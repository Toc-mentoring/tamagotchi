import { Timestamp } from "firebase-admin/firestore";
import { connectFirestore } from "../db";
import type { Device, GrowthRule, Pet, User, Wallet } from "../models";
import { paths } from "../paths";
import { DEFAULT_GROWTH_RULE } from "../rules";

// 로컬 테스트용 데이터. 실행할 때마다 개발 사용자를 지우고 처음 상태(알, 0걸음)로 다시 만든다.
async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const uid = process.env.DEV_AUTH_UID;
  if (!projectId || !uid) throw new Error("FIREBASE_PROJECT_ID와 DEV_AUTH_UID를 설정하세요");
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.ALLOW_LIVE_SEED !== projectId) {
    throw new Error("실제 DB에 넣으려면 ALLOW_LIVE_SEED에 프로젝트 ID를 똑같이 설정하세요");
  }
  const db = connectFirestore(projectId);
  try {
    await db.recursiveDelete(db.doc(paths.user(uid)));

    const now = Timestamp.now();
    const joined = Timestamp.fromMillis(now.toMillis() - 8 * 24 * 60 * 60 * 1000); // 7일 소급 테스트용
    const friendCode = `DEV${uid.toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 8)}`;
    const rule: GrowthRule = { thresholds: DEFAULT_GROWTH_RULE.thresholds, effectRuleVersion: DEFAULT_GROWTH_RULE.id };
    const user: User = {
      nickname: "테스트", friendCode, activePetId: "pet-1", stepSourceDeviceId: "dev-device", timeZone: "Asia/Seoul",
      notificationSettings: { pushEnabled: true, care: true, hatch: true, growth: true, proposal: true, gift: true, walkSummary: true },
      createdAt: joined, lastSeenAt: now,
    };
    const device: Device = { platform: "ANDROID", pushToken: null, registeredAt: joined, lastSeenAt: now };
    const pet: Pet = {
      name: "모모", stage: "EGG", speciesId: null, familyId: null, growthSteps: 0,
      growthRuleVersion: DEFAULT_GROWTH_RULE.id, stats: null, traits: {}, createdAt: joined,
    };
    const wallet: Wallet = { balance: 0 };

    const batch = db.batch();
    batch.set(db.doc(paths.growthRule(DEFAULT_GROWTH_RULE.id)), rule);
    batch.set(db.doc(paths.user(uid)), user);
    batch.set(db.doc(paths.friendCode(friendCode)), { uid });
    batch.set(db.doc(paths.device(uid, "dev-device")), device);
    batch.set(db.doc(paths.pet(uid, "pet-1")), pet);
    batch.set(db.doc(paths.wallet(uid)), wallet);
    await batch.commit();
    console.log(`${projectId}: 테스트 사용자 '${uid}' 준비 완료 (알 모모, 0걸음)`);
  } finally {
    await db.terminate();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });