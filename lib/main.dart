import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion_detector.dart';

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
  final _motionDetector = MotionDetector();
  String _accX = '';
  String _accY = '';
  String _accZ = '';
  String _gyroX = '';
  String _gyroY = '';
  String _gyroZ = '';

  //final textStyle = const TextStyle(color: Colors.white, fontSize: 24);

  @override
  void initState() {
    super.initState();
    _motionDetector.start();
  }

  @override
  void dispose() {
    super.dispose();
    _motionDetector.stop();
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
          StreamBuilder(
            stream: _motionDetector.stream,
            builder: (context, snapShot) {
              final info = snapShot.data;
              if (info == null) {
                return const SizedBox.shrink();
              }

              setOutputValues(info);

              return Column(children: [
                Text(
                  _accX,
                  style: textStyle,
                ),
                Text(
                  _accY,
                  style: textStyle,
                ),
                Text(
                  _accZ,
                  style: textStyle,
                ),
                Text(
                  _gyroX,
                  style: textStyle,
                ),
                Text(
                  _gyroY,
                  style: textStyle,
                ),
                Text(
                  _gyroZ,
                  style: textStyle,
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  void setOutputValues(MotionInfo info) {
    final value = info.outputValue.toStringAsFixed(5);
    switch (info.sensorType) {
      case SensorType.userAccelerometerX:
        _accX = value;
        break;
      case SensorType.userAccelerometerY:
        _accY = value;
        break;
      case SensorType.userAccelerometerZ:
        _accZ = value;
        break;
      case SensorType.gyroscopeX:
        _gyroX = value;
        break;
      case SensorType.gyroscopeY:
        _gyroY = value;
        break;
      case SensorType.gyroscopeZ:
        _gyroZ = value;
        break;
    }
  }
}

extension ExtMotionInfo on MotionInfo {
  String getOutputValue(SensorType type) {
    return sensorType == type ? outputValue.toStringAsFixed(5) : '';
  }
}
