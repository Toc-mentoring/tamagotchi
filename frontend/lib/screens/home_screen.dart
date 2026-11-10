import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock/mock_data.dart';
import '../widgets/common.dart';
import 'egg_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todayPercent = MockData.todaySteps / MockData.goalSteps;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      children: [
        // ① 헤더 (높이 60)
        const SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(child: Text('포켓산책', style: AppText.pageTitle)),
              CircleIconButton(icon: Icons.notifications_none, hasDot: true),
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

                  // 캐릭터 (168 x 168)
                  Positioned(
                    top: 56,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Image.asset(
                        'assets/images/momo_baby.png',
                        width: 168,
                        height: 168,
                        errorBuilder: (context, error, stack) =>
                            const Icon(Icons.pets, size: 90, color: AppColors.primary),
                      ),
                    ),
                  ),

                  // 이름 · 단계
                  const Positioned(
                    left: 20,
                    top: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(MockData.petName, style: AppText.petName),
                            SizedBox(width: 8),
                            Text('${MockData.stageLabel} · ${MockData.petDays}일째', style: AppText.badge),
                          ],
                        ),
                        SizedBox(height: 3),
                        Text('오늘도 같이 걸을까?', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ],
                    ),
                  ),

                  // 기분 라벨
                  const Positioned(
                    top: 202,
                    left: 0,
                    right: 0,
                    child: Center(child: Pill(text: MockData.mood, icon: Icons.auto_awesome)),
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
                  Text('${comma(MockData.balance)} P 보유', style: AppText.badge),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(comma(MockData.todaySteps), style: AppText.bigNumber),
                  const SizedBox(width: 5),
                  const Text('걸음', style: AppText.unit),
                  const Spacer(),
                  Text('목표 ${comma(MockData.goalSteps)}걸음 · ${(todayPercent * 100).round()}%', style: AppText.caption),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: todayPercent),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Expanded(child: Text('방금 동기화 · 매일 0시 초기화', style: AppText.tiny)),
                  Text('오늘 적립 +${MockData.pointsToday} P', style: TextStyle(fontSize: 10, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ④ 성장 게이지
        Row(
          children: [
            const Expanded(child: Text('${MockData.nextStageLabel}이 될 준비 중', style: AppText.section)),
            Text('${(MockData.growthPercent * 100).round()}%',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 7),
        const ProgressBar(value: MockData.growthPercent, height: 6),
        const SizedBox(height: 7),
        const Row(
          children: [
            Expanded(child: Text('걸음과 먹이·놀이로 쑥쑥 자라요', style: AppText.caption)),
            Text('행복·청결 보너스 ↑', style: TextStyle(fontSize: 10, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 16),

        // ⑤ 상태 4칸 (간격 8)
        const Row(
          children: [
            Expanded(child: _StatCard(icon: Icons.restaurant, label: '포만감', value: MockData.satiety)),
            SizedBox(width: 8),
            Expanded(child: _StatCard(icon: Icons.sentiment_satisfied_alt, label: '행복', value: MockData.happiness)),
            SizedBox(width: 8),
            Expanded(child: _StatCard(icon: Icons.water_drop_outlined, label: '청결', value: MockData.cleanliness)),
            SizedBox(width: 8),
            Expanded(child: _StatCard(icon: Icons.favorite_border, label: '건강', value: MockData.health)),
          ],
        ),
        const SizedBox(height: 16),

        // ⑥ 돌보기 버튼 5개
        const Row(
          children: [
            Expanded(child: Text('${MockData.petName} 돌보기', style: AppText.section)),
            Text('작은 돌봄, 큰 행복', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: _CareButton(icon: Icons.restaurant_menu, label: '먹이', selected: true)),
            SizedBox(width: 10),
            Expanded(child: _CareButton(icon: Icons.bubble_chart_outlined, label: '청소')),
            SizedBox(width: 10),
            Expanded(child: _CareButton(icon: Icons.sports_volleyball_outlined, label: '놀기')),
            SizedBox(width: 10),
            Expanded(child: _CareButton(icon: Icons.medication_outlined, label: '약')),
            SizedBox(width: 10),
            Expanded(child: _CareButton(icon: Icons.bedtime_outlined, label: '재우기')),
          ],
        ),
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

// 돌보기 버튼 (54 x 46, 모서리 16)
class _CareButton extends StatelessWidget {
  const _CareButton({required this.icon, required this.label, this.selected = false});
  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 46,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 23, color: selected ? Colors.white : AppColors.primary),
        ),
        const SizedBox(height: 5),
        Text(label, style: AppText.careLabel),
      ],
    );
  }
}