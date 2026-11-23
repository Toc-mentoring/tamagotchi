import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

// 지갑 카드 글자색
const _walletLabel = Color(0xFFDFE9D4);
const _walletIcon = Color(0xFFD6E4BD);

// 카테고리 칩 (null = 전체)
const _categories = <(String?, String)>[
  (null, '전체'),
  ('FOOD', '먹이'),
  ('RARE_EGG', '희귀 알'),
  ('TOY', '장난감'),
];

// 상품 그림: 이미지가 아직 없어서 아이콘 + 배경색으로 표시
const _artColors = {
  'carrot': Color(0xFFFCEDDF),
  'berry': Color(0xFFF2EAF2),
  'moon_egg': Color(0xFFEFEBF6),
  'ball': Color(0xFFEAF0DF),
  'sandwich': Color(0xFFFCEDDF),
  'star_wand': Color(0xFFEDF0E6),
};
const _artIcons = {
  'carrot': Icons.eco_outlined,
  'berry': Icons.spa_outlined,
  'moon_egg': Icons.egg_outlined,
  'ball': Icons.sports_baseball_outlined,
  'sandwich': Icons.lunch_dining_outlined,
  'star_wand': Icons.auto_awesome_outlined,
};
const _categoryIcons = {
  'FOOD': Icons.restaurant_outlined,
  'RARE_EGG': Icons.egg_outlined,
  'TOY': Icons.toys_outlined,
  'MEDICINE': Icons.medication_outlined,
};
IconData _iconFor(String itemId, String category) =>
    _artIcons[itemId] ?? _categoryIcons[category] ?? Icons.card_giftcard;

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<(Wallet, List<Product>)> _future = _load();
  String? _category; // null = 전체
  bool _buying = false;

  Future<(Wallet, List<Product>)> _load() async {
    final results = await Future.wait([Api.instance.home(), Api.instance.products()]);
    return ((results[0] as HomeData).wallet, results[1] as List<Product>);
  }

  void _reload() => setState(() => _future = _load());

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // + 버튼 → 확인 → 구매
  Future<void> _buy(Product p, Wallet wallet) async {
    if (_buying) return;
    if (wallet.balance < p.price) {
      _toast('포인트가 ${comma(p.price - wallet.balance)} P 부족해요');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${p.name} 구매', style: AppText.section),
        content: Text('${comma(p.price)} P를 사용해요.\n남는 포인트: ${comma(wallet.balance - p.price)} P', style: AppText.caption),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('구매')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _buying = true);
    try {
      await Api.instance.purchase(p.id);
      _toast('${p.name}${josa(p.name, '을', '를')} 보관함에 넣었어요!');
      _reload();
    } on ApiException catch (e) {
      _toast(e.code == 'INSUFFICIENT_POINTS' ? '포인트가 부족해요' : e.message);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  // 보관함 → 아래에서 올라오는 시트
  void _openInventory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      showDragHandle: true,
      builder: (context) => const _InventorySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Wallet, List<Product>)>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('불러오지 못했어요\n${snap.error}', textAlign: TextAlign.center, style: AppText.caption),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('다시 시도')),
              ],
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final (wallet, products) = snap.data!;
        return RefreshIndicator(onRefresh: () async => _reload(), child: _body(wallet, products));
      },
    );
  }

  Widget _body(Wallet wallet, List<Product> all) {
    final shown = _category == null ? all : all.where((p) => p.category == _category).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      children: [
        // ① 헤더
        SizedBox(
          height: 60,
          child: Row(
            children: [
              const Expanded(child: Text('산책 상점', style: AppText.pageTitle)),
              CircleIconButton(icon: Icons.shopping_bag_outlined, onTap: _openInventory),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ② 지갑 카드
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('걷고 모은 산책 포인트', style: TextStyle(fontSize: 11, height: 1.45, color: _walletLabel)),
                    const SizedBox(height: 2),
                    Text('${comma(wallet.balance)} P',
                        style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700, height: 1.3, color: Colors.white)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.directions_walk, size: 25, color: _walletIcon),
                  const SizedBox(height: 4),
                  Text('오늘 +${comma(wallet.todayEarned)} P',
                      style: const TextStyle(fontSize: 11, height: 1.45, color: _walletLabel)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ③ 섹션 제목 + 보관함
        Row(
          children: [
            const Expanded(
              child: Text('모모를 위한 작은 선물',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
            ),
            GestureDetector(
              onTap: _openInventory,
              child: const Text('보관함 →', style: AppText.caption),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ④ 카테고리 칩
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (value, label) in _categories) ...[
                _Chip(label: label, selected: _category == value, onTap: () => setState(() => _category = value)),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ⑤ 상품 2열 그리드
        if (shown.isEmpty)
          const AppCard(child: Text('아직 준비된 상품이 없어요.', style: AppText.caption))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              mainAxisExtent: 148,
            ),
            itemBuilder: (context, i) => _ProductCard(product: shown[i], onBuy: () => _buy(shown[i], wallet)),
          ),
        const SizedBox(height: 16),
        const Center(child: Text('포인트로만 구매해요 · 가격과 효과는 예시예요', style: AppText.tiny)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.primary : AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.sub)),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onBuy});
  final Product product;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 그림
          Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _artColors[p.itemId] ?? AppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_iconFor(p.itemId, p.category), size: 24, color: AppColors.primary),
          ),
          const SizedBox(height: 6),
          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
          Text(p.effectText, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.tiny),
          const Spacer(),
          // 가격 + 구매 버튼
          Row(
            children: [
              Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Text('P', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(comma(p.price),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
              GestureDetector(
                onTap: p.available ? onBuy : null,
                child: Container(
                  width: 27,
                  height: 26,
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(9)),
                  child: Icon(Icons.add, size: 15, color: p.available ? AppColors.primary : AppColors.disabled),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 보관함 시트 (GET /inventory)
class _InventorySheet extends StatefulWidget {
  const _InventorySheet();

  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  final _future = Api.instance.inventory();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: FutureBuilder<List<InventoryItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return SizedBox(height: 120, child: Center(child: Text('불러오지 못했어요\n${snap.error}', textAlign: TextAlign.center, style: AppText.caption)));
            }
            if (!snap.hasData) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            final items = snap.data!.where((i) => i.quantity > 0).toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('보관함', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('아직 산 아이템이 없어요', style: AppText.caption)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final it = items[i];
                        return AppCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _artColors[it.itemId] ?? AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_iconFor(it.itemId, it.category), size: 20, color: AppColors.primary),
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
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
