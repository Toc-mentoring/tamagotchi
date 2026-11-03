import type { Timestamp } from "firebase-admin/firestore";

// Persisted Firestore documents, not API response DTOs. IDs usually come from paths.
export type PetStage = "EGG" | "BABY" | "TEEN" | "ADULT";
export type ProposalStatus = "PENDING" | "ACCEPTED" | "DECLINED" | "CANCELED";
export type NotificationType = "CARE" | "HATCH" | "GROWTH" | "PROPOSAL" | "GIFT" | "WALK_SUMMARY";
export interface NotificationSettings { pushEnabled: boolean; care: boolean; hatch: boolean; growth: boolean; proposal: boolean; gift: boolean; walkSummary: boolean }
export interface User { nickname: string; friendCode: string; activePetId: string | null; stepSourceDeviceId: string | null; timeZone: string; notificationSettings: NotificationSettings; createdAt: Timestamp; lastSeenAt: Timestamp }
export interface FriendCode { uid: string }
export interface Device { platform: "ANDROID" | "IOS"; pushToken: string | null; registeredAt: Timestamp; lastSeenAt: Timestamp }
export interface PetStats { satiety: number; happiness: number; cleanliness: number; health: number }
export interface Pet { name: string; stage: PetStage; speciesId: string | null; familyId: string | null; growthSteps: number; growthRuleVersion: string; stats: PetStats | null; traits: Record<string, unknown>; createdAt: Timestamp }
export interface PetEvent { type: string; commandId: string; createdAt: Timestamp; stepDate?: string; oldHighWater?: number; newHighWater?: number; action?: string; itemId?: string | null; appliedEffects?: Record<string, number> }
export interface StepDay { totalSteps: number; creditedHighWater: number; pointsEarned: number; goalSteps: number; observedAt: Timestamp; lastSyncedAt: Timestamp; sourceDeviceId: string; provider: "HEALTH_CONNECT" | "HEALTHKIT" }
export interface Wallet { balance: number }
export interface PointTransaction { amount: number; type: string; sourceId: string; stepDate?: string; commandId: string; createdAt: Timestamp }
export interface InventoryItem { quantity: number; updatedAt: Timestamp }
export interface Purchase { productId: string; itemId: string; quantity: number; unitPrice: number; totalPrice: number; commandId: string; createdAt: Timestamp }
export interface Item { name: string; category: "FOOD" | "RARE_EGG" | "TOY" | "MEDICINE"; effectRuleVersion: string; effectDefinition: Record<string, unknown>; imageUrl: string | null; active: boolean }
export interface Product { itemId: string; price: number; available: boolean; displayOrder: number }
export interface Species { name: string; traits: Record<string, unknown>; imageUrl: string | null; catalogOrder: number; active: boolean }
// Thresholds and effects are intentionally not fixed until the game policy is decided.
export interface GrowthRule { thresholds: Array<{ stage: PetStage; cumulativeSteps: number }>; effectRuleVersion: string }
export interface Friendship { userA: string; userB: string; memberUids: [string, string]; status: string; createdAt: Timestamp }
export interface Visit { friendUid: string; targetPetId: string | null; commandId: string; createdAt: Timestamp }
export interface Gift { senderUid: string; recipientUid: string; itemId: string; quantity: number; commandId: string; createdAt: Timestamp }
export interface Proposal { senderUid: string; recipientUid: string; senderPetId: string; recipientPetId: string; status: ProposalStatus; familyId: string | null; commandId: string; createdAt: Timestamp; resolvedAt: Timestamp | null }
export interface PendingProposalKey { proposalId: string }
export interface Family { proposalId: string; parentPetAId: string; parentPetBId: string; parentUserAUid: string; parentUserBUid: string; createdAt: Timestamp }
export interface Discovery { source: "OWN_GROWN" | "FRIEND_VISIT"; firstPetId: string; firstOwnerUid: string; firstDiscoveredAt: Timestamp }
export interface Notification { type: NotificationType; title: string; body: string; targetType: string | null; targetId: string | null; createdAt: Timestamp; readAt: Timestamp | null }
export interface Outbox { notificationId: string; recipientUid: string; status: string; attempts: number; nextAttemptAt: Timestamp; createdAt: Timestamp }
export interface IdempotencyRecord { uid: string; method: string; path: string; bodyHash: string; response: unknown; expiresAt: Timestamp }
export interface Command { uid: string; bodyHash: string; resourcePath: string | null; createdAt: Timestamp }
