/// 랜드마크 한 점. x, y는 0~1 정규화 이미지 좌표이고 y는 아래로 증가한다.
class PoseLandmark {
  /// 좌표와 가시성으로 점을 만든다.
  const new({
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  /// 정규화 가로 좌표(0~1).
  final double x;

  /// 정규화 세로 좌표(0~1, 아래로 증가).
  final double y;

  /// 깊이 값.
  final double z;

  /// 가시성(0~1).
  final double visibility;
}

/// 한 시점의 랜드마크 33개.
class PoseFrame {
  /// [landmarks] 길이가 [LandmarkIndex.count]가 아니면 [ArgumentError].
  new({
    required this.timestampMs,
    required List<PoseLandmark> landmarks,
    this.aspectRatio = 1.0,
  }) : landmarks = List.unmodifiable(landmarks) {
    if (landmarks.length != LandmarkIndex.count) {
      throw ArgumentError.value(
        landmarks.length,
        'landmarks',
        '랜드마크는 ${LandmarkIndex.count}개여야 함',
      );
    }
  }

  /// 클립 시작 기준 시각(ms).
  final int timestampMs;

  /// 33개 랜드마크(읽기 전용).
  final List<PoseLandmark> landmarks;

  /// 이미지 너비/높이.
  final double aspectRatio;

  /// [index]번 랜드마크. [LandmarkIndex] 상수를 쓴다.
  PoseLandmark operator [](int index) => landmarks[index];
}

/// 몸의 왼쪽, 오른쪽.
enum BodySide {
  /// 왼쪽.
  left,

  /// 오른쪽.
  right,
}

/// MediaPipe Pose 랜드마크 인덱스.
abstract final class LandmarkIndex {
  /// 코.
  static const int nose = 0;

  /// 왼쪽 어깨.
  static const int leftShoulder = 11;

  /// 오른쪽 어깨.
  static const int rightShoulder = 12;

  /// 왼쪽 팔꿈치.
  static const int leftElbow = 13;

  /// 오른쪽 팔꿈치.
  static const int rightElbow = 14;

  /// 왼쪽 손목.
  static const int leftWrist = 15;

  /// 오른쪽 손목.
  static const int rightWrist = 16;

  /// 왼쪽 엉덩이.
  static const int leftHip = 23;

  /// 오른쪽 엉덩이.
  static const int rightHip = 24;

  /// 왼쪽 무릎.
  static const int leftKnee = 25;

  /// 오른쪽 무릎.
  static const int rightKnee = 26;

  /// 왼쪽 발목.
  static const int leftAnkle = 27;

  /// 오른쪽 발목.
  static const int rightAnkle = 28;

  /// 왼쪽 뒤꿈치.
  static const int leftHeel = 29;

  /// 오른쪽 뒤꿈치.
  static const int rightHeel = 30;

  /// 왼쪽 발끝.
  static const int leftFootIndex = 31;

  /// 오른쪽 발끝.
  static const int rightFootIndex = 32;

  /// 랜드마크 총 개수.
  static const int count = 33;
}
