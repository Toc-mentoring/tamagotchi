import { createHash } from "node:crypto";
import type { Request, Response } from "express";
import { Timestamp, type Firestore, type Transaction } from "firebase-admin/firestore";
import { ApiError, badRequest } from "./http";
import type { Command, IdempotencyRecord } from "./models";
import { paths } from "./paths";

const KEEP_MS = 72 * 60 * 60 * 1000; // 성공 응답 72시간 보관
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const sha256 = (text: string) => createHash("sha256").update(text).digest("hex");

/**
 * 변경 요청(POST/PUT/PATCH)을 멱등하게 실행한다.
 * - 같은 키 + 같은 본문 재요청 → 처음 성공 응답을 그대로 돌려줌
 * - 같은 키 + 다른 본문 → 409 IDEMPOTENCY_CONFLICT
 * - 72시간 지나 응답이 만료된 재요청 → 409 ALREADY_PROCESSED
 * work 안의 읽기·쓰기와 명령 기록은 한 트랜잭션으로 저장된다.
 */
export async function runCommand<T>(
  db: Firestore, req: Request, res: Response,
  work: (tx: Transaction, commandId: string) => Promise<{ data: T; resourcePath: string | null }>,
): Promise<T> {
  const uid: string = res.locals.uid;
  const key = req.get("idempotency-key");
  if (!key || !UUID.test(key)) throw badRequest("Idempotency-Key 헤더에 UUID가 필요합니다.");
  const path = req.originalUrl.split("?")[0];
  const commandId = sha256(JSON.stringify([uid, req.method, path, key]));
  const bodyHash = sha256(JSON.stringify(req.body ?? null));

  return db.runTransaction(async tx => {
    const commandRef = db.doc(paths.command(commandId));
    const recordRef = db.doc(paths.idempotency(commandId));
    const [command, record] = await Promise.all([tx.get(commandRef), tx.get(recordRef)]);

    if (command.exists) {
      const saved = command.data() as Command;
      if (saved.bodyHash !== bodyHash) throw new ApiError(409, "IDEMPOTENCY_CONFLICT", "같은 키로 다른 요청을 보냈습니다.");
      const rec = record.data() as IdempotencyRecord | undefined;
      if (rec && rec.expiresAt.toMillis() > Date.now()) return rec.response as T;
      throw new ApiError(409, "ALREADY_PROCESSED", "이미 처리된 요청입니다.", { commandId, resourcePath: saved.resourcePath });
    }

    const { data, resourcePath } = await work(tx, commandId);
    const now = Timestamp.now();
    const newCommand: Command = { uid, bodyHash, resourcePath, createdAt: now };
    const newRecord: IdempotencyRecord = {
      uid, method: req.method, path, bodyHash, response: data, expiresAt: Timestamp.fromMillis(now.toMillis() + KEEP_MS),
    };
    tx.create(commandRef, newCommand);
    tx.create(recordRef, newRecord);
    return data;
  });
}