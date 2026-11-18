import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import type { Device } from "../models";
import { paths } from "../paths";
import { requireUser } from "../store";

const PLATFORMS = ["ANDROID", "IOS"] as const;

export function deviceRoutes(db: Firestore) {
  const router = Router();

  // PUT /devices/:deviceId — 앱 설치 단위 기기 등록 (다시 보내면 정보만 갱신)
  router.put("/devices/:deviceId", async (req, res) => {
    const uid: string = res.locals.uid;
    const { deviceId } = req.params;
    const { platform, pushToken = null } = req.body ?? {};
    if (!isId(deviceId)) throw badRequest("deviceId 형식이 올바르지 않습니다.");
    if (!PLATFORMS.includes(platform)) throw badRequest("platform은 ANDROID 또는 IOS입니다.");
    if (pushToken !== null && (typeof pushToken !== "string" || pushToken.length > 4096)) throw badRequest("pushToken이 올바르지 않습니다.");

    const data = await runCommand(db, req, res, async tx => {
      await requireUser(db, uid, tx);
      const ref = db.doc(paths.device(uid, deviceId));
      const snap = await tx.get(ref);
      const now = Timestamp.now();
      const device: Device = {
        platform,
        pushToken,
        registeredAt: snap.exists ? (snap.get("registeredAt") as Timestamp) : now,
        lastSeenAt: now,
      };
      tx.set(ref, device);
      return { data: { deviceId, platform }, resourcePath: ref.path };
    });
    send(res, data);
  });

  // PUT /me/step-source — 걸음을 보낼 대표 기기 지정 (등록된 본인 기기만)
  router.put("/me/step-source", async (req, res) => {
    const uid: string = res.locals.uid;
    const { deviceId } = req.body ?? {};
    if (!isId(deviceId)) throw badRequest("deviceId 형식이 올바르지 않습니다.");

    const data = await runCommand(db, req, res, async tx => {
      await requireUser(db, uid, tx);
      const deviceSnap = await tx.get(db.doc(paths.device(uid, deviceId)));
      if (!deviceSnap.exists) throw new ApiError(404, "NOT_FOUND", "등록된 기기가 아닙니다.");
      tx.update(db.doc(paths.user(uid)), { stepSourceDeviceId: deviceId });
      return { data: { stepSourceDeviceId: deviceId }, resourcePath: paths.user(uid) };
    });
    send(res, data);
  });

  return router;
}