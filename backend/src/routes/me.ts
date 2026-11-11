import { randomBytes, randomUUID } from "node:crypto";
import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { ApiError, badRequest, send } from "../http";
import type { FriendCode, GrowthRule, Pet, User, Wallet } from "../models";
import { paths } from "../paths";
import { DEFAULT_GROWTH_RULE } from "../rules";
import { petDto, userDto } from "../store";

const INITIAL_NICKNAME_MAX_LENGTH = 24;
const FRIEND_CODE_ATTEMPTS = 5;

function newFriendCode(): string {
  return randomBytes(6).toString("hex").toUpperCase();
}

function initialGrowthRule(): GrowthRule {
  return {
    thresholds: DEFAULT_GROWTH_RULE.thresholds,
    effectRuleVersion: DEFAULT_GROWTH_RULE.id,
  };
}

export function meRoutes(db: Firestore) {
  const router = Router();

  // POST /me/bootstrap — 인증된 계정에 사용자·첫 알·지갑을 최초 1회 생성
  router.post("/me/bootstrap", async (req, res) => {
    const uid: string = res.locals.uid;
    const input = req.body?.nickname;
    if (typeof input !== "string") throw badRequest("nickname은 문자열이어야 합니다.");
    const nickname = input.trim();
    if (!nickname || [...nickname].length > INITIAL_NICKNAME_MAX_LENGTH) {
      throw badRequest(`nickname은 1~${INITIAL_NICKNAME_MAX_LENGTH}자여야 합니다.`);
    }

    for (let attempt = 0; attempt < FRIEND_CODE_ATTEMPTS; attempt++) {
      const friendCode = newFriendCode();
      const petId = randomUUID();
      const result = await db.runTransaction(async tx => {
        const userRef = db.doc(paths.user(uid));
        const userSnap = await tx.get(userRef);

        if (userSnap.exists) {
          const user = userSnap.data() as User;
          if (!user.activePetId) throw new ApiError(409, "USER_DATA_INCOMPLETE", "활성 반려동물 정보가 없습니다.");
          const petRef = db.doc(paths.pet(uid, user.activePetId));
          const walletRef = db.doc(paths.wallet(uid));
          const [petSnap, walletSnap] = await Promise.all([tx.get(petRef), tx.get(walletRef)]);
          if (!petSnap.exists || !walletSnap.exists) {
            throw new ApiError(409, "USER_DATA_INCOMPLETE", "사용자 초기 데이터가 완전하지 않습니다.");
          }

          const pet = petSnap.data() as Pet;
          const ruleRef = db.doc(paths.growthRule(pet.growthRuleVersion));
          const ruleSnap = await tx.get(ruleRef);
          let rule: GrowthRule;
          if (ruleSnap.exists) {
            rule = ruleSnap.data() as GrowthRule;
          } else if (pet.growthRuleVersion === DEFAULT_GROWTH_RULE.id) {
            rule = initialGrowthRule();
            tx.create(ruleRef, rule);
          } else {
            throw new Error(`growthRules/${pet.growthRuleVersion} 문서가 없습니다.`);
          }

          const wallet = walletSnap.data() as Wallet;
          return {
            retry: false,
            data: {
              user: userDto(uid, user),
              pet: petDto(user.activePetId, uid, pet, rule),
              wallet,
              created: false,
            },
          };
        }

        const friendCodeRef = db.doc(paths.friendCode(friendCode));
        const ruleRef = db.doc(paths.growthRule(DEFAULT_GROWTH_RULE.id));
        const [friendCodeSnap, ruleSnap] = await Promise.all([tx.get(friendCodeRef), tx.get(ruleRef)]);
        if (friendCodeSnap.exists) return { retry: true as const };

        const now = Timestamp.now();
        const pet: Pet = {
          name: "모모",
          stage: "EGG",
          speciesId: null,
          familyId: null,
          growthSteps: 0,
          growthRuleVersion: DEFAULT_GROWTH_RULE.id,
          stats: null,
          traits: {},
          createdAt: now,
        };
        const user: User = {
          nickname,
          friendCode,
          activePetId: petId,
          stepSourceDeviceId: null,
          timeZone: "Asia/Seoul",
          notificationSettings: {
            pushEnabled: true,
            care: true,
            hatch: true,
            growth: true,
            proposal: true,
            gift: true,
            walkSummary: true,
          },
          createdAt: now,
          lastSeenAt: now,
        };
        const wallet: Wallet = { balance: 0 };
        const rule = ruleSnap.exists ? ruleSnap.data() as GrowthRule : initialGrowthRule();

        if (!ruleSnap.exists) tx.create(ruleRef, rule);
        tx.create(userRef, user);
        tx.create(friendCodeRef, { uid } satisfies FriendCode);
        tx.create(db.doc(paths.pet(uid, petId)), pet);
        tx.create(db.doc(paths.wallet(uid)), wallet);

        return {
          retry: false,
          data: {
            user: userDto(uid, user),
            pet: petDto(petId, uid, pet, rule),
            wallet,
            created: true,
          },
        };
      });

      if (result.retry) continue;
      send(res, result.data);
      return;
    }

    throw new ApiError(503, "UNAVAILABLE", "친구 코드를 발급하지 못했습니다. 다시 시도해 주세요.");
  });

  return router;
}
