import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion_analyser.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
    [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _motionAnalyser = MotionAnalyser();
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  String _accX = '';
  String _accY = '';
  String _accZ = '';
  String _gyroX = '';
  String _gyroY = '';
  String _gyroZ = '';
  bool _isAccXDetected = false;
  bool _isAccYDetected = false;
  bool _isAccZDetected = false;
  bool _isGyroXDetected = false;
  bool _isGyroYDetected = false;
  bool _isGyroZDetected = false;

  @override
  void initState() {
    super.initState();
    _motionAnalyser.start();

    _streamSubscriptions.add(
      _motionAnalyser.stream.listen(
        (info) {
          setState(() => _setOutputValues(info));
        },
        onError: (e) => print(e),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _motionAnalyser.stop();
    _streamSubscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white, fontSize: 24);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Sensor Test',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        elevation: 4,
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Column(children: [
            Text(
              'Acc X',
              style: textStyle,
            ),
            Text(
              'Acc Y',
              style: textStyle,
            ),
            Text(
              'Acc Z',
              style: textStyle,
            ),
            Text(
              'gyro X',
              style: textStyle,
            ),
            Text(
              'gyro Y',
              style: textStyle,
            ),
            Text(
              'gyro Z',
              style: textStyle,
            ),
          ]),
          Column(children: [
            Text(
              _accX,
              style: textStyle.copyWith(color: _isAccXDetected ? Colors.red : Colors.white),
            ),
            Text(
              _accY,
              style: textStyle.copyWith(color: _isAccYDetected ? Colors.red : Colors.white),
            ),
            Text(
              _accZ,
              style: textStyle.copyWith(color: _isAccZDetected ? Colors.red : Colors.white),
            ),
            Text(
              _gyroX,
              style: textStyle.copyWith(color: _isGyroXDetected ? Colors.red : Colors.white),
            ),
            Text(
              _gyroY,
              style: textStyle.copyWith(color: _isGyroYDetected ? Colors.red : Colors.white),
            ),
            Text(
              _gyroZ,
              style: textStyle.copyWith(color: _isGyroZDetected ? Colors.red : Colors.white),
            ),
          ]),
        ],
      ),
    );
  }

  void _setOutputValues(MotionInfo info) {
    final value = info.outputValue.toStringAsFixed(5);
    switch (info.sensorType) {
      case SensorType.userAccelerometerX:
        _accX = value;
        _isAccXDetected = info.isDetected;
        break;
      case SensorType.userAccelerometerY:
        _accY = value;
        _isAccYDetected = info.isDetected;
        break;
      case SensorType.userAccelerometerZ:
        _accZ = value;
        _isAccZDetected = info.isDetected;
        break;
      case SensorType.gyroscopeX:
        _gyroX = value;
        _isGyroXDetected = info.isDetected;
        break;
      case SensorType.gyroscopeY:
        _gyroY = value;
        _isGyroYDetected = info.isDetected;
        break;
      case SensorType.gyroscopeZ:
        _gyroZ = value;
        _isGyroZDetected = info.isDetected;
        break;
    }
  }
}
