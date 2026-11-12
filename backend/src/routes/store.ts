import { Router } from "express";
import { Timestamp, type Firestore } from "firebase-admin/firestore";
import { inventoryDto, productDto } from "../catalog";
import { dateIn } from "../dates";
import { ApiError, badRequest, isId, send } from "../http";
import { runCommand } from "../idempotency";
import type { InventoryItem, Item, PointTransaction, Product, Purchase, Wallet } from "../models";
import { paginate, pageCursor, pageLimit } from "../pagination";
import { paths } from "../paths";
import { requireUser, sumEarned, todayEarnedQuery } from "../store";

const CATEGORIES = ["FOOD", "RARE_EGG", "TOY", "MEDICINE"] as const;

export function storeRoutes(db: Firestore) {
  const router = Router();

  // GET /products — 판매 중인 상품과 아이템 정의를 결합한다.
  router.get("/products", async (req, res) => {
    const category = String(req.query.category ?? "ALL");
    if (category !== "ALL" && !CATEGORIES.includes(category as typeof CATEGORIES[number])) {
      throw badRequest("category는 ALL, FOOD, RARE_EGG, TOY, MEDICINE 중 하나여야 합니다.");
    }
    const productsSnap = await db.collection("products").get();
    const products = productsSnap.docs
      .map(doc => ({ id: doc.id, data: doc.data() as Product }))
      .filter(row => row.data.available)
      .sort((a, b) => a.data.displayOrder - b.data.displayOrder || a.id.localeCompare(b.id));
    const itemSnaps = products.length
      ? await db.getAll(...products.map(row => db.doc(paths.item(row.data.itemId))))
      : [];
    const items = products.flatMap((row, i) => {
      const itemSnap = itemSnaps[i];
      if (!itemSnap.exists) return [];
      const dto = productDto(row.id, row.data, itemSnap.data() as Item);
      if (!dto.available || (category !== "ALL" && dto.category !== category)) return [];
      return [dto];
    });
    const page = paginate(items, pageLimit(req.query.limit), pageCursor(req.query.cursor), item => item.id);
    send(res, { items: page.items }, 200, { nextCursor: page.nextCursor });
  });

  // GET /inventory — 수량이 남은 아이템을 최근 변경 순으로 반환한다.
  router.get("/inventory", async (req, res) => {
    const uid: string = res.locals.uid;
    await requireUser(db, uid);
    const inventorySnap = await db.collection(`${paths.user(uid)}/inventory`).get();
    const inventory = inventorySnap.docs
      .map(doc => ({ id: doc.id, data: doc.data() as InventoryItem }))
      .filter(row => row.data.quantity > 0)
      .sort((a, b) => b.data.updatedAt.toMillis() - a.data.updatedAt.toMillis() || a.id.localeCompare(b.id));
    const itemSnaps = inventory.length
      ? await db.getAll(...inventory.map(row => db.doc(paths.item(row.id))))
      : [];
    const items = inventory.map((row, i) => {
      if (!itemSnaps[i].exists) throw new Error(`items/${row.id} inventory reference is missing`);
      return inventoryDto(row.id, row.data, itemSnaps[i].data() as Item);
    });
    const page = paginate(items, pageLimit(req.query.limit), pageCursor(req.query.cursor), item => item.itemId);
    send(res, { items: page.items }, 200, { nextCursor: page.nextCursor });
  });

  // POST /purchases — 잔액, 구매 이력, 포인트 원장과 보관함을 원자적으로 변경한다.
  router.post("/purchases", async (req, res) => {
    const uid: string = res.locals.uid;
    const { productId, quantity } = req.body ?? {};
    if (!isId(productId)) throw badRequest("productId 형식이 올바르지 않습니다.");
    if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 99) throw badRequest("quantity는 1~99의 정수여야 합니다.");

    const data = await runCommand(db, req, res, async (tx, commandId) => {
      await requireUser(db, uid, tx);
      const productRef = db.doc(paths.product(productId));
      const productSnap = await tx.get(productRef);
      if (!productSnap.exists) throw new ApiError(404, "NOT_FOUND", "상품을 찾을 수 없습니다.");
      const product = productSnap.data() as Product;
      const walletRef = db.doc(paths.wallet(uid));
      const inventoryRef = db.doc(paths.inventory(uid, product.itemId));
      const [itemSnap, walletSnap, inventorySnap, earnedSnap] = await Promise.all([
        tx.get(db.doc(paths.item(product.itemId))),
        tx.get(walletRef),
        tx.get(inventoryRef),
        tx.get(todayEarnedQuery(db, uid, dateIn())),
      ]);
      if (!itemSnap.exists || !product.available || !itemSnap.get("active")) {
        throw new ApiError(409, "PRODUCT_UNAVAILABLE", "현재 구매할 수 없는 상품입니다.");
      }
      if (!walletSnap.exists) throw new ApiError(409, "USER_DATA_INCOMPLETE", "지갑 정보가 없습니다.");
      const item = itemSnap.data() as Item;
      const balance = Number(walletSnap.get("balance") ?? 0);
      const totalPrice = product.price * quantity;
      if (!Number.isSafeInteger(product.price) || product.price < 0 || !Number.isSafeInteger(totalPrice)) {
        throw new Error(`products/${productId} has an invalid price`);
      }
      if (balance < totalPrice) {
        throw new ApiError(409, "INSUFFICIENT_POINTS", "포인트가 부족합니다.", { balance, required: totalPrice });
      }

      const now = Timestamp.now();
      const purchaseId = commandId;
      const nextWallet: Wallet = { balance: balance - totalPrice };
      const nextInventory: InventoryItem = {
        quantity: Number(inventorySnap.get("quantity") ?? 0) + quantity,
        updatedAt: now,
      };
      const purchase: Purchase = {
        productId,
        itemId: product.itemId,
        quantity,
        unitPrice: product.price,
        totalPrice,
        commandId,
        createdAt: now,
      };
      const point: PointTransaction = {
        amount: -totalPrice,
        type: "PURCHASE",
        sourceId: purchaseId,
        commandId,
        createdAt: now,
      };

      tx.set(walletRef, nextWallet);
      tx.set(inventoryRef, nextInventory);
      tx.create(db.doc(paths.purchase(uid, purchaseId)), purchase);
      tx.create(db.doc(paths.pointTransaction(uid, commandId)), point);

      return {
        data: {
          purchaseId,
          wallet: { ...nextWallet, todayEarned: sumEarned(earnedSnap) },
          inventoryItem: inventoryDto(product.itemId, nextInventory, item),
        },
        resourcePath: paths.purchase(uid, purchaseId),
      };
    });
    send(res, data, 201);
  });

  // GET /wallet/transactions — 지급·사용 원장.
  router.get("/wallet/transactions", async (req, res) => {
    const uid: string = res.locals.uid;
    await requireUser(db, uid);
    const snap = await db.collection(`${paths.user(uid)}/pointTransactions`).get();
    const items = snap.docs
      .map(doc => ({
        id: doc.id,
        amount: Number(doc.get("amount") ?? 0),
        type: String(doc.get("type") ?? ""),
        sourceId: String(doc.get("sourceId") ?? ""),
        stepDate: doc.get("stepDate") ?? null,
        createdAt: (doc.get("createdAt") as Timestamp).toDate().toISOString(),
      }))
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.id.localeCompare(b.id));
    const page = paginate(items, pageLimit(req.query.limit), pageCursor(req.query.cursor), item => item.id);
    send(res, { items: page.items }, 200, { nextCursor: page.nextCursor });
  });

  return router;
}
