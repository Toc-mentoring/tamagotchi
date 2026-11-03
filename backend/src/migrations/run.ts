import { FieldValue } from "firebase-admin/firestore";
import { connectFirestore } from "../db";
import { initialMigration } from "./001_initial";

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) throw new Error("Set FIREBASE_PROJECT_ID explicitly");
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.ALLOW_LIVE_MIGRATION !== projectId) {
    throw new Error("For a live database set ALLOW_LIVE_MIGRATION to the exact project ID");
  }
  const db = connectFirestore(projectId);
  try {
    const record = db.doc("schemaMigrations/001_initial");
    const applied = await db.runTransaction(async tx => {
      const [migration, schema] = await Promise.all([tx.get(record), tx.get(db.doc("system/schema"))]);
      if (migration.exists) {
        if (!schema.exists || typeof schema.get("version") !== "number" || schema.get("version") < 1) throw new Error("Migration record and schema metadata disagree");
        return false;
      }
      if (schema.exists) throw new Error("Schema metadata exists without migration record; inspect before proceeding");
      initialMigration(db, tx);
      tx.create(record, { version: 1, appliedAt: FieldValue.serverTimestamp() });
      return true;
    });
    console.log(`${projectId}: ${applied ? "applied" : "already applied"} 001_initial`);
  } finally {
    await db.terminate();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
