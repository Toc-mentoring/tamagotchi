import type { InventoryItem, Item, Product } from "./models";
import { Timestamp } from "firebase-admin/firestore";

function effectText(item: Item): string {
  const value = item.effectDefinition.effectText;
  return typeof value === "string" ? value : "";
}

export function productDto(id: string, product: Product, item: Item) {
  return {
    id,
    itemId: product.itemId,
    name: item.name,
    category: item.category,
    price: product.price,
    effectText: effectText(item),
    imageUrl: item.imageUrl,
    available: product.available && item.active,
  };
}

export function inventoryDto(itemId: string, inventory: InventoryItem, item: Item) {
  return {
    itemId,
    name: item.name,
    category: item.category,
    quantity: inventory.quantity,
    effectText: effectText(item),
    imageUrl: item.imageUrl,
    updatedAt: inventory.updatedAt instanceof Timestamp ? inventory.updatedAt.toDate().toISOString() : null,
  };
}
