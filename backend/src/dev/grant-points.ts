import { randomUUID } from "node:crypto";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { connectFirestore } from "../db";
import type { PointTransaction } from "../models";
import { paths } from "../paths";

// 개발용: 테스트하려고 포인트를 넣어 준다.
// npm run grant:points            → 모든 사용자에게 1000P
// npm run grant:points -- 5000    → 모든 사용자에게 5000P
// npm run grant:points -- 5000 uid → 그 사용자에게만
async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) throw new Error("FIREBASE_PROJECT_ID를 설정하세요");
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.ALLOW_LIVE_SEED !== projectId) {
    throw new Error("실제 DB에 넣으려면 ALLOW_LIVE_SEED에 프로젝트 ID를 똑같이 설정하세요");
  }
  const amount = Number(process.argv[2] ?? 1000);
  if (!Number.isSafeInteger(amount) || amount < 1 || amount > 100000) throw new Error("포인트는 1~100000 사이 정수로 주세요");
  const onlyUid = process.argv[3];

  const db = connectFirestore(projectId);
  try {
    const uids = onlyUid ? [onlyUid] : (await db.collection("users").listDocuments()).map(d => d.id);
    let count = 0;
    for (const uid of uids) {
      const walletRef = db.doc(paths.wallet(uid));
      if (!(await walletRef.get()).exists) continue; // 지갑이 없는 사용자는 건너뜀
      const id = randomUUID();
      const tx: PointTransaction = { amount, type: "DEV_GRANT", sourceId: "dev", commandId: id, createdAt: Timestamp.now() };
      const batch = db.batch();
      batch.update(walletRef, { balance: FieldValue.increment(amount) });
      batch.set(db.doc(paths.pointTransaction(uid, id)), tx);
      await batch.commit();
      count++;
    }
    console.log(`${projectId}: 사용자 ${count}명에게 ${amount}P 지급 완료`);
  } finally {
    await db.terminate();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
