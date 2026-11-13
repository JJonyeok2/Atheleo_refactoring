// [파일] 테스트용 가짜 자세 감지기(FakePoseDetector). 호출 기록과 결과 주입.
//   테스트 전용, app/lib에서 쓰지 않음.
// [Spec] F-01 / [Task] TASK-19
// [의존] 없음 (환경 변수 사용 안 함)

import 'dart:async';

import 'package:atheleo/pose/detector/pose_detector.dart';

/// 테스트용 가짜 감지기. 호출을 [calls]에 기록하고 결과는 [emit]으로 넣는다.
class FakePoseDetector implements PoseDetector {
  /// `camera`는 [start]가 돌려줄 값(실행 중 다시 불러도 같은 값).
  new({
    this._camera = const PoseCameraInfo(textureId: 1, width: 720, height: 1280),
  });

  final PoseCameraInfo _camera;
  final StreamController<PoseDetectionResult> _controller =
      StreamController.broadcast();
  final List<String> _calls = [];
  PoseModel? _currentModel;
  bool _running = false;

  /// 'start:full', 'stop', 'setModel:lite' 형식의 호출 기록.
  List<String> get calls => List.unmodifiable(_calls);

  /// 마지막으로 정해진 모델. 아직 없으면 null.
  PoseModel? get currentModel => _currentModel;

  /// 구독자에게 결과를 보낸다.
  void emit(PoseDetectionResult result) => _controller.add(result);

  /// 구독자에게 스트림 오류를 보낸다.
  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<PoseDetectionResult> get results => _controller.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<PoseCameraInfo> start({PoseModel model = PoseModel.full}) async {
    _calls.add('start:${model.name}');
    _currentModel = model;
    _running = true;
    return _camera;
  }

  @override
  Future<void> stop() async {
    _calls.add('stop');
    _running = false;
  }

  @override
  Future<void> setModel(PoseModel model) async {
    _calls.add('setModel:${model.name}');
    _currentModel = model;
  }
}

// [QA] 2026-11-13 PASS
// [보안] 해당 없음(테스트 전용).
// [유지보수] results는 broadcast라 구독자가 없을 때 emit한 값은 사라진다.
//   소비 테스트는 화면/컨트롤러가 listen한 뒤(pump 이후) emit할 것.
//   실행 중 start도 calls에 'start:<model>'로 남는다(Platform과 달리 setModel 기록 없음).
