import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

// 친구 숲 전용 색 (Figma)
const _meadow = AppColors.peach;           // FCEDDF
const _hillFar = Color(0xFFF2DFCB);
const _hillNear = Color(0xFFEDD6BE);
const _heart = Color(0xFFCC977D);
const _gold = Color(0xFFB58C45);
const _brown = AppColors.brown;            // A08062

class FriendVisitScreen extends StatefulWidget {
  const FriendVisitScreen({super.key, required this.friend});
  final Friend friend;

  @override
  State<FriendVisitScreen> createState() => _FriendVisitScreenState();
}

class _FriendVisitScreenState extends State<FriendVisitScreen> {
  // 들어올 때 방문 기록을 남기고, 내 펫 정보도 함께 가져온다
  late Future<(FriendVisit, HomeData)> _future = _load();
  bool _busy = false;

  Future<(FriendVisit, HomeData)> _load() async {
    final results = await Future.wait([Api.instance.visitFriend(widget.friend.uid), Api.instance.home()]);
    return (results[0] as FriendVisit, results[1] as HomeData);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _propose(FriendVisit visit, Pet myPet) async {
    final friendPet = visit.pet;
    if (_busy || friendPet == null) return;
    setState(() => _busy = true);
    try {
      await Api.instance.propose(recipientUid: visit.friend.uid, senderPetId: myPet.id, recipientPetId: friendPet.id);
      _toast('${friendPet.name}에게 청혼했어요! ${visit.friend.nickname}님의 응답을 기다려요.');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ① 헤더
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 60,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.chevron_left, size: 26, color: AppColors.text),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('친구의 작은 숲', style: AppText.pageTitle)),
                    const CircleIconButton(icon: Icons.notifications_none),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<(FriendVisit, HomeData)>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('불러오지 못했어요\n${snap.error}', textAlign: TextAlign.center, style: AppText.caption),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: () => setState(() => _future = _load()), child: const Text('다시 시도')),
                        ],
                      ),
                    );
                  }
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final (visit, home) = snap.data!;
                  return _body(visit, home.pet);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(FriendVisit visit, Pet? myPet) {
    final friendPet = visit.pet;
    final myName = myPet?.name ?? '나';
    final friendName = friendPet?.name ?? visit.friend.nickname;
    final canPropose = visit.canPropose && myPet != null && friendPet != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
      children: [
        // ② 친구 소개 + 선물
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${visit.friend.nickname}네 놀러 왔어요',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                  const SizedBox(height: 3),
                  Text('$friendName${josa(friendName, '이', '가')} $myName${josa(myName, '을', '를')} 반겨요!',
                      style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.sub)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _toast('선물은 상점이 열리면 보낼 수 있어요'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    Icon(Icons.card_giftcard, size: 17, color: _brown),
                    SizedBox(width: 6),
                    Text('선물', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brown)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ③ 둘이 만난 숲 (높이 220, 모서리 28)
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 220,
            color: _meadow,
            child: Stack(
              children: [
                const Positioned(left: -80, top: 145, child: _Ellipse(w: 390, h: 160, color: _hillFar)),
                const Positioned(left: 150, top: 155, child: _Ellipse(w: 350, h: 140, color: _hillNear)),
                const Positioned(left: 26, top: 48, child: _Ellipse(w: 69, h: 18, color: AppColors.cloud)),
                const Positioned(left: 45, top: 34, child: _Ellipse(w: 28, h: 27, color: AppColors.cloud)),
                const Positioned(left: 294, top: 30, child: _Ellipse(w: 35, h: 35, color: AppColors.sun)),

                // 상단 배지
                Positioned(
                  top: 12, left: 0, right: 0,
                  child: Center(
                    child: Text(visit.canPropose ? '어른 친구끼리 만났어요' : '함께 놀고 있어요',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _gold)),
                  ),
                ),

                // 내 펫 (왼쪽) · 하트 · 친구 펫 (오른쪽)
                Positioned(left: 32, top: 42, child: _PetImage(path: myPet?.image, size: 136)),
                const Positioned(left: 171, top: 92, child: Icon(Icons.favorite_border, size: 27, color: _heart)),
                Positioned(left: 201, top: 42, child: _PetImage(path: friendPet?.image, size: 136)),

                // 이름표
                Positioned(left: 37, top: 182, child: _NameTag(text: '$myName · ${myPet?.stageLabel ?? '-'}')),
                Positioned(left: 212, top: 182, child: _NameTag(text: '$friendName · ${friendPet?.stageLabel ?? '-'}')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ④ 가족이 되는 과정 (간격 12)
        const Text('둘이 함께, 새로운 가족',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0) const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.chevron_right, size: 12, color: AppColors.sub),
              ),
              Expanded(child: _Milestone(top: _steps[i].$1, bottom: _steps[i].$2, active: i == 0)),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // ⑤ 둘을 닮은 새 알 (padding 16, 간격 12)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('둘을 닮은 새 알',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(100)),
                    child: const Text('미리 보기', style: AppText.badge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 89,
                    height: 91,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                    child: const _PetImage(path: 'assets/images/momo_egg.png', size: 84),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$myName + $friendName',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                        const SizedBox(height: 6),
                        const Text('부모의 생김새와 돌봄 점수가 이어져요. 어떤 친구가 태어날까요?', style: AppText.caption),
                        const SizedBox(height: 6),
                        const Text('정성껏 돌본 시간이 다음 세대로', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('서로 청혼을 수락하면 결혼 후 새 알을 만나요.', style: AppText.tiny),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ⑥ 청혼 버튼 (높이 50, 모서리 20). 어른끼리만 누를 수 있다
        GestureDetector(
          onTap: canPropose && !_busy ? () => _propose(visit, myPet!) : null,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: canPropose ? AppColors.primary : AppColors.disabled,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_border, size: 18, color: Colors.white),
                const SizedBox(width: 7),
                Text('$friendName에게 청혼하기',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          canPropose
              ? '${visit.friend.nickname}님이 수락하기 전까지 청혼을 취소할 수 있어요.'
              : '둘 다 어른이 되면 청혼할 수 있어요.',
          textAlign: TextAlign.center,
          style: AppText.tiny,
        ),
      ],
    );
  }
}

// 가족이 되는 4단계 (작은 글자, 큰 글자)
const _steps = [('마음 전하기', '청혼'), ('친구의 응답', '서로 수락'), ('가족이 돼요', '결혼'), ('다음 이야기', '새 알')];

// 단계 칸 (높이 54, 모서리 14, 간격 3)
class _Milestone extends StatelessWidget {
  const _Milestone({required this.top, required this.bottom, required this.active});
  final String top;
  final String bottom;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: active ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(top, style: TextStyle(fontSize: 10, color: active ? AppColors.primary : AppColors.sub)),
          const SizedBox(height: 3),
          Text(bottom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
    );
  }
}

// 흰색 이름표 (padding 10/5, 모서리 14)
class _NameTag extends StatelessWidget {
  const _NameTag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text)),
    );
  }
}

// 캐릭터 이미지 (경로가 없거나 파일이 없으면 아이콘)
class _PetImage extends StatelessWidget {
  const _PetImage({required this.path, required this.size});
  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.pets, size: size * 0.5, color: AppColors.primary);
    if (path == null) return SizedBox(width: size, height: size, child: fallback);
    return Image.asset(path!, width: size, height: size, errorBuilder: (context, error, stack) => fallback);
  }
}

// 타원 (언덕, 해, 구름)
class _Ellipse extends StatelessWidget {
  const _Ellipse({required this.w, required this.h, required this.color});
  final double w;
  final double h;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
      ),
    );
  }
}
