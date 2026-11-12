import { Timestamp, type Firestore, type Transaction } from "firebase-admin/firestore";
import { dateIn } from "./dates";
import { ApiError } from "./http";
import type { Friendship, Pet, StepDay, User } from "./models";
import { friendshipId, paths } from "./paths";

export interface FriendSummary {
  uid: string;
  user: User;
  pet: Pet | null;
  today: StepDay | null;
}

export async function loadFriendSummary(db: Firestore, uid: string, tx?: Transaction): Promise<FriendSummary> {
  const userRef = db.doc(paths.user(uid));
  const userSnap = tx ? await tx.get(userRef) : await userRef.get();
  if (!userSnap.exists) throw new ApiError(404, "NOT_FOUND", "사용자를 찾을 수 없습니다.");
  const user = userSnap.data() as User;
  const refs = [
    user.activePetId ? db.doc(paths.pet(uid, user.activePetId)) : null,
    db.doc(paths.stepDay(uid, dateIn())),
  ];
  const petRef = refs[0];
  const dayRef = refs[1]!;
  const [petSnap, daySnap] = await Promise.all([
    petRef ? (tx ? tx.get(petRef) : petRef.get()) : Promise.resolve(null),
    tx ? tx.get(dayRef) : dayRef.get(),
  ]);
  return {
    uid,
    user,
    pet: petSnap?.exists ? petSnap.data() as Pet : null,
    today: daySnap.exists ? daySnap.data() as StepDay : null,
  };
}

export function friendDto(summary: FriendSummary) {
  const petId = summary.user.activePetId;
  const pet = petId && summary.pet
    ? { id: petId, name: summary.pet.name, stage: summary.pet.stage, speciesId: summary.pet.speciesId, careScore: null }
    : null;
  return {
    uid: summary.uid,
    nickname: summary.user.nickname,
    pet,
    todaySteps: summary.today?.totalSteps ?? null,
    lastSeenAt: summary.user.lastSeenAt instanceof Timestamp ? summary.user.lastSeenAt.toDate().toISOString() : null,
  };
}

export async function requireFriendship(db: Firestore, uid: string, friendUid: string, tx?: Transaction): Promise<Friendship> {
  if (uid === friendUid) throw new ApiError(403, "NOT_FRIENDS", "자기 자신과는 친구 기능을 사용할 수 없습니다.");
  const ref = db.doc(paths.friendship(friendshipId(uid, friendUid)));
  const snap = tx ? await tx.get(ref) : await ref.get();
  if (!snap.exists || snap.get("status") !== "ACTIVE") throw new ApiError(403, "NOT_FRIENDS", "친구 관계가 아닙니다.");
  return snap.data() as Friendship;
}
