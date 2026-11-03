import { applicationDefault, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

/** Explicit project selection prevents accidental writes to a default project. */
export function connectFirestore(projectId: string) {
  if (!projectId || projectId.includes("/")) throw new Error("FIREBASE_PROJECT_ID is required");
  const name = `pocketwalk-${projectId}`;
  const existing = getApps().find(app => app.name === name);
  const app = existing ?? initializeApp({ projectId, credential: applicationDefault() }, name);
  return getFirestore(app);
}
