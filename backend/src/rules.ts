import type { PetStage, PetStats } from "./models";

// ⚠ 아래 값은 모두 임시값이다 (docs/open-decisions.md). 기획이 확정되면 이 파일만 고친다.
export const DEFAULT_GOAL_STEPS = 8000; // D03 하루 목표
export const STEPS_PER_POINT = 100;     // D04 100걸음당 1P
export const SYNC_WINDOW_DAYS = 7;      // D09 오늘 포함 최근 7일만 동기화
export const INITIAL_STATS: PetStats = { satiety: 70, happiness: 70, cleanliness: 70, health: 70 }; // D14 부화 직후 상태

// D05 단계별 누적 걸음. seed가 growthRules/v0 문서로 저장한다.
export const DEFAULT_GROWTH_RULE = {
  id: "v0",
  thresholds: [
    { stage: "EGG" as PetStage, cumulativeSteps: 0 },
    { stage: "BABY" as PetStage, cumulativeSteps: 8000 },
    { stage: "TEEN" as PetStage, cumulativeSteps: 30000 },
    { stage: "ADULT" as PetStage, cumulativeSteps: 80000 },
  ],
};

export type CareAction = "FEED" | "CLEAN" | "PLAY" | "MEDICINE" | "SLEEP";
// D14 돌봄 행동별 상태 변화
export const CARE_EFFECTS: Record<CareAction, Partial<PetStats>> = {
  FEED: { satiety: 20 },
  CLEAN: { cleanliness: 30 },
  PLAY: { happiness: 15, satiety: -5 },
  MEDICINE: { health: 30 },
  SLEEP: { health: 10, happiness: 5 },
};

const ORDER: PetStage[] = ["EGG", "BABY", "TEEN", "ADULT"];
export const TRANSITION: Record<PetStage, string> = { EGG: "", BABY: "HATCHED", TEEN: "BECAME_TEEN", ADULT: "BECAME_ADULT" };
type Threshold = { stage: PetStage; cumulativeSteps: number };

/** 기존 최대 → 새 최대로 늘었을 때 줄 포인트 */
export function pointsFor(oldHighWater: number, newHighWater: number): number {
  return Math.floor(newHighWater / STEPS_PER_POINT) - Math.floor(oldHighWater / STEPS_PER_POINT);
}

/** 현재 단계 다음 기준들 (가까운 순) */
function upcoming(stage: PetStage, thresholds: Threshold[]): Threshold[] {
  return thresholds
    .filter(t => ORDER.indexOf(t.stage) > ORDER.indexOf(stage))
    .sort((a, b) => ORDER.indexOf(a.stage) - ORDER.indexOf(b.stage));
}

/** 누적 걸음으로 새로 도달한 단계들. 한 번에 여러 단계를 넘으면 순서대로 */
export function reachedStages(stage: PetStage, growthSteps: number, thresholds: Threshold[]): PetStage[] {
  const reached: PetStage[] = [];
  for (const t of upcoming(stage, thresholds)) {
    if (growthSteps < t.cumulativeSteps) break;
    reached.push(t.stage);
  }
  return reached;
}

/** 다음 단계까지 진행도. 어른이면 다음 단계 값은 null */
export function stageProgress(stage: PetStage, growthSteps: number, thresholds: Threshold[]) {
  const next = upcoming(stage, thresholds)[0];
  if (!next) return { currentSteps: growthSteps, requiredSteps: null, remainingSteps: null, percent: null, nextStage: null };
  return {
    currentSteps: growthSteps,
    requiredSteps: next.cumulativeSteps,
    remainingSteps: Math.max(0, next.cumulativeSteps - growthSteps),
    percent: Math.min(100, Math.floor((growthSteps / next.cumulativeSteps) * 100)),
    nextStage: next.stage,
  };
}

/** 상태 변화 적용 (0~100). 실제로 바뀐 양도 함께 돌려준다 */
export function applyEffects(stats: PetStats, effects: Partial<PetStats>) {
  const next = { ...stats };
  const applied: Record<string, number> = {};
  for (const [key, delta] of Object.entries(effects) as [keyof PetStats, number][]) {
    const value = Math.min(100, Math.max(0, stats[key] + delta));
    applied[key] = value - stats[key];
    next[key] = value;
  }
  return { stats: next, applied };
}

type DaySnapshot = { totalSteps: number | null; goalSteps: number };

/** 걸음 기록 화면의 합계·평균·목표 달성·지난 기간 대비 */
export function summarize(days: DaySnapshot[], previous: DaySnapshot[]) {
  const synced = days.filter(d => d.totalSteps !== null);
  const totalSteps = synced.reduce((sum, d) => sum + (d.totalSteps ?? 0), 0);
  const previousSynced = previous.filter(d => d.totalSteps !== null);
  const previousTotal = previousSynced.reduce((sum, d) => sum + (d.totalSteps ?? 0), 0);
  const comparable = synced.length === days.length && previousSynced.length === previous.length && previousTotal > 0;
  return {
    totalSteps,
    syncedDays: synced.length,
    averageSteps: synced.length ? Math.round(totalSteps / synced.length) : null,
    goalAchievedDays: synced.filter(d => (d.totalSteps ?? 0) >= d.goalSteps).length,
    previousPeriodSyncedDays: previousSynced.length,
    previousPeriodChangePercent: comparable ? Math.round(((totalSteps - previousTotal) / previousTotal) * 100) : null,
  };
}