import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:phone_navigation_assistant/app_commons.dart';
import 'package:phone_navigation_assistant/handle_contacts.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  FlutterTts flutterTts = FlutterTts();

  String msg =
      'Hello, welcome to your assistant, Shake your phone to start interactions.';
  String instruction =
      'How can I help you, Make Call, Send Message or Read Message. ';
  String statusMSG = '';

  // Threshold for shake detection
  static const double shakeThresholdGravity = 2.7; // gravity force
  static const int shakeSlopTimeMs = 500; // 0.5 seconds cooldown
  int lastShakeTimestamp = 0;

  late StreamSubscription<AccelerometerEvent> _streamSubscription;

  // // Speech to text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';
  bool _isInstruction = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setLanguage("en-US"); // Set the language to English
    flutterTts.setPitch(1.0); // Set pitch (1.0 is normal)
    flutterTts.setSpeechRate(0.4);

    flutterTts.awaitSpeakCompletion(true);

    statusMSG = msg;
    _initSpeech();
    Future.delayed(Duration(seconds: 3), () {
      _speak(msg);
      _streamSubscription = accelerometerEvents.listen((
        AccelerometerEvent event,
      ) {
        _handleShake(event);
      });
    });

    flutterTts.setCompletionHandler(() {
      if (_isInstruction) {
        //after giving instructions, listening to what user says
        _startListening();
      }
    });
  }

  Future _speak(String msg) async {
    await flutterTts.speak(msg);
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
      statusMSG = 'CMD: $_lastWords';
    });
    handleCMD(_lastWords);
    // _stopListening();
  }


  Future<void> handleCMD(String spokenWord) async {
    print('------XXX----> $_lastWords');
    final cmd = parseVoiceCommand(spokenWord);
    print('---->CMD: ${cmd.cmd} ----->Value: ${cmd.value}');
    switch (cmd.cmd) {
      case Command.call:
        print("📞 Calling ${cmd.value}");

        setState(() {
          _isInstruction = false;
          statusMSG = "Calling ${cmd.value}";
        });

        _speak(statusMSG);
        //
        // final results = await callContact(cmd.value);
        // if (results.isEmpty) {
        //   print('✅ Dialing initiated or no contact found for "${cmd.value}".');
        // } else {
        //   // TODO: present these in your Flutter UI (e.g., a ListView)
        //   print('Multiple matches:');
        //   String selectNumber = 'Please select the number you want to call.\n';
        //   for (var c in results) {
        //     selectNumber += '1. For ${c.displayName} on (${c.phones?.map((p) => p.value).join(", ")})';
        //     print('------> • ${c.displayName} (${c.phones?.map((p) => p.value).join(", ")})');
        //   }
        // }

        final results = await callContact(cmd.value);
        if (results.isEmpty) {
          print('✅ Call completed or no contact found.');
        } else {
          print('📇 Multiple matches:');
          String selectNumber = 'Please select the number you want to call.\n';
          int count = 0;
          for (var c in results) {
            count += 1;
            print('• ${c.name} - ${c.phoneNumber}');
            selectNumber += '$count. For ${c.name} on ${c.phoneNumber}. \n';
          }
          setState(() {
            _isInstruction = true;
            statusMSG = selectNumber;
          });
          _speak(selectNumber);
          // Show UI to let user pick one
        }
        break;

      case Command.sendMessage:
        print("✉️ Sending message to ${cmd.value}");
        setState(() {
          _isInstruction = false;
          statusMSG = "Sending messages not functional yet, please check later";
        });

        _speak(statusMSG);
        // sendMessageTo(cmd.value);
        break;
      case Command.readMessage:
        print("📖 Reading messages${cmd.value.isNotEmpty ? ' for ' + cmd.value : ''}");
        setState(() {
          _isInstruction = false;
          statusMSG = "Reading messages not functional yet, please check later";
        });

        _speak(statusMSG);
        // readMessages(cmd.value);
        break;
      case Command.unknown:
        print("❓ Couldn't understand the command: \"$spokenWord\"");
        setState(() {
          _isInstruction = false;
          statusMSG = "Couldn't understand the command: \"$spokenWord\"";
        });

        _speak(statusMSG);
        break;
    }
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

  void _onShakeDetected() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Shake Detected!')));

    setState(() {
      _isInstruction = true;
    });

    setState(() => statusMSG = instruction);
    await _speak(instruction);


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
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        tooltip: 'Listen',
        child: Icon(
          _speechToText.isNotListening ? Icons.mic_off : Icons.mic,
          color:
              _speechToText.isNotListening ? Colors.black54 : Colors.redAccent,
          size: 40,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // _speech.stop();
    super.dispose();
    _streamSubscription.cancel();
  }
}
