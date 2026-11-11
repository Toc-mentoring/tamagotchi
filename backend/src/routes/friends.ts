import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import { friendDto, loadFriendSummary, requireFriendship } from "../friends";
import type { Discovery, Friendship, Pet, Visit } from "../models";
import { friendshipId, paths } from "../paths";
import { paginate, pageCursor, pageLimit } from "../pagination";
import { requireUser } from "../store";

export function friendRoutes(db: Firestore) {
  const router = Router();

  // POST /friends — 코드로 양방향 친구 관계를 만든다.
  router.post("/friends", async (req, res) => {
    const uid: string = res.locals.uid;
    const rawCode = req.body?.friendCode;
    if (typeof rawCode !== "string" || !/^[A-Za-z0-9_-]{1,32}$/.test(rawCode.trim())) {
      throw badRequest("friendCode 형식이 올바르지 않습니다.");
    }
    const friendCode = rawCode.trim().toUpperCase();
    const result = await runCommand(db, req, res, async (tx, commandId) => {
      await requireUser(db, uid, tx);
      const codeSnap = await tx.get(db.doc(paths.friendCode(friendCode)));
      if (!codeSnap.exists) throw new ApiError(404, "NOT_FOUND", "친구 코드를 찾을 수 없습니다.");
      const friendUid = String(codeSnap.get("uid") ?? "");
      if (!friendUid || friendUid === uid) throw new ApiError(400, "INVALID_ARGUMENT", "자기 자신의 친구 코드는 추가할 수 없습니다.");
      const relationRef = db.doc(paths.friendship(friendshipId(uid, friendUid)));
      const [friendSummary, relationSnap] = await Promise.all([
        loadFriendSummary(db, friendUid, tx),
        tx.get(relationRef),
      ]);
      if (relationSnap.exists) {
        if (relationSnap.get("status") !== "ACTIVE") throw new ApiError(409, "FRIENDSHIP_NOT_ACTIVE", "친구 관계를 추가할 수 없습니다.");
        return { data: { friend: friendDto(friendSummary), created: false }, resourcePath: relationRef.path };
      }

      const [userA, userB] = [uid, friendUid].sort();
      const friendship: Friendship = {
        userA,
        userB,
        memberUids: [userA, userB],
        status: "ACTIVE",
        createdAt: Timestamp.now(),
      };
      tx.create(relationRef, friendship);
      return { data: { friend: friendDto(friendSummary), created: true }, resourcePath: relationRef.path };
    });
    send(res, result, result.created ? 201 : 200);
  });

  // GET /friends — 친구 목록과 전체 수.
  router.get("/friends", async (req, res) => {
    const uid: string = res.locals.uid;
    await requireUser(db, uid);
    const snap = await db.collection("friendships").where("memberUids", "array-contains", uid).get();
    const relations = snap.docs
      .filter(doc => doc.get("status") === "ACTIVE")
      .map(doc => ({ id: doc.id, data: doc.data() as Friendship }))
      .sort((a, b) => b.data.createdAt.toMillis() - a.data.createdAt.toMillis() || a.id.localeCompare(b.id));
    const page = paginate(relations, pageLimit(req.query.limit), pageCursor(req.query.cursor), relation => relation.id);
    const items = await Promise.all(page.items.map(async ({ data }) => {
      const friendUid = data.memberUids.find(memberUid => memberUid !== uid);
      if (!friendUid) throw new Error("Friendship is missing its other member");
      return friendDto(await loadFriendSummary(db, friendUid));
    }));
    send(res, { items, totalCount: relations.length }, 200, { nextCursor: page.nextCursor });
  });

  // POST /friend-visits — 방문 이력과 성체 종의 첫 발견을 한 트랜잭션에 저장한다.
  router.post("/friend-visits", async (req, res) => {
    const uid: string = res.locals.uid;
    const { friendUid } = req.body ?? {};
    if (!isId(friendUid)) throw badRequest("friendUid 형식이 올바르지 않습니다.");
    const data = await runCommand(db, req, res, async (tx, commandId) => {
      const user = await requireUser(db, uid, tx);
      await requireFriendship(db, uid, friendUid, tx);
      const friend = await loadFriendSummary(db, friendUid, tx);
      const myPetSnap = user.activePetId ? await tx.get(db.doc(paths.pet(uid, user.activePetId))) : null;
      const myPet = myPetSnap?.exists ? myPetSnap.data() as Pet : null;
      const targetPetId = friend.user.activePetId;
      let discoveryRef = null;
      let discoverySnap = null;
      if (friend.pet?.stage === "ADULT" && friend.pet.speciesId) {
        discoveryRef = db.doc(paths.discovery(uid, friend.pet.speciesId));
        discoverySnap = await tx.get(discoveryRef);
      }

      const now = Timestamp.now();
      const visit: Visit = { friendUid, targetPetId, commandId, createdAt: now };
      const visitPath = paths.visit(uid, commandId);
      tx.create(db.doc(visitPath), visit);
      let newDiscovery = null;
      if (discoveryRef && discoverySnap && !discoverySnap.exists && friend.pet?.speciesId && targetPetId) {
        const discovery: Discovery = {
          source: "FRIEND_VISIT",
          firstPetId: targetPetId,
          firstOwnerUid: friendUid,
          firstDiscoveredAt: now,
        };
        tx.create(discoveryRef, discovery);
        newDiscovery = {
          speciesId: friend.pet.speciesId,
          discovered: true,
          firstPetId: targetPetId,
          firstOwnerUid: friendUid,
          firstDiscoveredAt: now.toDate().toISOString(),
          discoverySource: discovery.source,
        };
      }
      return {
        data: {
          visitId: commandId,
          friend: friendDto(friend),
          pet: friend.pet ? { id: targetPetId, name: friend.pet.name, stage: friend.pet.stage, speciesId: friend.pet.speciesId, careScore: null } : null,
          canPropose: myPet?.stage === "ADULT" && friend.pet?.stage === "ADULT",
          newDiscovery,
        },
        resourcePath: visitPath,
      };
    });
    send(res, data, 201);
  });

  // GET /friends/:friendUid/visit — 새로고침을 위한 읽기 전용 방문 데이터.
  router.get("/friends/:friendUid/visit", async (req, res) => {
    const uid: string = res.locals.uid;
    const { friendUid } = req.params;
    if (!isId(friendUid)) throw badRequest("friendUid 형식이 올바르지 않습니다.");
    const user = await requireUser(db, uid);
    await requireFriendship(db, uid, friendUid);
    const friend = await loadFriendSummary(db, friendUid);
    const myPetId = user.activePetId;
    const myPetSnap = myPetId ? await db.doc(paths.pet(uid, myPetId)).get() : null;
    const myPet = myPetSnap?.exists ? myPetSnap.data() as Pet : null;
    send(res, {
      friend: friendDto(friend),
      pet: friend.pet ? { id: friend.user.activePetId, name: friend.pet.name, stage: friend.pet.stage, speciesId: friend.pet.speciesId, careScore: null } : null,
      canPropose: myPet?.stage === "ADULT" && friend.pet?.stage === "ADULT",
    });
  });

  return router;
}
