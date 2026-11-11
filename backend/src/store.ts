import type { DocumentReference, DocumentSnapshot, Firestore, Query, QuerySnapshot, Transaction } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";
import { startOfDay } from "./dates";
import { ApiError } from "./http";
import type { GrowthRule, Pet, StepDay, User } from "./models";
import { paths } from "./paths";
import { DEFAULT_GOAL_STEPS, stageProgress } from "./rules";

// 트랜잭션 안이면 tx로, 밖이면 바로 읽는다.
const read = (tx: Transaction | undefined, ref: DocumentReference): Promise<DocumentSnapshot> => (tx ? tx.get(ref) : ref.get());
const iso = (t: Timestamp | null | undefined) => (t ? t.toDate().toISOString() : null);

export async function requireUser(db: Firestore, uid: string, tx?: Transaction): Promise<User> {
  const snap = await read(tx, db.doc(paths.user(uid)));
  if (!snap.exists) throw new ApiError(404, "NOT_FOUND", "사용자 초기화가 필요합니다.");
  return snap.data() as User;
}

export async function loadRule(db: Firestore, version: string, tx?: Transaction): Promise<GrowthRule> {
  const snap = await read(tx, db.doc(paths.growthRule(version)));
  if (!snap.exists) throw new Error(`growthRules/${version} 문서가 없습니다. npm run seed를 실행하세요.`);
  return snap.data() as GrowthRule;
}

/** 오늘(서울) 지급된 포인트 조회용 쿼리 */
export function todayEarnedQuery(db: Firestore, uid: string, today: string): Query {
  return db.collection(`${paths.user(uid)}/pointTransactions`).where("createdAt", ">=", Timestamp.fromDate(startOfDay(today)));
}
export function sumEarned(snap: QuerySnapshot): number {
  return snap.docs.reduce((sum, d) => sum + Math.max(0, Number(d.get("amount") ?? 0)), 0);
}

// ----- API 응답 객체 (docs/api-spec.md 공통 객체) -----

export function userDto(uid: string, u: User) {
  return {
    uid, nickname: u.nickname, friendCode: u.friendCode, activePetId: u.activePetId,
    stepSourceDeviceId: u.stepSourceDeviceId, timeZone: u.timeZone, createdAt: iso(u.createdAt),
  };
}

export function petDto(id: string, ownerUid: string, p: Pet, rule: GrowthRule) {
  return {
    id, ownerUid, name: p.name, stage: p.stage, speciesId: p.speciesId, growthSteps: p.growthSteps,
    growthRuleVersion: p.growthRuleVersion, stageProgress: stageProgress(p.stage, p.growthSteps, rule.thresholds),
    stats: p.stats, careScore: null, createdAt: iso(p.createdAt),
  };
}

/** 저장된 기록이 없으면 미동기화 StepDay */
export function stepDayDto(date: string, d?: StepDay) {
  if (!d) return { date, totalSteps: null, goalSteps: DEFAULT_GOAL_STEPS, pointsEarned: 0, isSynced: false, lastSyncedAt: null };
  return { date, totalSteps: d.totalSteps, goalSteps: d.goalSteps, pointsEarned: d.pointsEarned, isSynced: true, lastSyncedAt: iso(d.lastSyncedAt) };
}