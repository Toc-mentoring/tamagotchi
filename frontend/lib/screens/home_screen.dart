import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'egg_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeData> _future = Api.instance.home();
  bool _busy = false; // 돌보기 요청 중이면 버튼 잠금

  void _reload() => setState(() => _future = Api.instance.home());

  Future<void> _care(Pet pet, String action, String label) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Api.instance.care(pet.id, action);
      _reload();
      _toast('$label 완료!');
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
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
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: _body(context, snap.data!),
        );
      },
    );
  }

  Widget _body(BuildContext context, HomeData data) {
    final pet = data.pet;
    final steps = data.today.totalSteps ?? 0;
    final goal = data.today.goalSteps;
    final todayPercent = goal == 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0).toDouble();
    final growth = (pet?.progress.percent ?? 100) / 100;
    final nextLabel = stageLabels[pet?.progress.nextStage] ?? '';
    final stats = pet?.stats;
    final isEgg = stats == null; // 알은 상태값이 없다

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      children: [
        // ① 헤더 (높이 60)
        SizedBox(
          height: 60,
          child: Row(
            children: [
              const Expanded(child: Text('포켓산책', style: AppText.pageTitle)),
              CircleIconButton(icon: Icons.notifications_none, hasDot: data.unreadCount > 0),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ② 캐릭터 카드 (높이 238, 모서리 28)
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EggScreen())),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 238,
              color: AppColors.primarySoft,
              child: Stack(
                children: [
                  // 배경: 언덕 · 해 · 구름
                  const Positioned(left: -80, top: 163, child: _Ellipse(w: 390, h: 160, color: AppColors.hillFar)),
                  const Positioned(left: 150, top: 173, child: _Ellipse(w: 350, h: 140, color: AppColors.hillNear)),
                  const Positioned(left: 294, top: 30, child: _Ellipse(w: 35, h: 35, color: AppColors.sun)),
                  const Positioned(left: 26, top: 48, child: _Ellipse(w: 69, h: 18, color: AppColors.cloud)),
                  const Positioned(left: 45, top: 34, child: _Ellipse(w: 28, h: 27, color: AppColors.cloud)),

                  // 캐릭터 (단계별 이미지)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        pet?.image ?? stageImages['EGG']!,
                        width: 168,
                        height: 168,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.pets, size: 90, color: AppColors.primary),
                      ),
                    ),
                  ),

                  // 이름 · 단계
                  Positioned(
                    left: 20,
                    top: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(pet?.name ?? '-', style: AppText.petName),
                            const SizedBox(width: 8),
                            if (pet != null) Text('${pet.stageLabel} · ${pet.days}일째', style: AppText.badge),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text('오늘도 같이 걸을까?', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),

                  // 기분 라벨
                  Positioned(
                    top: 202,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Pill(text: isEgg ? '곧 만날 수 있을 것 같아!' : '오늘은 기분이 정말 좋아!', icon: Icons.auto_awesome),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ③ 오늘의 걸음
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('오늘의 걸음', style: AppText.cardTitle)),
                  Container(
                    width: 19,
                    height: 19,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: const Text('P', style: AppText.badge),
                  ),
                  const SizedBox(width: 5),
                  Text('${comma(data.wallet.balance)} P 보유', style: AppText.badge),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(comma(steps), style: AppText.bigNumber),
                  const SizedBox(width: 5),
                  const Text('걸음', style: AppText.unit),
                  const Spacer(),
                  Text('목표 ${comma(goal)}걸음 · ${(todayPercent * 100).round()}%', style: AppText.caption),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: todayPercent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(data.today.isSynced ? '동기화됨 · 매일 0시 초기화' : '아직 동기화 전 · 매일 0시 초기화', style: AppText.tiny),
                  ),
                  Text('오늘 적립 +${data.wallet.todayEarned} P', style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ④ 성장 게이지
        Row(
          children: [
            Expanded(
              child: Text(nextLabel.isEmpty ? '다 자랐어요' : '$nextLabel${isEgg ? '로 깨어날' : '이 될'} 준비 중', style: AppText.section),
            ),
            Text('${(growth * 100).round()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 7),
        ProgressBar(value: growth, height: 6),
        const SizedBox(height: 7),
        Row(
          children: [
            const Expanded(child: Text('걸음과 먹이·놀이로 쑥쑥 자라요', style: AppText.caption)),
            if (pet?.progress.remainingSteps != null)
              Text('${comma(pet!.progress.remainingSteps!)}걸음 남음', style: const TextStyle(fontSize: 10, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 16),

        // 알일 때는 상태·돌보기 대신 안내
        if (pet == null || stats == null)
          const AppCard(child: Text('알이 깨어나면 상태를 보고 돌봐 줄 수 있어요.', style: AppText.caption))
        else ...[
          // ⑤ 상태 4칸 (간격 8)
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.restaurant, label: '포만감', value: stats.satiety)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(icon: Icons.sentiment_satisfied_alt, label: '행복', value: stats.happiness)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(icon: Icons.water_drop_outlined, label: '청결', value: stats.cleanliness)),
              const SizedBox(width: 8),
              Expanded(child: _StatCard(icon: Icons.favorite_border, label: '건강', value: stats.health)),
            ],
          ),
          const SizedBox(height: 16),

          // ⑥ 돌보기 버튼 5개
          Row(
            children: [
              Expanded(child: Text('${pet.name} 돌보기', style: AppText.section)),
              const Text('작은 돌봄, 큰 행복', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (icon, label, action) in const [
                (Icons.restaurant_menu, '먹이', 'FEED'),
                (Icons.bubble_chart_outlined, '청소', 'CLEAN'),
                (Icons.sports_volleyball_outlined, '놀기', 'PLAY'),
                (Icons.medication_outlined, '약', 'MEDICINE'),
                (Icons.bedtime_outlined, '재우기', 'SLEEP'),
              ])
                Expanded(
                  child: _CareButton(icon: icon, label: label, onTap: _busy ? null : () => _care(pet, action, label)),
                ),
            ],
          ),
        ],
      ],
    );
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

// 상태 카드 (padding 10/8, 모서리 12)
class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label, style: AppText.tiny),
          ]),
          const SizedBox(height: 7),
          Text('$value%', style: AppText.statValue),
          const SizedBox(height: 7),
          ProgressBar(value: value / 100, height: 4),
        ],
      ),
    );
  }
}

// 돌보기 버튼 (54 x 46, 모서리 16). 누르면 서버에 돌보기 요청
class _CareButton extends StatelessWidget {
  const _CareButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 54,
            height: 46,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 23, color: AppColors.primary),
          ),
          const SizedBox(height: 5),
          Text(label, style: AppText.careLabel),
        ],
      ),
    );
  }
}