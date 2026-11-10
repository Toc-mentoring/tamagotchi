import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFBF9F2);
  static const text = Color(0xFF293D31);
  static const primary = Color(0xFF426B4F);
  static const primarySoft = Color(0xFFEAF0DF);
  static const sub = Color(0xFF7E897D);
  static const line = Color(0xFFE7E9DD);
  static const track = Color(0xFFE9EDDF);
  static const dot = Color(0xFFECA894);

  // 캐릭터 카드 배경 그림
  static const hillFar = Color(0xFFDDE6CA);
  static const hillNear = Color(0xFFD0DEBB);
  static const sun = Color(0xFFFCF6D8);
  static const cloud = Color(0x90FFFFFF);
  static const sprig = Color(0xFFA1B88D);

  // 알 돌보기 · 산책 기록 (CSS 받으면 확정)
  static const peach = Color(0xFFFCEDDF);
  static const tan = Color(0xFFDDC39F);
  static const barLight = Color(0xFFC6D5AF);
}

class AppText {
  static const _h = 1.45; // Figma 줄 높이 145%

  static const pageTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: AppColors.text);
  static const petName = TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: _h, color: AppColors.text);
  static const section = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: _h, color: AppColors.text);
  static const cardTitle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: _h, color: AppColors.text);
  static const bigNumber = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1, color: AppColors.text);
  static const unit = TextStyle(fontSize: 13, height: _h, color: AppColors.sub);
  static const caption = TextStyle(fontSize: 11, height: _h, color: AppColors.sub);
  static const tiny = TextStyle(fontSize: 10, height: _h, color: AppColors.sub);
  static const badge = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: _h, color: AppColors.primary);
  static const statValue = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: _h, color: AppColors.text);
  static const careLabel = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: _h, color: AppColors.text);
}