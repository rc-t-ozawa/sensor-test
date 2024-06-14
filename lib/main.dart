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
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  bool _isUserAccelerometerDetected = false;
  bool _isGyroscopeDetected = false;

  @override
  void initState() {
    super.initState();
    _motionDetector.start();

    _streamSubscriptions.addAll([
      _motionDetector.userAccelerometerStream.listen(
        (event) {
          setState(() => _isUserAccelerometerDetected = true);
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() => _isUserAccelerometerDetected = false);
          });
        },
      ),
      _motionDetector.gyroscopeStream.listen(
        (event) {
          setState(() => _isGyroscopeDetected = true);
          Future.delayed(const Duration(milliseconds: 500), () {
            setState(() => _isGyroscopeDetected = false);
          });
        },
      ),
    ]);
  }

  @override
  void dispose() {
    super.dispose();
    _motionDetector.stop();
    _streamSubscriptions.clear();
  }

  @override
  Widget build(BuildContext context) {
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
      body: AnimatedContainer(
        color: () {
          if (_isUserAccelerometerDetected) {
            return Colors.red;
          } else if (_isGyroscopeDetected) {
            return Colors.blue;
          } else {
            return Colors.transparent;
          }
        }(),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }
}
