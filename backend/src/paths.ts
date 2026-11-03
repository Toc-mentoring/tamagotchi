import { createHash } from "node:crypto";

function segment(value: string): string {
  if (!value || value.includes("/") || value === "." || value === ".." || /^__.*__$/.test(value) || Buffer.byteLength(value, "utf8") > 1500) throw new Error("Invalid Firestore path segment");
  return value;
}
export const paths = {
  user: (uid: string) => `users/${segment(uid)}`,
  friendCode: (code: string) => `friendCodes/${segment(code)}`,
  device: (uid: string, id: string) => `users/${segment(uid)}/devices/${segment(id)}`,
  pet: (uid: string, id: string) => `users/${segment(uid)}/pets/${segment(id)}`,
  petEvent: (uid: string, petId: string, id: string) => `users/${segment(uid)}/pets/${segment(petId)}/events/${segment(id)}`,
  stepDay: (uid: string, date: string) => `users/${segment(uid)}/stepDays/${segment(date)}`,
  wallet: (uid: string) => `users/${segment(uid)}/wallet/main`,
  pointTransaction: (uid: string, id: string) => `users/${segment(uid)}/pointTransactions/${segment(id)}`,
  inventory: (uid: string, itemId: string) => `users/${segment(uid)}/inventory/${segment(itemId)}`,
  purchase: (uid: string, id: string) => `users/${segment(uid)}/purchases/${segment(id)}`,
  visit: (uid: string, id: string) => `users/${segment(uid)}/visits/${segment(id)}`,
  discovery: (uid: string, speciesId: string) => `users/${segment(uid)}/discoveries/${segment(speciesId)}`,
  notification: (uid: string, id: string) => `users/${segment(uid)}/notifications/${segment(id)}`,
  item: (id: string) => `items/${segment(id)}`,
  product: (id: string) => `products/${segment(id)}`,
  species: (id: string) => `species/${segment(id)}`,
  growthRule: (id: string) => `growthRules/${segment(id)}`,
  friendship: (id: string) => `friendships/${segment(id)}`,
  gift: (id: string) => `gifts/${segment(id)}`,
  proposal: (id: string) => `proposals/${segment(id)}`,
  pendingProposalKey: (id: string) => `pendingProposalKeys/${segment(id)}`,
  family: (id: string) => `families/${segment(id)}`,
  outbox: (id: string) => `notificationOutbox/${segment(id)}`,
  idempotency: (id: string) => `idempotency/${segment(id)}`,
  command: (id: string) => `commands/${segment(id)}`,
};
function hashPair(a: string, b: string): string {
  if (a === b) throw new Error("Pair members must differ");
  return createHash("sha256").update(JSON.stringify([a, b].sort())).digest("hex");
}
export const friendshipId = (uidA: string, uidB: string) => hashPair(segment(uidA), segment(uidB));
// Pet IDs are only unique within their owner path.
export const proposalPairId = (uidA: string, petA: string, uidB: string, petB: string) =>
  hashPair(paths.pet(uidA, petA), paths.pet(uidB, petB));
