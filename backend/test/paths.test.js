const { test } = require("node:test");
const assert = require("node:assert/strict");
const { paths, friendshipId, proposalPairId } = require("../lib/paths");

test("pair IDs are deterministic, unambiguous and owner-scoped", () => {
  assert.equal(friendshipId("a", "b"), friendshipId("b", "a"));
  assert.notEqual(friendshipId("a", "bc"), friendshipId("ab", "c"));
  assert.equal(proposalPairId("a", "pet", "b", "pet"), proposalPairId("b", "pet", "a", "pet"));
  assert.notEqual(proposalPairId("a", "pet", "b", "pet"), proposalPairId("a", "pet", "c", "pet"));
  assert.throws(() => friendshipId("a", "a"));
});
test("paths reject invalid segments", () => {
  assert.equal(paths.wallet("user"), "users/user/wallet/main");
  for (const bad of ["", "a/b", ".", "..", "__reserved__"]) assert.throws(() => paths.user(bad));
});
