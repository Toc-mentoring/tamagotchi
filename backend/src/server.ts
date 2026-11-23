import express from "express";
import { getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { connectFirestore } from "./db";
import { ApiError, authenticate, errorHandler, requestId } from "./http";
import { homeRoutes } from "./routes/home";
import { friendRoutes } from "./routes/friends";
import { giftRoutes } from "./routes/gifts";
import { meRoutes } from "./routes/me";
import { proposalRoutes } from "./routes/proposals";
import { storeRoutes } from "./routes/store";
import { stepRoutes } from "./routes/steps";  // 2단계
import { petRoutes } from "./routes/pets";    // 3단계
import { deviceRoutes } from "./routes/devices";

const projectId = process.env.FIREBASE_PROJECT_ID ?? "";
const db = connectFirestore(projectId);
const firebaseApp = getApps().find(a => a.name === `pocketwalk-${projectId}`)!;

const app = express();
app.use(requestId);
// 로컬 개발: 크롬에서 실행한 Flutter 앱(localhost)의 요청 허용
app.use((req, res, next) => {
  const origin = req.get("origin");
  if (origin && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)) {
    res.set({
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers": "Authorization, Content-Type, Idempotency-Key",
      "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
      Vary: "Origin",
    });
    if (req.method === "OPTIONS") return res.sendStatus(204);
  }
  next();
});
app.use(express.json({ limit: "16kb" }));

const v1 = express.Router();
v1.use(authenticate(getAuth(firebaseApp)));
v1.use(meRoutes(db));
v1.use(friendRoutes(db));
v1.use(giftRoutes(db));
v1.use(proposalRoutes(db));
v1.use(storeRoutes(db));
v1.use(homeRoutes(db));
v1.use(stepRoutes(db));  // 2단계
v1.use(petRoutes(db));   // 3단계
v1.use(deviceRoutes(db));
app.use("/v1", v1);

app.use((_req, _res, next) => next(new ApiError(404, "NOT_FOUND", "없는 주소입니다.")));
app.use(errorHandler);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, "127.0.0.1", () => console.log(`API 서버: http://127.0.0.1:${port}/v1  (프로젝트: ${projectId})`));
