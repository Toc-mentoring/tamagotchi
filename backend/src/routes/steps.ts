import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { addDays, dateIn, dateRange, isDate } from "../dates";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import type { Pet, PetEvent, PointTransaction, StepDay, Wallet } from "../models";
import { paths } from "../paths";
import { DEFAULT_GOAL_STEPS, INITIAL_STATS, pointsFor, reachedStages, summarize, SYNC_WINDOW_DAYS, TRANSITION } from "../rules";
import { loadRule, petDto, requireUser, stepDayDto, sumEarned, todayEarnedQuery } from "../store";

const PROVIDER_PLATFORM = { HEALTH_CONNECT: "ANDROID", HEALTHKIT: "IOS" } as const;
type Provider = keyof typeof PROVIDER_PLATFORM;

export function stepRoutes(db: Firestore) {
  const router = Router();

  // PUT /steps/days/:date — 그날 누적 걸음 저장 + 포인트·성장 반영
  router.put("/steps/days/:date", async (req, res) => {
    const uid: string = res.locals.uid;
    const { date } = req.params;
    const today = dateIn();
    const { deviceId, provider, totalSteps, observedAt } = req.body ?? {};

    // 입력 검사
    if (!isDate(date)) throw badRequest("날짜는 YYYY-MM-DD 형식이어야 합니다.");
    if (date > today) throw badRequest("미래 날짜는 동기화할 수 없습니다.");
    if (date < addDays(today, -(SYNC_WINDOW_DAYS - 1))) throw badRequest(`최근 ${SYNC_WINDOW_DAYS}일만 동기화할 수 있습니다.`);
    if (!isId(deviceId)) throw badRequest("deviceId가 필요합니다.");
    if (!Object.hasOwn(PROVIDER_PLATFORM, provider)) throw badRequest("provider는 HEALTH_CONNECT 또는 HEALTHKIT입니다.");
    if (!Number.isInteger(totalSteps) || totalSteps < 0) throw badRequest("totalSteps는 0 이상의 정수입니다.");
    const observedMs = typeof observedAt === "string" ? Date.parse(observedAt) : NaN;
    if (Number.isNaN(observedMs) || observedMs > Date.now() + 5 * 60 * 1000) throw badRequest("observedAt이 올바르지 않습니다.");

    const data = await runCommand(db, req, res, async (tx, commandId) => {
      // 1) 읽기
      const user = await requireUser(db, uid, tx);
      if (date < dateIn(user.createdAt.toDate())) throw badRequest("가입일 이전 날짜는 동기화할 수 없습니다.");
      if (user.stepSourceDeviceId !== deviceId) throw new ApiError(409, "STEP_SOURCE_MISMATCH", "대표 기기가 아닙니다.");
      const device = await tx.get(db.doc(paths.device(uid, deviceId)));
      if (device.get("platform") !== PROVIDER_PLATFORM[provider as Provider]) throw new ApiError(409, "STEP_SOURCE_MISMATCH", "기기와 걸음 출처가 맞지 않습니다.");
      if (!user.activePetId) throw new ApiError(409, "ACTIVE_PET_REQUIRED", "키우는 반려동물이 없습니다.");

      const petId = user.activePetId;
      const petRef = db.doc(paths.pet(uid, petId));
      const dayRef = db.doc(paths.stepDay(uid, date));
      const walletRef = db.doc(paths.wallet(uid));
      const [petSnap, daySnap, walletSnap, earnedSnap] = await Promise.all([
        tx.get(petRef), tx.get(dayRef), tx.get(walletRef), tx.get(todayEarnedQuery(db, uid, today)),
      ]);
      if (!petSnap.exists) throw new ApiError(409, "ACTIVE_PET_REQUIRED", "키우는 반려동물이 없습니다.");
      const pet = petSnap.data() as Pet;
      const rule = await loadRule(db, pet.growthRuleVersion, tx);
      const old = daySnap.data() as StepDay | undefined;
      if (old && observedMs <= old.observedAt.toMillis()) throw new ApiError(409, "STALE_STEP_SNAPSHOT", "이미 더 최근 걸음이 저장되어 있습니다.");

      // 2) 계산: 기존 최대보다 늘어난 만큼만 성장·포인트 지급 (줄어도 회수 안 함)
      const oldHigh = old?.creditedHighWater ?? 0;
      const newHigh = Math.max(oldHigh, totalSteps);
      const creditedSteps = newHigh - oldHigh;
      const pointsGranted = pointsFor(oldHigh, newHigh);
      const growthSteps = pet.growthSteps + creditedSteps;
      const reached = reachedStages(pet.stage, growthSteps, rule.thresholds);
      const stage = reached.at(-1) ?? pet.stage;
      const newPet: Pet = { ...pet, stage, growthSteps, stats: pet.stats ?? (stage === "EGG" ? null : INITIAL_STATS) };
      const balance: number = (walletSnap.get("balance") ?? 0) + pointsGranted;
      const now = Timestamp.now();

      // 3) 쓰기
      const day: StepDay = {
        totalSteps, creditedHighWater: newHigh, pointsEarned: (old?.pointsEarned ?? 0) + pointsGranted,
        goalSteps: old?.goalSteps ?? DEFAULT_GOAL_STEPS, observedAt: Timestamp.fromMillis(observedMs),
        lastSyncedAt: now, sourceDeviceId: deviceId, provider,
      };
      tx.set(dayRef, day);
      tx.set(petRef, newPet);
      const wallet: Wallet = { balance };
      tx.set(walletRef, wallet);
      if (pointsGranted > 0) {
        const point: PointTransaction = { amount: pointsGranted, type: "STEP_REWARD", sourceId: date, stepDate: date, commandId, createdAt: now };
        tx.create(db.doc(paths.pointTransaction(uid, commandId)), point);
      }
      if (creditedSteps > 0) {
        const growth: PetEvent = { type: "STEP_GROWTH", commandId, createdAt: now, stepDate: date, oldHighWater: oldHigh, newHighWater: newHigh };
        tx.create(db.doc(paths.petEvent(uid, petId, commandId)), growth);
      }
      reached.forEach((s, i) => {
        const event: PetEvent = { type: TRANSITION[s], commandId, createdAt: now, stepDate: date };
        tx.create(db.doc(paths.petEvent(uid, petId, `${commandId}-${i + 1}`)), event);
      });

      return {
        data: {
          day: stepDayDto(date, day),
          wallet: { balance, todayEarned: sumEarned(earnedSnap) + pointsGranted },
          activePet: petDto(petId, uid, newPet, rule),
          creditedSteps,
          pointsGranted,
          transitions: reached.map(s => TRANSITION[s]),
        },
        resourcePath: paths.stepDay(uid, date),
      };
    });
    send(res, data);
  });

  // GET /steps/summary?period=WEEK&endDate=2026-11-02 — 걸음 기록 화면
  router.get("/steps/summary", async (req, res) => {
    const uid: string = res.locals.uid;
    const today = dateIn();
    const period = String(req.query.period ?? "WEEK");
    const endDate = String(req.query.endDate ?? today);
    if (period !== "DAY" && period !== "WEEK") throw badRequest("period는 DAY 또는 WEEK입니다.");
    if (!isDate(endDate) || endDate > today) throw badRequest("endDate가 올바르지 않습니다.");

    await requireUser(db, uid);
    const count = period === "DAY" ? 1 : 7;
    const dates = dateRange(endDate, count);
    const previousDates = dateRange(addDays(endDate, -count), count);
    const snaps = await db.getAll(...[...previousDates, ...dates].map(d => db.doc(paths.stepDay(uid, d))));
    const toDto = (d: string, i: number) => stepDayDto(d, snaps[i].data() as StepDay | undefined);
    const previous = previousDates.map((d, i) => toDto(d, i));
    const days = dates.map((d, i) => toDto(d, count + i));

    send(res, { period, startDate: dates[0], endDate, days, ...summarize(days, previous) });
  });

  return router;
}