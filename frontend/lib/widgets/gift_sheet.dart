import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

const _giftBg = AppColors.peach;
const _giftIcon = Color(0xFF99785B);

/// 친구에게 선물: 내 보관함에서 하나 고르면 1개를 보낸다 (친구 목록·놀러 가기에서 같이 씀)
Future<void> sendGift(BuildContext context, Friend friend) async {
  void toast(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  List<InventoryItem> items;
  try {
    items = (await Api.instance.inventory()).where((i) => i.quantity > 0).toList();
  } catch (e) {
    toast('$e');
    return;
  }
  if (!context.mounted) return;
  if (items.isEmpty) {
    toast('보관함이 비어 있어요. 상점에서 먼저 사 주세요');
    return;
  }
  final picked = await showModalBottomSheet<InventoryItem>(
    context: context,
    backgroundColor: AppColors.bg,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${friend.nickname}님에게 보낼 선물',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('하나를 고르면 1개가 바로 전달돼요', style: AppText.caption),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final it = items[i];
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, it),
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: _giftBg, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.card_giftcard, size: 20, color: _giftIcon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.name, style: AppText.cardTitle),
                                Text(it.effectText, style: AppText.tiny),
                              ],
                            ),
                          ),
                          Text('× ${it.quantity}', style: AppText.badge),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (picked == null) return;
  try {
    await Api.instance.gift(recipientUid: friend.uid, itemId: picked.itemId);
    toast('${friend.nickname}님에게 ${picked.name}${josa(picked.name, '을', '를')} 보냈어요!');
  } on ApiException catch (e) {
    toast(e.code == 'INSUFFICIENT_ITEMS' ? '보관함에 남은 게 없어요' : e.message);
  } catch (e) {
    toast('$e');
  }
}
