import type { Firestore, Transaction } from "firebase-admin/firestore";

// Firestore creates collections lazily. This migration deliberately seeds no game data.
export function initialMigration(db: Firestore, tx: Transaction): void {
  tx.create(db.doc("system/schema"), { version: 1, description: "Initial Firestore schema" });
}
