import { randomUUID } from "node:crypto";
import { Router } from "express";
import type { Request, Response } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import { requireFriendship } from "../friends";
import type { Family, Notification, PendingProposalKey, Pet, Proposal, User } from "../models";
import { paths, proposalPairId } from "../paths";
import { DEFAULT_GROWTH_RULE } from "../rules";
import { loadRule, petDto, requireUser } from "../store";

function proposalDto(id: string, proposal: Proposal) {
  return {
    id,
    senderUid: proposal.senderUid,
    recipientUid: proposal.recipientUid,
    senderPetId: proposal.senderPetId,
    recipientPetId: proposal.recipientPetId,
    status: proposal.status,
    createdAt: proposal.createdAt.toDate().toISOString(),
    resolvedAt: proposal.resolvedAt?.toDate().toISOString() ?? null,
    familyId: proposal.familyId,
  };
}

function traitLabels(pet: Pet): string[] {
  const labels = pet.traits.labels;
  if (Array.isArray(labels)) return labels.filter((label): label is string => typeof label === "string");
  return Object.values(pet.traits).filter((value): value is string => typeof value === "string");
}

function notification(type: "PROPOSAL", title: string, body: string, proposalId: string, createdAt: Timestamp): Notification {
  return { type, title, body, targetType: "PROPOSAL", targetId: proposalId, createdAt, readAt: null };
}

function newEgg(familyId: string, now: Timestamp): Pet {
  return {
    name: "모모",
    stage: "EGG",
    speciesId: null,
    familyId,
    growthSteps: 0,
    growthRuleVersion: DEFAULT_GROWTH_RULE.id,
    stats: null,
    traits: {},
    createdAt: now,
  };
}

export function proposalRoutes(db: Firestore) {
  const router = Router();

  // POST /proposals — 활성 성체끼리 친구 청혼을 만든다.
  router.post("/proposals", async (req, res) => {
    const uid: string = res.locals.uid;
    const { recipientUid, senderPetId, recipientPetId } = req.body ?? {};
    if (!isId(recipientUid) || !isId(senderPetId) || !isId(recipientPetId)) {
      throw badRequest("recipientUid, senderPetId, recipientPetId가 필요합니다.");
    }

    const data = await runCommand(db, req, res, async (tx, commandId) => {
      const sender = await requireUser(db, uid, tx);
      const recipient = await requireUser(db, recipientUid, tx);
      await requireFriendship(db, uid, recipientUid, tx);
      if (sender.activePetId !== senderPetId || recipient.activePetId !== recipientPetId) {
        throw new ApiError(409, "PET_NOT_ACTIVE", "청혼 대상은 각 사용자의 활성 반려동물이어야 합니다.");
      }
      const senderPetRef = db.doc(paths.pet(uid, senderPetId));
      const recipientPetRef = db.doc(paths.pet(recipientUid, recipientPetId));
      const pairId = proposalPairId(uid, senderPetId, recipientUid, recipientPetId);
      const pendingKeyRef = db.doc(paths.pendingProposalKey(pairId));
      const [senderPetSnap, recipientPetSnap, pendingSnap] = await Promise.all([
        tx.get(senderPetRef),
        tx.get(recipientPetRef),
        tx.get(pendingKeyRef),
      ]);
      if (!senderPetSnap.exists || !recipientPetSnap.exists) throw new ApiError(404, "NOT_FOUND", "청혼할 반려동물을 찾을 수 없습니다.");
      const senderPet = senderPetSnap.data() as Pet;
      const recipientPet = recipientPetSnap.data() as Pet;
      if (senderPet.stage !== "ADULT" || recipientPet.stage !== "ADULT") {
        throw new ApiError(409, "PET_NOT_ADULT", "어른 반려동물끼리만 청혼할 수 있습니다.");
      }
      if (pendingSnap.exists) {
        throw new ApiError(409, "PROPOSAL_ALREADY_PENDING", "같은 반려동물 사이에 처리 중인 청혼이 있습니다.", {
          proposalId: (pendingSnap.data() as PendingProposalKey).proposalId,
        });
      }

      const now = Timestamp.now();
      const proposalId = commandId;
      const proposal: Proposal = {
        senderUid: uid,
        recipientUid,
        senderPetId,
        recipientPetId,
        status: "PENDING",
        familyId: null,
        commandId,
        createdAt: now,
        resolvedAt: null,
      };
      const proposalPath = paths.proposal(proposalId);
      tx.create(db.doc(proposalPath), proposal);
      tx.create(pendingKeyRef, { proposalId } satisfies PendingProposalKey);
      tx.create(db.doc(paths.notification(recipientUid, proposalId)), notification(
        "PROPOSAL", "청혼이 도착했어요", `${sender.nickname}님의 반려동물이 가족이 되고 싶어 해요.`, proposalId, now,
      ));
      return { data: { proposal: proposalDto(proposalId, proposal) }, resourcePath: proposalPath };
    });
    send(res, data, 201);
  });

  // GET /proposals/:proposalId — 청혼 당사자만 상세와 임시 부모 형질 미리보기를 조회한다.
  router.get("/proposals/:proposalId", async (req, res) => {
    const uid: string = res.locals.uid;
    const { proposalId } = req.params;
    if (!isId(proposalId)) throw badRequest("proposalId 형식이 올바르지 않습니다.");
    const snap = await db.doc(paths.proposal(proposalId)).get();
    if (!snap.exists) throw new ApiError(404, "NOT_FOUND", "청혼을 찾을 수 없습니다.");
    const proposal = snap.data() as Proposal;
    if (uid !== proposal.senderUid && uid !== proposal.recipientUid) throw new ApiError(403, "FORBIDDEN", "청혼 당사자만 조회할 수 있습니다.");
    const [senderPetSnap, recipientPetSnap] = await Promise.all([
      db.doc(paths.pet(proposal.senderUid, proposal.senderPetId)).get(),
      db.doc(paths.pet(proposal.recipientUid, proposal.recipientPetId)).get(),
    ]);
    if (!senderPetSnap.exists || !recipientPetSnap.exists) throw new ApiError(404, "NOT_FOUND", "청혼 반려동물 정보를 찾을 수 없습니다.");
    const senderPet = senderPetSnap.data() as Pet;
    const recipientPet = recipientPetSnap.data() as Pet;
    const parentTraitLabels = [...new Set([...traitLabels(senderPet), ...traitLabels(recipientPet)])].slice(0, 4);
    send(res, {
      proposal: proposalDto(proposalId, proposal),
      eggPreview: { parentTraitLabels, isGuaranteed: false },
    });
  });

  // POST /proposals/:proposalId/accept — 가족과 양쪽 사용자 소유의 비활성 알을 함께 만든다.
  router.post("/proposals/:proposalId/accept", async (req, res) => {
    const uid: string = res.locals.uid;
    const { proposalId } = req.params;
    if (!isId(proposalId)) throw badRequest("proposalId 형식이 올바르지 않습니다.");
    const senderEggId = randomUUID();
    const recipientEggId = randomUUID();
    const data = await runCommand(db, req, res, async tx => {
      const proposalRef = db.doc(paths.proposal(proposalId));
      const proposalSnap = await tx.get(proposalRef);
      if (!proposalSnap.exists) throw new ApiError(404, "NOT_FOUND", "청혼을 찾을 수 없습니다.");
      const proposal = proposalSnap.data() as Proposal;
      if (uid !== proposal.recipientUid) throw new ApiError(403, "FORBIDDEN", "청혼을 받은 사용자만 수락할 수 있습니다.");
      if (proposal.status !== "PENDING") throw new ApiError(409, "PROPOSAL_NOT_PENDING", "이미 처리된 청혼입니다.");

      const [sender, recipient] = await Promise.all([
        requireUser(db, proposal.senderUid, tx),
        requireUser(db, proposal.recipientUid, tx),
      ]);
      await requireFriendship(db, proposal.senderUid, proposal.recipientUid, tx);
      if (sender.activePetId !== proposal.senderPetId || recipient.activePetId !== proposal.recipientPetId) {
        throw new ApiError(409, "PET_NOT_ACTIVE", "청혼 당시의 반려동물이 더 이상 활성 상태가 아닙니다.");
      }
      const senderPetRef = db.doc(paths.pet(proposal.senderUid, proposal.senderPetId));
      const recipientPetRef = db.doc(paths.pet(proposal.recipientUid, proposal.recipientPetId));
      const pairId = proposalPairId(proposal.senderUid, proposal.senderPetId, proposal.recipientUid, proposal.recipientPetId);
      const pendingKeyRef = db.doc(paths.pendingProposalKey(pairId));
      const ruleRef = db.doc(paths.growthRule(DEFAULT_GROWTH_RULE.id));
      const [senderPetSnap, recipientPetSnap, pendingSnap, ruleSnap] = await Promise.all([
        tx.get(senderPetRef),
        tx.get(recipientPetRef),
        tx.get(pendingKeyRef),
        tx.get(ruleRef),
      ]);
      if (!senderPetSnap.exists || !recipientPetSnap.exists) throw new ApiError(404, "NOT_FOUND", "청혼 반려동물 정보를 찾을 수 없습니다.");
      const senderPet = senderPetSnap.data() as Pet;
      const recipientPet = recipientPetSnap.data() as Pet;
      if (senderPet.stage !== "ADULT" || recipientPet.stage !== "ADULT") {
        throw new ApiError(409, "PET_NOT_ADULT", "두 반려동물 모두 어른 단계여야 합니다.");
      }
      if (!pendingSnap.exists || (pendingSnap.data() as PendingProposalKey).proposalId !== proposalId) {
        throw new ApiError(409, "PROPOSAL_NOT_PENDING", "대기 중인 청혼 정보가 없습니다.");
      }
      if (!ruleSnap.exists) throw new ApiError(503, "TEMPORARILY_UNAVAILABLE", "성장 규칙이 준비되지 않았습니다.");

      const now = Timestamp.now();
      const familyId = proposalId;
      const family: Family = {
        proposalId,
        parentPetAId: proposal.senderPetId,
        parentPetBId: proposal.recipientPetId,
        parentUserAUid: proposal.senderUid,
        parentUserBUid: proposal.recipientUid,
        createdAt: now,
      };
      const senderEgg = newEgg(familyId, now);
      const recipientEgg = newEgg(familyId, now);
      const nextProposal: Proposal = { ...proposal, status: "ACCEPTED", familyId, resolvedAt: now };
      const familyPath = paths.family(familyId);
      tx.update(proposalRef, { status: "ACCEPTED", familyId, resolvedAt: now });
      tx.delete(pendingKeyRef);
      tx.create(db.doc(familyPath), family);
      tx.create(db.doc(paths.pet(proposal.senderUid, senderEggId)), senderEgg);
      tx.create(db.doc(paths.pet(proposal.recipientUid, recipientEggId)), recipientEgg);
      tx.create(db.doc(paths.notification(proposal.senderUid, `${proposalId}-accepted`)), notification(
        "PROPOSAL", "청혼이 수락됐어요", `${recipient.nickname}님이 청혼을 수락했어요.`, proposalId, now,
      ));
      const rule = ruleSnap.data() as Awaited<ReturnType<typeof loadRule>>;
      return {
        data: {
          proposal: proposalDto(proposalId, nextProposal),
          familyId,
          myEgg: petDto(recipientEggId, proposal.recipientUid, recipientEgg, rule),
        },
        resourcePath: familyPath,
      };
    });
    send(res, data);
  });

  // POST /proposals/:proposalId/decline — 수신자만 거절할 수 있다.
  router.post("/proposals/:proposalId/decline", async (req, res) => {
    const data = await resolveProposal(db, req, res, "DECLINED");
    send(res, data);
  });

  // POST /proposals/:proposalId/cancel — 발신자만 취소할 수 있다.
  router.post("/proposals/:proposalId/cancel", async (req, res) => {
    const data = await resolveProposal(db, req, res, "CANCELED");
    send(res, data);
  });

  return router;
}

async function resolveProposal(db: Firestore, req: Request, res: Response, status: "DECLINED" | "CANCELED") {
  const uid: string = res.locals.uid;
  const { proposalId } = req.params;
  if (!isId(proposalId)) throw badRequest("proposalId 형식이 올바르지 않습니다.");
  return runCommand(db, req, res, async tx => {
    const proposalRef = db.doc(paths.proposal(proposalId));
    const proposalSnap = await tx.get(proposalRef);
    if (!proposalSnap.exists) throw new ApiError(404, "NOT_FOUND", "청혼을 찾을 수 없습니다.");
    const proposal = proposalSnap.data() as Proposal;
    const actorIsAllowed = status === "DECLINED" ? uid === proposal.recipientUid : uid === proposal.senderUid;
    if (!actorIsAllowed) throw new ApiError(403, "FORBIDDEN", status === "DECLINED" ? "청혼을 받은 사용자만 거절할 수 있습니다." : "청혼을 보낸 사용자만 취소할 수 있습니다.");
    if (proposal.status !== "PENDING") throw new ApiError(409, "PROPOSAL_NOT_PENDING", "이미 처리된 청혼입니다.");
    const pairId = proposalPairId(proposal.senderUid, proposal.senderPetId, proposal.recipientUid, proposal.recipientPetId);
    const pendingKeyRef = db.doc(paths.pendingProposalKey(pairId));
    const targetUid = status === "DECLINED" ? proposal.senderUid : proposal.recipientUid;
    const [pendingSnap, actor] = await Promise.all([
      tx.get(pendingKeyRef),
      requireUser(db, uid, tx),
    ]);
    if (!pendingSnap.exists || (pendingSnap.data() as PendingProposalKey).proposalId !== proposalId) {
      throw new ApiError(409, "PROPOSAL_NOT_PENDING", "대기 중인 청혼 정보가 없습니다.");
    }
    const now = Timestamp.now();
    const nextProposal: Proposal = { ...proposal, status, resolvedAt: now };
    const notificationId = `${proposalId}-${status.toLowerCase()}`;
    const title = status === "DECLINED" ? "청혼이 거절됐어요" : "청혼이 취소됐어요";
    const body = status === "DECLINED" ? `${actor.nickname}님이 청혼을 거절했어요.` : `${actor.nickname}님이 청혼을 취소했어요.`;
    const resourcePath = paths.proposal(proposalId);
    tx.update(proposalRef, { status, resolvedAt: now });
    tx.delete(pendingKeyRef);
    tx.create(db.doc(paths.notification(targetUid, notificationId)), notification("PROPOSAL", title, body, proposalId, now));
    return { data: { proposal: proposalDto(proposalId, nextProposal) }, resourcePath };
  });
}
