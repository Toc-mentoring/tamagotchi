import { Router } from "express";
import type { Firestore } from "firebase-admin/firestore";
import { dateIn } from "../dates";
import { send } from "../http";
import type { Pet, StepDay } from "../models";
import { paths } from "../paths";
import { loadRule, petDto, requireUser, stepDayDto, sumEarned, todayEarnedQuery, userDto } from "../store";

export function homeRoutes(db: Firestore) {
  const router = Router();

  // GET /home — 홈 화면 데이터 한 번에
  router.get("/home", async (_req, res) => {
    const uid: string = res.locals.uid;
    const user = await requireUser(db, uid);
    const today = dateIn();

    const [petSnap, daySnap, walletSnap, earnedSnap, unread] = await Promise.all([
      user.activePetId ? db.doc(paths.pet(uid, user.activePetId)).get() : null,
      db.doc(paths.stepDay(uid, today)).get(),
      db.doc(paths.wallet(uid)).get(),
      todayEarnedQuery(db, uid, today).get(),
      db.collection(`${paths.user(uid)}/notifications`).where("readAt", "==", null).count().get(),
    ]);

    let pet = null;
    if (petSnap?.exists) {
      const data = petSnap.data() as Pet;
      pet = petDto(petSnap.id, uid, data, await loadRule(db, data.growthRuleVersion));
    }

    send(res, {
      user: userDto(uid, user),
      pet,
      today: stepDayDto(today, daySnap.data() as StepDay | undefined),
      wallet: { balance: walletSnap.get("balance") ?? 0, todayEarned: sumEarned(earnedSnap) },
      unreadCount: unread.data().count,
    });
  });

  return router;
}