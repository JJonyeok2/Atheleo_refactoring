// [파일] 운동 화면 위 휴식 오버레이 위젯(카운트다운, 다음 세트 정보, 건너뛰기).
// [Spec] F-08 / [Task] TASK-24
// [의존] Flutter material만 (환경 변수 사용 안 함)

import 'package:flutter/material.dart';

/// 운동 화면 위에 올라가는 휴식 오버레이. 값만 받는 표시 전용 위젯.
class RestOverlay extends StatelessWidget {
  /// 휴식 오버레이를 만든다.
  const new({
    required this.remainingSec,
    required this.nextSet,
    required this.totalSets,
    required this.targetReps,
    required this.onSkip,
    super.key,
  });

  /// 남은 휴식 시간(초).
  final int remainingSec;

  /// 다음 세트 번호.
  final int nextSet;

  /// 전체 세트 수.
  final int totalSets;

  /// 세트당 목표 횟수.
  final int targetReps;

  /// 건너뛰기 버튼 콜백.
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xB3000000),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '휴식',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                Text(
                  '$remainingSec',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '다음 세트 $nextSet / $totalSets · 목표 $targetReps회',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onSkip, child: const Text('건너뛰기')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// [QA] 2026-11-13 PASS
// [보안] 입력은 int 값과 콜백뿐이고 Text로만 출력. 시크릿, 로그, 새 의존성 없음.
// [유지보수] 배경 ColoredBox(불투명 히트 테스트)가 터치를 흡수해 아래 위젯으로
// 통과하지 않음(QA 실측). 이를 고정하는 테스트는 아직 없음.
// [유지보수] 남은 시간은 초 정수 그대로 표시(3600은 '3600').
// 분:초 표시가 필요하면 Spec에서 정할 것.
// [유지보수] TASK-53의 '일시정지', '종료' 버튼은 휴식 중에도 눌려야 하므로
// Stack에서 이 오버레이보다 위에 둘 것.
