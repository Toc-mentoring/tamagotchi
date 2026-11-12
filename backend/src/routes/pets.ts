import { randomUUID } from "node:crypto";
import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { inventoryDto } from "../catalog";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import type { InventoryItem, Item, Pet, PetEvent } from "../models";
import { paginate, pageCursor, pageLimit } from "../pagination";
import { paths } from "../paths";
import { applyEffects, CARE_EFFECTS, type CareAction } from "../rules";
import { loadRule, petDto, requireUser } from "../store";

export function petRoutes(db: Firestore) {
  const router = Router();

  // GET /pets — 사용자의 보유 개체 목록.
  router.get("/pets", async (req, res) => {
    const uid: string = res.locals.uid;
    const user = await requireUser(db, uid);
    const snap = await db.collection(`${paths.user(uid)}/pets`).get();
    const pets = await Promise.all(snap.docs
      .map(doc => ({ id: doc.id, pet: doc.data() as Pet }))
      .sort((a, b) => b.pet.createdAt.toMillis() - a.pet.createdAt.toMillis() || a.id.localeCompare(b.id))
      .map(async row => ({ ...petDto(row.id, uid, row.pet, await loadRule(db, row.pet.growthRuleVersion)), id: row.id })));
    const page = paginate(pets, pageLimit(req.query.limit), pageCursor(req.query.cursor), pet => pet.id);
    send(res, { items: page.items, activePetId: user.activePetId }, 200, { nextCursor: page.nextCursor });
  });

  // POST /pets — 보관함의 희귀 알 하나를 사용해 비활성 알을 생성한다.
  router.post("/pets", async (req, res) => {
    const uid: string = res.locals.uid;
    const { sourceItemId } = req.body ?? {};
    if (!isId(sourceItemId)) throw badRequest("sourceItemId 형식이 올바르지 않습니다.");
    const petId = randomUUID();
    const data = await runCommand(db, req, res, async (tx, commandId) => {
      await requireUser(db, uid, tx);
      const inventoryRef = db.doc(paths.inventory(uid, sourceItemId));
      const itemRef = db.doc(paths.item(sourceItemId));
      const [inventorySnap, itemSnap] = await Promise.all([tx.get(inventoryRef), tx.get(itemRef)]);
      if (!itemSnap.exists || !itemSnap.get("active") || itemSnap.get("category") !== "RARE_EGG") {
        throw new ApiError(409, "ITEM_NOT_EGG", "알 아이템이 아닙니다.");
      }
      const quantity: number = inventorySnap.get("quantity") ?? 0;
      if (quantity < 1) throw new ApiError(409, "INSUFFICIENT_ITEMS", "아이템이 부족합니다.");
      const item = itemSnap.data() as Item;
      const rule = await loadRule(db, "v0", tx);
      const now = Timestamp.now();
      const pet: Pet = {
        name: "모모",
        stage: "EGG",
        speciesId: null,
        familyId: null,
        growthSteps: 0,
        growthRuleVersion: "v0",
        stats: null,
        traits: {},
        createdAt: now,
      };
      const inventory: InventoryItem = { quantity: quantity - 1, updatedAt: now };
      const petPath = paths.pet(uid, petId);
      tx.set(inventoryRef, inventory);
      tx.create(db.doc(petPath), pet);
      return {
        data: {
          pet: petDto(petId, uid, pet, rule),
          inventoryItem: inventoryDto(sourceItemId, inventory, item),
        },
        resourcePath: petPath,
      };
    });
    send(res, data, 201);
  });

  // POST /pets/:petId/activate — 본인 소유 개체로 활성 상태를 전환한다.
  router.post("/pets/:petId/activate", async (req, res) => {
    const uid: string = res.locals.uid;
    const { petId } = req.params;
    if (!isId(petId)) throw badRequest("petId 형식이 올바르지 않습니다.");
    const data = await runCommand(db, req, res, async (tx) => {
      const user = await requireUser(db, uid, tx);
      const petRef = db.doc(paths.pet(uid, petId));
      const petSnap = await tx.get(petRef);
      if (!petSnap.exists) throw new ApiError(404, "NOT_FOUND", "반려동물을 찾을 수 없습니다.");
      const pet = petSnap.data() as Pet;
      const rule = await loadRule(db, pet.growthRuleVersion, tx);
      if (user.activePetId !== petId) tx.update(db.doc(paths.user(uid)), { activePetId: petId });
      return {
        data: { activePetId: petId, pet: petDto(petId, uid, pet, rule) },
        resourcePath: paths.user(uid),
      };
    });
    send(res, data);
  });

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
