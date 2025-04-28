import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  FlutterTts flutterTts = FlutterTts();

  String msg = 'Hello, welcome to your assistant, Shake your phone to start interactions.';
  String instruction = 'How can I help you, Make Call, Send Message or Read Message.';
  String statusMSG = '';

  // Threshold for shake detection
  static const double shakeThresholdGravity = 2.7; // gravity force
  static const int shakeSlopTimeMs = 500; // 0.5 seconds cooldown
  int lastShakeTimestamp = 0;

  late StreamSubscription<AccelerometerEvent> _streamSubscription;



  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-US"); // Set the language to English
    flutterTts.setPitch(1.0); // Set pitch (1.0 is normal)
    flutterTts.setSpeechRate(0.3); // Set the speech rate (0.5 is slower)

    statusMSG = msg;

    Future.delayed(Duration(seconds: 3), () {
      _speak(msg);
      _streamSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
        _handleShake(event);
      });
    });

  }

  Future _speak(String msg) async {
    await flutterTts.speak(msg);
  }


  void _handleShake(AccelerometerEvent event) {
    double gX = event.x / 9.8;
    double gY = event.y / 9.8;
    double gZ = event.z / 9.8;

    // gForce will be close to 1 when stationary
    double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

    if (gForce > shakeThresholdGravity) {
      int now = DateTime.now().millisecondsSinceEpoch;

      if (lastShakeTimestamp + shakeSlopTimeMs < now) {
        lastShakeTimestamp = now;
        _onShakeDetected();
      }
    }
  }

  void _onShakeDetected(){

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shake Detected!')),
    );

    _speak(instruction);
    setState(() {
      statusMSG = instruction;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        title: Text("Phone Assistant", style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
               Text(
                statusMSG,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20.0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _streamSubscription.cancel();
  }
}
