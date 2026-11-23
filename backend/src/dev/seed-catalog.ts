import { connectFirestore } from "../db";
import type { Item, Product } from "../models";
import { paths } from "../paths";

// 상점 상품 데이터 (Figma 산책 상점 화면의 예시 상품). 이름·가격·효과는 모두 임시값 (docs/open-decisions.md D17)
// 다시 실행하면 같은 ID 문서를 덮어써서 최신 값으로 맞춘다. 사용자 데이터는 건드리지 않는다.
const CATALOG: Array<{ id: string; item: Omit<Item, "effectRuleVersion" | "imageUrl" | "active">; price: number }> = [
  { id: "carrot", item: { name: "아삭 당근", category: "FOOD", effectDefinition: { effectText: "포만감 +20", satiety: 20 } }, price: 60 },
  { id: "berry", item: { name: "숲속 베리", category: "FOOD", effectDefinition: { effectText: "포만감 +15 · 행복 +5", satiety: 15, happiness: 5 } }, price: 90 },
  { id: "moon_egg", item: { name: "달빛 희귀 알", category: "RARE_EGG", effectDefinition: { effectText: "새로운 친구와의 만남" } }, price: 900 },
  { id: "ball", item: { name: "데굴데굴 공", category: "TOY", effectDefinition: { effectText: "함께 놀면 행복 +15", happiness: 15 } }, price: 180 },
  { id: "sandwich", item: { name: "든든 샌드위치", category: "FOOD", effectDefinition: { effectText: "포만감 +35", satiety: 35 } }, price: 120 },
  { id: "star_wand", item: { name: "별빛 장난감", category: "TOY", effectDefinition: { effectText: "호기심 가득한 놀이 시간", happiness: 10 } }, price: 250 },
];

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) throw new Error("FIREBASE_PROJECT_ID를 설정하세요");
  if (!process.env.FIRESTORE_EMULATOR_HOST && process.env.ALLOW_LIVE_SEED !== projectId) {
    throw new Error("실제 DB에 넣으려면 ALLOW_LIVE_SEED에 프로젝트 ID를 똑같이 설정하세요");
  }
  const db = connectFirestore(projectId);
  try {
    const batch = db.batch();
    CATALOG.forEach(({ id, item, price }, i) => {
      const fullItem: Item = { ...item, effectRuleVersion: "v0", imageUrl: null, active: true };
      const product: Product = { itemId: id, price, available: true, displayOrder: i + 1 };
      batch.set(db.doc(paths.item(id)), fullItem);
      batch.set(db.doc(paths.product(id)), product);
    });
    await batch.commit();
    console.log(`${projectId}: 상점 상품 ${CATALOG.length}개 준비 완료`);
  } finally {
    await db.terminate();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
