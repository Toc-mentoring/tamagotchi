import 'package:flutter/material.dart';
import '../theme.dart';
import '../mock/mock_data.dart';
import '../widgets/common.dart';

class EggScreen extends StatelessWidget {
  const EggScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final percent = MockData.eggCumulative / MockData.eggGoal; // 0.78

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ① 헤더 (높이 60, 좌우 22, 간격 10)
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
                    const Expanded(child: Text('알 돌보기', style: AppText.pageTitle)),
                    const CircleIconButton(icon: Icons.notifications_none, hasDot: true),
                  ],
                ),
              ),
            ),

            // ② 본문 (padding 10/22/18, 간격 12)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
                children: [
                  // 소개
                  const Text('따뜻하게 품는 중이에요', // 문구 확인
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                  const SizedBox(height: 5),
                  const Text('걸을수록 알이 빨리 깨어나요', style: AppText.unit), // 문구 확인
                  const SizedBox(height: 12),

                  // 알 카드 (높이 190, 모서리 28)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      height: 190,
                      color: AppColors.primarySoft,
                      child: Stack(
                        children: [
                          const Positioned(left: -80, top: 115, child: _Ellipse(w: 390, h: 160, color: AppColors.hillFar)),
                          const Positioned(left: 150, top: 125, child: _Ellipse(w: 350, h: 140, color: AppColors.hillNear)),
                          const Positioned(left: 26, top: 48, child: _Ellipse(w: 69, h: 18, color: AppColors.cloud)),
                          const Positioned(left: 45, top: 34, child: _Ellipse(w: 28, h: 27, color: AppColors.cloud)),
                          const Positioned(left: 294, top: 30, child: _Ellipse(w: 35, h: 35, color: AppColors.sun)),

                          // 알 (147 x 147)
                          const Positioned(
                            top: 24, left: 0, right: 0,
                            child: Center(child: _PetImage(path: 'assets/images/momo_egg.png', size: 147)),
                          ),

                          // 알 종류 배지
                          const Positioned(left: 16, top: 14, child: _Badge(text: MockData.eggName)),

                          // 기분 라벨
                          const Positioned(
                            top: 155, left: 0, right: 0,
                            child: Center(child: Pill(text: '곧 만날 수 있을 것 같아!')), // 문구 확인
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 부화 카드 (padding 16, 간격 11)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('부화까지 남은 걸음',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                            ),
                            _Badge(text: '${(percent * 100).round()}%'),
                          ],
                        ),
                        const SizedBox(height: 11),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(comma(MockData.eggRemaining), style: AppText.bigNumber),
                            const SizedBox(width: 6),
                            const Text('걸음 남았어요', style: AppText.unit), // 문구 확인
                          ],
                        ),
                        const SizedBox(height: 11),
                        ProgressBar(value: percent, height: 9),
                        const SizedBox(height: 11),
                        Row(
                          children: [
                            Expanded(
                              child: Text('누적 ${comma(MockData.eggCumulative)}걸음', // 문구 확인
                                  style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.primary)),
                            ),
                            Text('목표 ${comma(MockData.eggGoal)}걸음', style: AppText.caption), // 문구 확인
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 성장 여정 (간격 13)
                  const Row(
                    children: [
                      Expanded(
                        child: Text('${MockData.petName}의 성장 여정', // 문구 확인
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                      ),
                      Text('총 4단계', style: TextStyle(fontSize: 12, color: AppColors.sub)), // 문구 확인
                    ],
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Expanded(child: _Stage(path: 'assets/images/momo_egg.png', name: '알', sub: '지금 여기', current: true)), // 문구 확인
                      SizedBox(width: 8),
                      Expanded(child: _Stage(path: 'assets/images/momo_baby.png', name: '아기', sub: '8천 걸음')), // 문구 확인
                      SizedBox(width: 8),
                      Expanded(child: _Stage(path: 'assets/images/momo_teen.png', name: '청소년', sub: '3일 돌봄')), // 문구 확인
                      SizedBox(width: 8),
                      Expanded(child: _Stage(path: 'assets/images/momo_adult.png', name: '어른', sub: '7일 돌봄')), // 문구 확인
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 안내 카드 (padding 14, 모서리 18)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.peach, borderRadius: BorderRadius.circular(18)),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.spa_outlined, size: 21, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('걸을수록 알이 빨리 자라요', // 문구 확인
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                              SizedBox(height: 4),
                              Text('오늘 걸은 걸음이 알에 쌓여요. 목표 걸음을 채우면 모모가 태어나요.', // 문구 확인
                                  style: AppText.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('걸음은 매일 0시에 초기화돼요', // 문구 확인
                      textAlign: TextAlign.center, style: AppText.tiny),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 캐릭터 이미지 (없으면 아이콘)
class _PetImage extends StatelessWidget {
  const _PetImage({required this.path, required this.size});
  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: size,
      height: size,
      errorBuilder: (context, error, stack) => Icon(Icons.egg_outlined, size: size * 0.55, color: AppColors.primary),
    );
  }
}

// 연초록 배지 (padding 10/4, 둥근 끝)
class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: AppText.badge),
    );
  }
}

// 성장 단계 칸 (그림 64 x 58, 모서리 18, 간격 4)
class _Stage extends StatelessWidget {
  const _Stage({required this.path, required this.name, required this.sub, this.current = false});
  final String path;
  final String name;
  final String sub;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: current ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: _PetImage(path: path, size: 56),
        ),
        const SizedBox(height: 4),
        Text(name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: current ? AppColors.primary : AppColors.text,
            )),
        const SizedBox(height: 4),
        Text(sub, style: AppText.tiny),
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