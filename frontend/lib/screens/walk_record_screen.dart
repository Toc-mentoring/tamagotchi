import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock/mock_data.dart';
import '../widgets/common.dart';

class WalkRecordScreen extends StatefulWidget {
  const WalkRecordScreen({super.key});

  @override
  State<WalkRecordScreen> createState() => _WalkRecordScreenState();
}

class _WalkRecordScreenState extends State<WalkRecordScreen> {
  bool _weekly = true; // 일간 / 주간

  @override
  Widget build(BuildContext context) {
    final todayPercent = MockData.todaySteps / MockData.goalSteps;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
      children: [
        // ① 헤더
        const SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(child: Text('걸음 기록', style: AppText.pageTitle)),
              CircleIconButton(icon: Icons.calendar_today_outlined),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ② 일간 / 주간 (padding 4, 모서리 15)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(15)),
          child: Row(
            children: [
              Expanded(child: _PeriodTab(label: '일간', selected: !_weekly, onTap: () => setState(() => _weekly = false))),
              const SizedBox(width: 4),
              Expanded(child: _PeriodTab(label: '주간', selected: _weekly, onTap: () => setState(() => _weekly = true))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ③ 날짜 이동
        const SizedBox(
          height: 40,
          child: Row(
            children: [
              Icon(Icons.chevron_left, size: 22, color: AppColors.primary),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('10.27 – 11.02', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                    SizedBox(height: 2),
                    Text('이번 주', style: AppText.tiny), // 문구 확인
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: AppColors.disabled),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ④ 주간 그래프 카드 (padding 16, 간격 12)
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('이번 주 걸음', style: AppText.caption), // 문구 확인
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(comma(MockData.weekTotal), style: AppText.bigNumber),
                            const SizedBox(width: 5),
                            const Text('걸음', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(100)),
                    child: const Text('지난주보다 ${MockData.changePercent}% ↑', style: AppText.badge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _WeekChart(),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ⑤ 평균 · 목표 달성 (간격 12)
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                color: AppColors.primarySoft,
                accent: AppColors.primary,
                icon: Icons.directions_walk,
                title: '하루 평균',
                value: '${comma(MockData.weekAverage)}걸음',
                sub: '목표의 ${(MockData.weekAverage / MockData.goalSteps * 100).round()}%', // 문구 확인
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _InsightCard(
                color: AppColors.peach,
                accent: AppColors.brown,
                icon: Icons.flag_outlined,
                title: '목표 달성',
                value: '${MockData.goalDays}일 / 7일',
                sub: '8천 걸음 이상 걸은 날', // 문구 확인
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ⑥ 오늘 카드 (간격 10)
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: Text('오늘 ${comma(MockData.todaySteps)}걸음', style: AppText.section)), // 문구 확인
                  Text('목표 ${(todayPercent * 100).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: todayPercent),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('목표까지 ${comma(MockData.goalSteps - MockData.todaySteps)}걸음', style: AppText.caption)),
                  const Text('+${MockData.pointsToday} P 적립', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ⑦ 안내 문구
        const Row(
          children: [
            Icon(Icons.sync, size: 13, color: AppColors.sub),
            SizedBox(width: 7),
            Expanded(child: Text('걸음 수는 휴대폰 만보기와 자동으로 동기화돼요', style: AppText.tiny)), // 문구 확인
          ],
        ),
      ],
    );
  }
}

// 일간/주간 탭 (높이 34, 모서리 11)
class _PeriodTab extends StatelessWidget {
  const _PeriodTab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.sub,
            )),
      ),
    );
  }
}

// 주간 막대 그래프 (높이 204)
class _WeekChart extends StatelessWidget {
  const _WeekChart();

  static const _base = 169.0;      // 막대 바닥 y
  static const _pxPerStep = 0.015; // 1만 걸음 = 150px

  double _y(int steps) => _base - steps * _pxPerStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 204,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final step = (w - 38 - 13 - 33) / 6; // 막대 칸 간격 (Figma 42)

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 눈금선 + 숫자 (0 / 5천 / 1만)
              for (final g in const [(0, '0'), (5000, '5천'), (10000, '1만')]) ...[
                Positioned(left: 0, top: _y(g.$1) - 6, child: Text(g.$2, style: const TextStyle(fontSize: 9, color: AppColors.sub))),
                Positioned(left: 29, right: 0, top: _y(g.$1), child: Container(height: 1, color: AppColors.line)),
              ],

              // 목표 점선 + 라벨
              Positioned(left: 29, right: 0, top: _y(MockData.goalSteps), child: const _DashedLine()),
              Positioned(
                right: w - 312,
                top: _y(MockData.goalSteps) - 16,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  child: const Text('목표 8천', style: TextStyle(fontSize: 8, color: AppColors.primary)), // 문구 확인
                ),
              ),

              // 막대 7개
              for (var i = 0; i < 7; i++)
                Positioned(
                  left: 38 + step * i,
                  top: 0,
                  width: 33,
                  height: 204,
                  child: _Bar(
                    label: MockData.weekLabels[i],
                    steps: MockData.weekSteps[i],
                    height: MockData.weekSteps[i] * _pxPerStep,
                    isToday: i == 6,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// 막대 1개 (칸 33, 막대 23)
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.steps, required this.height, required this.isToday});
  final String label;
  final int steps;
  final double height;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final color = isToday
        ? AppColors.primary
        : (steps >= MockData.goalSteps ? AppColors.tan : AppColors.barLight);
    final textColor = isToday ? AppColors.primary : AppColors.sub;
    final weight = isToday ? FontWeight.w700 : FontWeight.w400;

    return Stack(
      children: [
        // 걸음 수 (막대 위 18px)
        Positioned(
          left: 0, right: 0, top: 169 - height - 18,
          child: Text(comma(steps), textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: weight, color: textColor)),
        ),
        // 막대 (위 7, 아래 3 둥글게)
        Positioned(
          left: 5, width: 23, top: 169 - height, height: height,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)),
            ),
          ),
        ),
        // 요일
        Positioned(
          left: 0, right: 0, top: 181,
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: weight, color: textColor)),
        ),
      ],
    );
  }
}

// 점선
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / 6).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(width: 3, height: 1, margin: const EdgeInsets.only(right: 3), color: AppColors.goalLine),
          ),
        );
      },
    );
  }
}

// 평균 / 목표 달성 카드 (padding 15, 간격 5, 모서리 18)
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.color, required this.accent, required this.icon,
    required this.title, required this.value, required this.sub,
  });
  final Color color;
  final Color accent;
  final IconData icon;
  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 5),
            Text(title, style: TextStyle(fontSize: 11, color: accent)),
          ]),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
          const SizedBox(height: 5),
          Text(sub, style: AppText.tiny),
        ],
      ),
    );
  }
}