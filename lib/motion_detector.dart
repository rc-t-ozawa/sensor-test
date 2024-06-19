import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class Accelerometer {
  final double x;
  final double y;
  final double z;
  final DateTime time;

  Accelerometer({required this.x, required this.y, required this.z, required this.time});
}

/// センサー種別
enum SensorType {
  /// 加速度（重力を含まない）
  userAccelerometer,

  /// ジャイロ
  gyroscope,
}

class MotionDetector {
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  final Duration _sensorInterval = SensorInterval.uiInterval;
  late AccelerometerAnalyser _accelerometerXAnalyser;
  late GyroscopeAnalyser _gyroscopeZAnalyser;

  final _streamController = StreamController<SensorType>();
  Stream<SensorType> get stream => _streamController.stream;

  MotionDetector() {
    _accelerometerXAnalyser = AccelerometerAnalyser(
      name: 'x',
      thresholdValue: 0.2,
      onDetect: () => _streamController.add(SensorType.userAccelerometer),
    );
    _gyroscopeZAnalyser = GyroscopeAnalyser(
      name: 'z',
      thresholdValue: 90,
      onDetect: () => _streamController.add(SensorType.gyroscope),
    );
  }

  void start() {
    _streamSubscriptions.addAll([
      userAccelerometerEventStream(samplingPeriod: _sensorInterval).listen(
        (UserAccelerometerEvent event) {
          //_accelerometerXAnalyser.set(value: event.x, time: DateTime.now());
        },
        onError: (e) {
          print(e);
        },
        cancelOnError: true,
      ),
      gyroscopeEventStream(samplingPeriod: _sensorInterval).listen(
        (GyroscopeEvent event) {
          _gyroscopeZAnalyser.set(value: event.z, time: DateTime.now());
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
  final String name;
  final double thresholdValue;
  final void Function() onDetect;

  AccelerometerAnalyser({required this.name, required this.thresholdValue, required this.onDetect});

  double _prevValue = 0;
  double _speed = 0;
  double _prevSpeed = 0;
  double _distance = 0;
  DateTime? _prevTime;

  /// キャリブレーター
  final _calibrator = Calibrator();

  /// ローパスフィルター
  final _lowPassFilter = LowPassFilter();

  void set({required double value, required DateTime time}) {
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
    //     '$name: value=${value.toStringAsFixed(5)}, caliValue=${calibratedValue.toStringAsFixed(5)}, roundedValue=${roundedValue.toStringAsFixed(5)}, filValue=${filteredValue.toStringAsFixed(5)}, speed=${_speed.toStringAsFixed(5)}, distance=${_distance.toStringAsFixed(5)}');
    print(
        '$name: value=${value.toStringAsFixed(5)}, caliValue=${calibratedValue.toStringAsFixed(5)}, filValue=${filteredValue.toStringAsFixed(5)}, speed=${_speed.toStringAsFixed(5)}, distance=${_distance.toStringAsFixed(5)}');

    if (_distance.abs() > thresholdValue) {
      //print('$name: distance=${distance.toStringAsFixed(5)}');
      clear();
      onDetect();
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
  final String name;
  final double thresholdValue;
  final void Function() onDetect;

  GyroscopeAnalyser({required this.name, required this.thresholdValue, required this.onDetect});

  double _prevValue = 0;
  double _angle = 0;
  DateTime? _prevTime;

  /// キャリブレーター
  final _calibrator = Calibrator();

  void set({required double value, required DateTime time}) {
    final pTime = _prevTime;
    _prevTime = time;
    if (pTime == null) {
      return;
    }
    final timeSpan = time.difference(pTime).inMilliseconds / 1000;

    // キャリブレーション
    final calibratedValue = _calibrator.calibrate(value);

    // ラジアンから度に変換
    final degrees = radian2Degree(calibratedValue);

    // 角度計算(角速度を台形積分)
    _angle += ((degrees + _prevValue) * timeSpan) / 2;
    _prevValue = degrees;

    print(
        '$name: radian=${value.toStringAsFixed(5)}, caliValue=${calibratedValue.toStringAsFixed(5)}, degrees=${degrees.toStringAsFixed(5)}, angle=${_angle.toStringAsFixed(5)}, ${value < 0 ? 'MINUS' : ''}');

    if (_angle.abs() > thresholdValue) {
      clear();
      onDetect();
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
        print('@@@@ _offset=$_offset');
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
