import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// センサー種別
enum SensorType {
  /// 加速度X（重力を含まない）
  userAccelerometerX,

  /// 加速度Y（重力を含まない）
  userAccelerometerY,

  /// 加速度Z（重力を含まない）
  userAccelerometerZ,

  /// ジャイロX
  gyroscopeX,

  /// ジャイロY
  gyroscopeY,

  /// ジャイロX
  gyroscopeZ,
}

/// センサー情報
class MotionInfo {
  final SensorType sensorType;
  final double outputValue;
  final bool isDetected;

  MotionInfo({required this.sensorType, required this.outputValue, required this.isDetected});
}

class MotionDetector {
  Duration samplingPeriod;
  double accelerometerThreshold;
  double gyroscopeThreshold;

  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  late AccelerometerAnalyser _accelerometerXAnalyser;
  late AccelerometerAnalyser _accelerometerYAnalyser;
  late GyroscopeAnalyser _gyroscopeZAnalyser;

  final _streamController = StreamController<MotionInfo>();
  Stream<MotionInfo> get stream => _streamController.stream;

  MotionDetector({
    this.samplingPeriod = SensorInterval.uiInterval,
    this.accelerometerThreshold = 0.2,
    this.gyroscopeThreshold = 90,
  }) {
    _accelerometerXAnalyser = AccelerometerAnalyser(
      type: SensorType.userAccelerometerX,
      thresholdValue: accelerometerThreshold,
      onDetect: (info) => _streamController.add(info),
    );
    _accelerometerYAnalyser = AccelerometerAnalyser(
      type: SensorType.userAccelerometerY,
      thresholdValue: accelerometerThreshold,
      onDetect: (info) => _streamController.add(info),
    );
    _gyroscopeZAnalyser = GyroscopeAnalyser(
      type: SensorType.gyroscopeZ,
      thresholdValue: gyroscopeThreshold,
      onDetect: (info) => _streamController.add(info),
    );
  }

  void start() {
    _streamSubscriptions.addAll([
      userAccelerometerEventStream(samplingPeriod: samplingPeriod).listen(
        (UserAccelerometerEvent event) {
          _accelerometerXAnalyser.analyse(value: event.x, time: DateTime.now());
        },
        onError: (e) {
          print(e);
        },
        cancelOnError: true,
      ),
      userAccelerometerEventStream(samplingPeriod: samplingPeriod).listen(
        (UserAccelerometerEvent event) {
          _accelerometerYAnalyser.analyse(value: event.y, time: DateTime.now());
        },
        onError: (e) {
          print(e);
        },
        cancelOnError: true,
      ),
      gyroscopeEventStream(samplingPeriod: samplingPeriod).listen(
        (GyroscopeEvent event) {
          _gyroscopeZAnalyser.analyse(value: event.z, time: DateTime.now());
        },
        onError: (e) {
          print(e);
        },
        cancelOnError: true,
      ),
    ]);
  }

  void stop() {
    _streamSubscriptions.clear();
  }
}

class AccelerometerAnalyser {
  final SensorType type;
  final double thresholdValue;
  final void Function(MotionInfo) onDetect;

  AccelerometerAnalyser({required this.type, required this.thresholdValue, required this.onDetect});

  double _prevValue = 0;
  double _speed = 0;
  double _prevSpeed = 0;
  double _distance = 0;
  DateTime? _prevTime;
  bool isIgnoring = false;

  /// キャリブレーター
  final _calibrator = Calibrator();

  /// ローパスフィルター
  final _lowPassFilter = LowPassFilter();

  void analyse({required double value, required DateTime time}) {
    final pTime = _prevTime;
    _prevTime = time;
    if (pTime == null) {
      return;
    }
    final timeSpan = time.difference(pTime).inMilliseconds / 1000;

    // キャリブレーション
    final calibratedValue = _calibrator.calibrate(value);

    //final roundedValue = round(calibratedValue, _calibrator.offset);

    // ハイパスフィルター (= センサ値 - ローパスフィルターの値)
    //final filteredValue = roundedValue - _lowPassFilter.filter(roundedValue);
    final filteredValue = calibratedValue - _lowPassFilter.filter(calibratedValue);

    // 速度計算(加速度を台形積分する)
    _speed = ((filteredValue + _prevValue) * timeSpan) / 2 + _speed;
    _prevValue = filteredValue;

    // 変位計算(速度を台形積分する)
    _distance = ((_speed + _prevSpeed) * timeSpan) / 2 + _distance;
    _prevSpeed = _speed;

    // print(
    //     '$type: value=${value.toStringAsFixed(5)}, caliValue=${calibratedValue.toStringAsFixed(5)}, filValue=${filteredValue.toStringAsFixed(5)}, speed=${_speed.toStringAsFixed(5)}, distance=${_distance.toStringAsFixed(5)}');

    final isDetected = _distance.abs() > thresholdValue;
    onDetect(MotionInfo(sensorType: type, outputValue: _distance, isDetected: isDetected));
    if (isDetected) {
      clear();

      isIgnoring = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        isIgnoring = false;
      });
    }
  }

  double round(double value, double offset) {
    if (value.abs() < offset.abs() * 2) {
      return 0;
    } else {
      return value;
    }
  }

  void clear() {
    _prevValue = 0;
    _speed = 0;
    _prevSpeed = 0;
    _distance = 0;
  }
}

class GyroscopeAnalyser {
  final SensorType type;
  final double thresholdValue;
  final void Function(MotionInfo) onDetect;

  GyroscopeAnalyser({required this.type, required this.thresholdValue, required this.onDetect});

  double _prevValue = 0;
  double _angle = 0;
  DateTime? _prevTime;
  bool isIgnoring = false;

  /// キャリブレーター
  final _calibrator = Calibrator();

  void analyse({required double value, required DateTime time}) {
    final pTime = _prevTime;
    _prevTime = time;
    if (pTime == null) {
      return;
    }
    final timeSpan = time.difference(pTime).inMilliseconds / 1000;

    if (isIgnoring) {
      return;
    }

    // キャリブレーション
    final calibratedValue = _calibrator.calibrate(value);

    // ラジアンから度に変換
    final degrees = radian2Degree(calibratedValue);

    // 角度計算(角速度を台形積分)
    _angle += ((degrees + _prevValue) * timeSpan) / 2;
    _prevValue = degrees;

    print(
        '$type: radian=${value.toStringAsFixed(5)}, caliValue=${calibratedValue.toStringAsFixed(5)}, degrees=${degrees.toStringAsFixed(5)}, angle=${_angle.toStringAsFixed(5)}, ${value < 0 ? 'MINUS' : ''}');

    final isDetected = _angle.abs() > thresholdValue;
    onDetect(MotionInfo(sensorType: type, outputValue: _angle, isDetected: isDetected));
    if (isDetected) {
      clear();

      isIgnoring = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        isIgnoring = false;
      });
    }
  }

  double radian2Degree(double radian) {
    return radian * 180 / 3.14159;
  }

  void clear() {
    _prevValue = 0;
    _angle = 0;
  }
}

/// キャリブレーター
class Calibrator {
  final List<double> _values = [];
  final _numberOfSampling = 30;
  double _offset = 0.0;
  bool _isCalibrated = false;

  double get offset => _offset;

  double calibrate(double value) {
    if (_values.length < _numberOfSampling) {
      _values.add(value);
      return value;
    } else {
      if (!_isCalibrated) {
        _offset = _median(_values);
        _isCalibrated = true;
      }
      return value - _offset;
    }
  }

  /// 中央値を算出する
  double _median(List<double> list) {
    list.sort();
    final middle = list.length ~/ 2;
    if (list.length % 2 == 1) {
      return list[middle];
    } else {
      return (list[middle - 1] + list[middle]) / 2.0;
    }
  }
}

class Rounder {
  double round(double value, double offset) {
    if (value.abs() < offset.abs()) {
      return 0;
    } else {
      return value;
    }
  }
}

/// ローパスフィルター
class LowPassFilter {
  final double rate = 0.8;
  double _prevValue = 0;

  double filter(double value) {
    final output = rate * value + _prevValue * (1 - rate);
    _prevValue = value;
    return output;
  }
}
