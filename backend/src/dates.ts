// 날짜 계산. 일자 기준은 임시로 Asia/Seoul (docs/open-decisions.md D13)
export const TIME_ZONE = "Asia/Seoul";

/** 해당 시각의 서울 날짜 (YYYY-MM-DD) */
export function dateIn(at: Date = new Date()): string {
  return at.toLocaleDateString("sv-SE", { timeZone: TIME_ZONE });
}

/** 올바른 YYYY-MM-DD 날짜인지 (2026-02-30 같은 값은 거절) */
export function isDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const d = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** endDate를 포함한 최근 count일 (오래된 날짜부터) */
export function dateRange(endDate: string, count: number): string[] {
  return Array.from({ length: count }, (_, i) => addDays(endDate, i - count + 1));
}

/** 서울 기준 그날 0시 (서울은 서머타임이 없어 +09:00 고정) */
export function startOfDay(date: string): Date {
  return new Date(`${date}T00:00:00+09:00`);
}