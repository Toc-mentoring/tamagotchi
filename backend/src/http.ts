import { randomUUID } from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import type { Auth } from "firebase-admin/auth";

/** API 오류. 응답은 { error: { code, message, details, requestId } } */
export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details: Record<string, unknown> = {}) {
    super(message);
  }
}
export const badRequest = (message: string) => new ApiError(400, "INVALID_ARGUMENT", message);

/** 문서 ID로 쓸 수 있는 값인지 */
export function isId(value: unknown): value is string {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

export function requestId(_req: Request, res: Response, next: NextFunction) {
  res.locals.requestId = `req_${randomUUID()}`;
  next();
}

/** 성공 응답 { data, meta } */
export function send(res: Response, data: unknown, status = 200, extraMeta: Record<string, unknown> = {}) {
  res.status(status).json({ data, meta: { requestId: res.locals.requestId, ...extraMeta } });
}

/**
 * Firebase ID 토큰 검증 → res.locals.uid
 * 로컬 개발용: 환경 변수 DEV_AUTH_UID가 있으면 토큰 없는 요청을 그 사용자로 처리한다.
 */
export function authenticate(auth: Auth) {
  const devUid = process.env.DEV_AUTH_UID;
  if (devUid) console.warn(`⚠ 개발 모드: 토큰 없는 요청을 '${devUid}' 사용자로 처리합니다.`);
  return async (req: Request, res: Response, next: NextFunction) => {
    const token = /^Bearer (.+)$/.exec(req.get("authorization") ?? "")?.[1];
    if (token) {
      try {
        res.locals.uid = (await auth.verifyIdToken(token)).uid;
        return next();
      } catch {
        return next(new ApiError(401, "UNAUTHENTICATED", "로그인 정보가 유효하지 않습니다."));
      }
    }
    if (devUid) {
      res.locals.uid = devUid;
      return next();
    }
    next(new ApiError(401, "UNAUTHENTICATED", "로그인이 필요합니다."));
  };
}

export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  let e: ApiError;
  if (err instanceof ApiError) e = err;
  else if (err instanceof SyntaxError) e = badRequest("JSON 형식이 올바르지 않습니다.");
  else {
    console.error(err);
    e = new ApiError(500, "INTERNAL", "서버 오류가 발생했습니다.");
  }
  res.status(e.status).json({ error: { code: e.code, message: e.message, details: e.details, requestId: res.locals.requestId } });
}
