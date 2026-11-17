import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'friend_visit_screen.dart';

// 친구 아바타 배경색 (디자인 순서대로 돌아가며)
const _avatarColors = [AppColors.peach, Color(0xFFF0EBF5), AppColors.primarySoft];
const _giftBg = AppColors.peach;
const _giftIcon = Color(0xFF99785B);
const _heartColor = Color(0xFFA78063);

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<(String, FriendList)> _future = _load();
  bool _showAll = false; // '모두 보기'를 누르면 전체, 아니면 3명

  Future<(String, FriendList)> _load() async {
    final results = await Future.wait([Api.instance.friendCode(), Api.instance.friends()]);
    return (results[0] as String, results[1] as FriendList);
  }

  void _reload() => setState(() => _future = _load());

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // 친구 코드 입력 → 친구 추가
  Future<void> _addFriend() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 코드 입력', style: AppText.section),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: '친구에게 받은 코드'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('추가')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      final friend = await Api.instance.addFriend(code);
      _toast('${friend.nickname}님과 친구가 됐어요!');
      _reload();
    } catch (e) {
      _toast('$e');
    }
  }

  // 놀러 가기 → 친구의 작은 숲 화면 (들어가면 방문 기록이 저장돼요)
  void _visit(Friend friend) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FriendVisitScreen(friend: friend)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String, FriendList)>(
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
        final (code, list) = snap.data!;
        return RefreshIndicator(onRefresh: () async => _reload(), child: _body(code, list));
      },
    );
  }

  Widget _body(String code, FriendList list) {
    final shown = _showAll ? list.items : list.items.take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      children: [
        // ① 헤더
        SizedBox(
          height: 60,
          child: Row(
            children: [
              const Expanded(child: Text('산책 친구', style: AppText.pageTitle)),
              CircleIconButton(icon: Icons.person_add_alt, onTap: _addFriend),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ② 내 친구 코드 (padding 16, 간격 12, 모서리 20)
        AppCard(
          color: AppColors.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('나의 친구 코드', style: TextStyle(fontSize: 11, height: 1.45, color: AppColors.primary)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Flexible(
                              child: Text(code,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: code));
                                _toast('친구 코드를 복사했어요');
                              },
                              child: const Icon(Icons.copy_rounded, size: 15, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.qr_code_2, size: 30, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.keyboard_alt_outlined, label: '코드 입력',
                      background: AppColors.primary, foreground: Colors.white, onTap: _addFriend,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.qr_code_scanner, label: 'QR로 추가',
                      background: AppColors.primarySoft, foreground: AppColors.primary,
                      onTap: () => _toast('QR 추가는 준비 중이에요'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('친구가 되면 서로의 집에 놀러 갈 수 있어요.', style: AppText.tiny),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ③ 친구 수 + 모두 보기
        Row(
          children: [
            Expanded(
              child: Text('함께 걷는 친구 ${list.totalCount}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
            ),
            if (list.items.length > 3)
              GestureDetector(
                onTap: () => setState(() => _showAll = !_showAll),
                child: Text(_showAll ? '접기' : '모두 보기 →', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // ④ 친구 목록 (간격 12)
        if (list.items.isEmpty)
          const AppCard(child: Text('아직 친구가 없어요. 친구 코드를 입력해 친구를 추가해 보세요.', style: AppText.caption))
        else
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _FriendCard(
              friend: shown[i],
              avatarColor: _avatarColors[i % _avatarColors.length],
              onVisit: () => _visit(shown[i]),
              onGift: () => _toast('선물은 상점이 열리면 보낼 수 있어요'),
            ),
          ],
        const SizedBox(height: 16),

        // ⑤ 가족 안내 (padding 15, 모서리 18)
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(18)),
          child: const Row(
            children: [
              Icon(Icons.favorite_border, size: 25, color: _heartColor),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('마음이 닮은 친구를 만나면',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                    SizedBox(height: 3),
                    Text('어른이 된 친구끼리 새 가족을 만들어요.', style: AppText.caption),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 17, color: _heartColor),
            ],
          ),
        ),
      ],
    );
  }
}

// 친구 카드 (padding 14, 간격 12, 모서리 20)
class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend, required this.avatarColor, required this.onVisit, required this.onGift});
  final Friend friend;
  final Color avatarColor;
  final VoidCallback onVisit;
  final VoidCallback onGift;

  @override
  Widget build(BuildContext context) {
    final pet = friend.pet;
    final info = [
      if (pet != null) pet.name,
      if (pet != null) pet.stageLabel,
      friend.todaySteps == null ? '오늘 기록 없음' : '오늘 ${comma(friend.todaySteps!)}걸음',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // 아바타 (68 x 80, 모서리 18). 캐릭터가 칸 밖으로 살짝 나오게
          SizedBox(
            width: 68,
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(decoration: BoxDecoration(color: avatarColor, borderRadius: BorderRadius.circular(18))),
                if (pet != null)
                  Image.asset(
                    pet.image,
                    width: 90,
                    height: 90,
                    errorBuilder: (context, error, stack) => const Icon(Icons.pets, size: 36, color: AppColors.primary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(friend.nickname,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                    ),
                    Text(friend.lastSeenLabel, style: AppText.tiny),
                  ],
                ),
                const SizedBox(height: 5),
                Text(info, style: AppText.caption),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.door_front_door_outlined, label: '놀러 가기',
                        background: AppColors.primarySoft, foreground: AppColors.primary, onTap: onVisit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onGift,
                      child: Container(
                        width: 39,
                        height: 38,
                        decoration: BoxDecoration(color: _giftBg, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.card_giftcard, size: 18, color: _giftIcon),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 아이콘 + 글자 버튼 (높이 38, 모서리 12, 간격 7)
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon, required this.label, required this.background, required this.foreground, required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: foreground)),
          ],
        ),
      ),
    );
  }
}
