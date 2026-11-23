import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'main.dart';
import 'steps/step_sync.dart';
import 'theme.dart';

/// 앱 시작: 익명 로그인 → 사용자 초기화(bootstrap) → 기기 등록 → 메인 화면
class StartGate extends StatefulWidget {
  const StartGate({super.key});

  @override
  State<StartGate> createState() => _StartGateState();
}

class _StartGateState extends State<StartGate> {
  late Future<void> _ready = _start();

  Future<void> _start() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) await auth.signInAnonymously();
    await Api.instance.bootstrap('산책러'); // 닉네임 입력 화면은 나중에
    await StepSync.instance.registerDevice(); // 폰이면 이 기기를 대표 기기로 등록 (웹은 건너뜀)
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('시작하지 못했어요\n${snap.error}', textAlign: TextAlign.center, style: AppText.caption),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(() => _ready = _start()), child: const Text('다시 시도')),
                  ],
                ),
              ),
            ),
          );
        }
        return const MainShell();
      },
    );
  }
}