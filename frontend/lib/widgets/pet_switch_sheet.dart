import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

/// 내 아이들 목록 → 키울 아이 바꾸기. 바꾸면 true를 돌려준다.
/// (Figma에 없는 임시 화면 — 필요 없으면 이 파일과 홈의 버튼만 지우면 된다)
class PetSwitchSheet extends StatefulWidget {
  const PetSwitchSheet({super.key});

  @override
  State<PetSwitchSheet> createState() => _PetSwitchSheetState();
}

class _PetSwitchSheetState extends State<PetSwitchSheet> {
  late Future<(List<Pet>, String?)> _future = Api.instance.myPets();
  bool _busy = false;

  Future<void> _activate(Pet pet) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Api.instance.activatePet(pet.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: FutureBuilder<(List<Pet>, String?)>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('불러오지 못했어요\n${snap.error}', textAlign: TextAlign.center, style: AppText.caption),
                      TextButton(
                        onPressed: () => setState(() => _future = Api.instance.myPets()),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snap.hasData) return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
            final (pets, activeId) = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 아이들', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('걸음은 지금 키우는 아이에게만 쌓여요', style: AppText.caption),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final pet = pets[i];
                      final active = pet.id == activeId;
                      return AppCard(
                        color: active ? AppColors.primarySoft : Colors.white,
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
                              child: Image.asset(pet.image,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${pet.name} · ${pet.stageLabel}', style: AppText.cardTitle),
                                  Text('${pet.days}일째 · ${comma(pet.growthSteps)}걸음', style: AppText.tiny),
                                ],
                              ),
                            ),
                            if (active)
                              const Text('키우는 중', style: AppText.badge)
                            else
                              FilledButton(
                                onPressed: _busy ? null : () => _activate(pet),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  minimumSize: const Size(0, 32),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                child: const Text('이 아이 키우기'),
                              ),
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
