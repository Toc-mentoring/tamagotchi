import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import type { InventoryItem, Item, Pet, PetEvent } from "../models";
import { paths } from "../paths";
import { applyEffects, CARE_EFFECTS, type CareAction } from "../rules";
import { loadRule, petDto, requireUser } from "../store";

export function petRoutes(db: Firestore) {
  const router = Router();

  // GET /pets/:petId — 알 부화 화면 (stageProgress 사용)
  router.get("/pets/:petId", async (req, res) => {
    const uid: string = res.locals.uid;
    const { petId } = req.params;
    if (!isId(petId)) throw badRequest("petId 형식이 올바르지 않습니다.");

    const user = await requireUser(db, uid);
    const snap = await db.doc(paths.pet(uid, petId)).get();
    if (!snap.exists) throw new ApiError(404, "NOT_FOUND", "반려동물을 찾을 수 없습니다.");
    const pet = snap.data() as Pet;

    send(res, { pet: petDto(petId, uid, pet, await loadRule(db, pet.growthRuleVersion)), active: user.activePetId === petId });
  });

  // POST /pets/:petId/care-actions — 먹이·청소·놀기·약·재우기
  router.post("/pets/:petId/care-actions", async (req, res) => {
    const uid: string = res.locals.uid;
    const { petId } = req.params;
    const { action, itemId = null } = req.body ?? {};
    if (!isId(petId)) throw badRequest("petId 형식이 올바르지 않습니다.");
    if (!Object.hasOwn(CARE_EFFECTS, action)) throw badRequest("action은 FEED, CLEAN, PLAY, MEDICINE, SLEEP 중 하나입니다.");
    if (itemId !== null && !isId(itemId)) throw badRequest("itemId 형식이 올바르지 않습니다.");

    const data = await runCommand(db, req, res, async (tx, commandId) => {
      // 1) 읽기 (트랜잭션은 읽기를 모두 끝낸 뒤 써야 한다)
      const user = await requireUser(db, uid, tx);
      const petRef = db.doc(paths.pet(uid, petId));
      const petSnap = await tx.get(petRef);
      if (!petSnap.exists) throw new ApiError(404, "NOT_FOUND", "반려동물을 찾을 수 없습니다.");
      if (user.activePetId !== petId) throw new ApiError(409, "PET_NOT_ACTIVE", "지금 키우는 반려동물이 아닙니다.");
      const pet = petSnap.data() as Pet;
      if (pet.stage === "EGG" || !pet.stats) throw badRequest("알에는 돌봄을 할 수 없습니다.");
      const rule = await loadRule(db, pet.growthRuleVersion, tx);

      const invRef = itemId ? db.doc(paths.inventory(uid, itemId)) : null;
      const [invSnap, itemSnap] = itemId
        ? await Promise.all([tx.get(invRef!), tx.get(db.doc(paths.item(itemId)))])
        : [null, null];
      const quantity: number = invSnap?.get("quantity") ?? 0;
      if (itemId && (!itemSnap?.exists || quantity < 1)) throw new ApiError(409, "INSUFFICIENT_ITEMS", "아이템이 부족합니다.");

      // 2) 계산
      const { stats, applied } = applyEffects(pet.stats, CARE_EFFECTS[action as CareAction]);
      const now = Timestamp.now();

      // 3) 쓰기
      tx.update(petRef, { stats });
      let inventoryItem = null;
      if (invRef && itemSnap) {
        const left: InventoryItem = { quantity: quantity - 1, updatedAt: now };
        tx.set(invRef, left);
        const item = itemSnap.data() as Item;
        inventoryItem = { itemId, name: item.name, category: item.category, quantity: left.quantity, effectText: "", imageUrl: item.imageUrl };
      }
      const event: PetEvent = { type: "CARE", commandId, createdAt: now, action, itemId, appliedEffects: applied };
      const eventPath = paths.petEvent(uid, petId, commandId);
      tx.create(db.doc(eventPath), event);

      return {
        data: { pet: petDto(petId, uid, { ...pet, stats }, rule), inventoryItem, appliedEffects: applied },
        resourcePath: eventPath,
      };
    });
    send(res, data);
  });

  return router;
}