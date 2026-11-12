import { badRequest } from "./http";

export function pageLimit(value: unknown): number {
  if (value === undefined) return 20;
  if (typeof value !== "string" || !/^\d+$/.test(value)) throw badRequest("limit은 1~100의 정수여야 합니다.");
  const limit = Number(value);
  if (!Number.isSafeInteger(limit) || limit < 1 || limit > 100) throw badRequest("limit은 1~100의 정수여야 합니다.");
  return limit;
}

export function pageCursor(value: unknown): string | null {
  if (value === undefined) return null;
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) throw badRequest("cursor 형식이 올바르지 않습니다.");
  return value;
}

export function paginate<T>(items: T[], limit: number, cursor: string | null, idOf: (item: T) => string) {
  let start = 0;
  if (cursor !== null) {
    const index = items.findIndex(item => idOf(item) === cursor);
    if (index < 0) throw badRequest("cursor가 현재 결과에 없습니다.");
    start = index + 1;
  }
  const page = items.slice(start, start + limit);
  const nextCursor = start + limit < items.length && page.length ? idOf(page[page.length - 1]) : null;
  return { items: page, nextCursor };
}
