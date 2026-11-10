import 'package:flutter/material.dart';
import '../theme.dart';

String comma(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

// 흰색 카드 (radius 20, padding 16, 테두리)
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

// 게이지
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 7});
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: AppColors.track,
        color: AppColors.primary,
      ),
    );
  }
}

// 오른쪽 위 동그란 버튼 (40 x 40)
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, this.hasDot = false, this.onTap});
  final IconData icon;
  final bool hasDot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Stack(
          children: [
            Center(child: Icon(icon, size: 20, color: AppColors.text)),
            if (hasDot)
              Positioned(
                left: 26,
                top: 8,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: AppColors.dot, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 알약 라벨
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.color = Colors.white, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: AppColors.primary), const SizedBox(width: 5)],
          Text(text, style: AppText.badge),
        ],
      ),
    );
  }
}