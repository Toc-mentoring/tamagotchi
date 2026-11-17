import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class EggScreen extends StatefulWidget {
  const EggScreen({super.key, required this.petId});
  final String petId;

  @override
  State<EggScreen> createState() => _EggScreenState();
}

class _EggScreenState extends State<EggScreen> {
  late Future<Pet> _future = Api.instance.pet(widget.petId);

  void _reload() => setState(() => _future = Api.instance.pet(widget.petId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Pet>(
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
            return _body(context, snap.data!);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Pet pet) {
    final isEgg = pet.stage == 'EGG';
    final p = pet.progress;
    final percent = (p.percent ?? 100) / 100;
    final nextLabel = stageLabels[p.nextStage] ?? '';
    final currentIndex = _stages.indexWhere((s) => s.$1 == pet.stage);

    return Column(
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
                Expanded(child: Text(isEgg ? '알 돌보기' : '${pet.name} 성장', style: AppText.pageTitle)),
                const CircleIconButton(icon: Icons.notifications_none),
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
              Text(isEgg ? '따뜻하게 품는 중이에요' : '쑥쑥 자라는 중이에요',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
              const SizedBox(height: 5),
              Text(isEgg ? '걸을수록 알이 빨리 깨어나요' : '걸을수록 다음 단계에 가까워져요', style: AppText.unit),
              const SizedBox(height: 12),

              // 캐릭터 카드 (높이 190, 모서리 28)
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

                      // 캐릭터 (147 x 147)
                      Positioned(
                        top: 24, left: 0, right: 0,
                        child: Center(child: _PetImage(path: pet.image, size: 147)),
                      ),

                      // 단계 배지
                      Positioned(left: 16, top: 14, child: _Badge(text: '${pet.stageLabel} · ${pet.days}일째')),

                      // 기분 라벨
                      Positioned(
                        top: 155, left: 0, right: 0,
                        child: Center(child: Pill(text: isEgg ? '곧 만날 수 있을 것 같아!' : '오늘도 같이 걷자!')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 진행 카드 (padding 16, 간격 11)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nextLabel.isEmpty ? '다 자랐어요' : (isEgg ? '부화까지 남은 걸음' : '$nextLabel까지 남은 걸음'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text),
                          ),
                        ),
                        _Badge(text: '${(percent * 100).round()}%'),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(comma(p.remainingSteps ?? 0), style: AppText.bigNumber),
                        const SizedBox(width: 6),
                        const Text('걸음 남았어요', style: AppText.unit),
                      ],
                    ),
                    const SizedBox(height: 11),
                    ProgressBar(value: percent, height: 9),
                    const SizedBox(height: 11),
                    Row(
                      children: [
                        Expanded(
                          child: Text('누적 ${comma(p.currentSteps)}걸음',
                              style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.primary)),
                        ),
                        if (p.requiredSteps != null) Text('목표 ${comma(p.requiredSteps!)}걸음', style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 성장 여정 (간격 13)
              Row(
                children: [
                  Expanded(
                    child: Text('${pet.name}의 성장 여정',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                  ),
                  const Text('총 4단계', style: TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  for (var i = 0; i < _stages.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _Stage(
                        path: stageImages[_stages[i].$1]!,
                        name: _stages[i].$2,
                        // 지난 단계 = 완료, 지금 = 지금 여기, 바로 다음 = 필요한 누적 걸음
                        sub: i < currentIndex
                            ? '완료'
                            : i == currentIndex
                                ? '지금 여기'
                                : (_stages[i].$1 == p.nextStage && p.requiredSteps != null ? '${comma(p.requiredSteps!)}걸음' : ''),
                        current: i == currentIndex,
                      ),
                    ),
                  ],
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
                          Text('걸을수록 빨리 자라요',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.45, color: AppColors.text)),
                          SizedBox(height: 4),
                          Text('걸은 걸음이 쌓여서 목표 걸음을 채우면 다음 단계로 자라요.', style: AppText.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Text('걸음은 매일 0시에 초기화돼요', textAlign: TextAlign.center, style: AppText.tiny),
            ],
          ),
        ),
      ],
    );
  }
}

// 성장 단계 (코드, 이름)
const _stages = [('EGG', '알'), ('BABY', '아기'), ('TEEN', '청소년'), ('ADULT', '어른')];

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
