import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { inventoryDto } from "../catalog";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import { requireFriendship } from "../friends";
import type { Gift, InventoryItem, Item, Notification, User } from "../models";
import { paths } from "../paths";
import { requireUser } from "../store";

export function giftRoutes(db: Firestore) {
  const router = Router();

  // POST /gifts — 친구 관계, 발신자 재고, 수신자 재고와 알림을 한 트랜잭션에 저장한다.
  router.post("/gifts", async (req, res) => {
    const uid: string = res.locals.uid;
    const { recipientUid, itemId, quantity } = req.body ?? {};
    if (!isId(recipientUid)) throw badRequest("recipientUid 형식이 올바르지 않습니다.");
    if (!isId(itemId)) throw badRequest("itemId 형식이 올바르지 않습니다.");
    if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 99) throw badRequest("quantity는 1~99의 정수여야 합니다.");

    const data = await runCommand(db, req, res, async (tx, commandId) => {
      const sender = await requireUser(db, uid, tx);
      await requireFriendship(db, uid, recipientUid, tx);
      const senderInventoryRef = db.doc(paths.inventory(uid, itemId));
      const recipientInventoryRef = db.doc(paths.inventory(recipientUid, itemId));
      const [recipientSnap, itemSnap, senderInventorySnap, recipientInventorySnap] = await Promise.all([
        tx.get(db.doc(paths.user(recipientUid))),
        tx.get(db.doc(paths.item(itemId))),
        tx.get(senderInventoryRef),
        tx.get(recipientInventoryRef),
      ]);
      if (!recipientSnap.exists) throw new ApiError(404, "NOT_FOUND", "수신자를 찾을 수 없습니다.");
      if (!itemSnap.exists || !itemSnap.get("active")) throw new ApiError(404, "NOT_FOUND", "아이템을 찾을 수 없습니다.");
      const senderQuantity: number = senderInventorySnap.get("quantity") ?? 0;
      if (senderQuantity < quantity) throw new ApiError(409, "INSUFFICIENT_ITEMS", "보관함 아이템이 부족합니다.");

      const now = Timestamp.now();
      const item = itemSnap.data() as Item;
      const recipient = recipientSnap.data() as User;
      const senderInventory: InventoryItem = { quantity: senderQuantity - quantity, updatedAt: now };
      const recipientInventory: InventoryItem = {
        quantity: Number(recipientInventorySnap.get("quantity") ?? 0) + quantity,
        updatedAt: now,
      };
      const gift: Gift = { senderUid: uid, recipientUid, itemId, quantity, commandId, createdAt: now };
      const notification: Notification = {
        type: "GIFT",
        title: "선물이 도착했어요",
        body: `${sender.nickname}님이 ${item.name} ${quantity}개를 보냈어요.`,
        targetType: "GIFT",
        targetId: commandId,
        createdAt: now,
        readAt: null,
      };
      const giftPath = paths.gift(commandId);
      tx.set(senderInventoryRef, senderInventory);
      tx.set(recipientInventoryRef, recipientInventory);
      tx.create(db.doc(giftPath), gift);
      tx.create(db.doc(paths.notification(recipientUid, commandId)), notification);

      return {
        data: { giftId: commandId, senderInventoryItem: inventoryDto(itemId, senderInventory, item) },
        resourcePath: giftPath,
      };
    });
    send(res, data, 201);
  });

  return router;
}
