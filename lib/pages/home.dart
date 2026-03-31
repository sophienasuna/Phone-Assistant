import 'dart:async';
import 'dart:math';

import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
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

  final Telephony telephony = Telephony.instance;

  late StreamSubscription<AccelerometerEvent> _streamSubscription;

  // // Speech to text
  final SpeechToText _speechToText = SpeechToText();

  bool _isInstruction = false;
  bool _isListeningToInstruction = true;
  bool _selectingContact = false;
  bool _isListeningToCMD = false;
  String spokenCMD = '';
  List<SimpleContact> _contactList = [];

  //Sending message
  bool _isWritingMSG = false;
  String writtenMSG = '';
  SimpleContact? selectedContact;
  bool isSMSMode = false;

   late SmsSendStatusListener SMSlistener;

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
      setState(() {
        _isListeningToInstruction = false;
      });
      if (_isInstruction) {
        //after giving instructions, listening to what user says
        _startListening();
      }
    });

    SMSlistener = (SendStatus status) {

      setState(() {
        statusMSG = "Done";
      });
      // Handle the status
      print('--------->${status.name}, ---------->${status.toString()}');
      if(status.name == 'SENT'){
        _speak("Message sent successfully");
      }else{
        _speak("Failed to send Message");
      }
    };

  }

  Future _speak(String msg) async {
    setState(() {
      _isListeningToInstruction = true;
    });
    await flutterTts.speak(msg);
  }

  /// This has to happen only once per app
  void _initSpeech() async {
    await _speechToText.initialize();
    setState(() {});
  }

  /// Each time to start a speech recognition session
  void _startListening() async {
    print('---_isListeningToCMD----$_isListeningToCMD');
    if (!_isListeningToCMD) {
      setState(() {
        _isListeningToCMD = true;
        spokenCMD = "";
      });
      if (isSMSMode) {
        Future.delayed(Duration(seconds: 15)).then((_) {
          handleSPOKENSMS();
        });
      } else {
        Future.delayed(Duration(seconds: 5)).then((_) {
          handleCMD();
        });
      }
      print("------->>Starting to listen<<<<");
      await _speechToText.listen(onResult: _onSpeechResult);
    }
  }

  void _stopListening() async {
    await _speechToText.stop();
    print("------->>Stopped listening<<<<");
    setState(() {
      _isListeningToCMD = false;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    spokenCMD = result.recognizedWords;
    print("----Spoken ====$spokenCMD");
    // handleCMD(_lastWords);
    // _stopListening();
  }

  void handleMultipleSelection() {
    print('📇 Multiple matches:');
    String selectNumber = 'Please select the number you want to call.\n';
    if (isSMSMode) {
      selectNumber = 'Please select the number you want to message.\n';
    }
    int count = 0;
    for (var c in _contactList) {
      count += 1;
      print('• ${c.name} - ${c.phoneNumber}');
      selectNumber += '$count. For ${c.name} on ${c.phoneNumber}. \n';
    }
    setState(() {
      _isInstruction = true;
      statusMSG = selectNumber;
    });
    _speak(selectNumber);
  }

  void handleNumberSelection(int number) {
    int index = number - 1;
    print('--------Selected Number: $number');
    if (index >= 0 && index < _contactList.length) {
      final contact = _contactList[index];
      selectedContact = contact;
      if (isSMSMode) {
        giveSMSInstructions();
      } else {
        setState(() {
          _isInstruction = false;
          _selectingContact = false;
        });
        FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
      }
    } else {
      setState(() {
        _isInstruction = false;
        statusMSG =
            "Unknown value $number, please shake again for selection instructions.";
      });
    }
  }

  void giveSMSInstructions() {
    String info =
        'Please speak the message, and shake the phone to send when done.';

    setState(() {
      isSMSMode = true;
      writtenMSG = '';
      _isWritingMSG = true;
      _isInstruction = true;
      statusMSG = instruction;
    });

    _speak(info);
  }

  Future<void> handleCMD() async {
    _stopListening();
    print('------>Final spoken word: $spokenCMD');
    setState(() {
      statusMSG = 'CMD: $spokenCMD';
    });

    if (_selectingContact) {
      int saidValue = parseNumberFromSpeech(spokenCMD);
      handleNumberSelection(saidValue);
      return;
    }

    print('------XXX----> $spokenCMD');
    final cmd = parseVoiceCommand(spokenCMD);
    print('---->CMD: ${cmd.cmd} ----->Value: ${cmd.value}');
    switch (cmd.cmd) {
      case Command.call:
        final results = await callContact(cmd.value);

        if (results.isEmpty) {
          print('✅ No contact found.');
        } else {
          if (results.length == 1) {
            final contact = results.first;
            print("📞 Calling ${contact.name}");

            setState(() {
              _isInstruction = false;
              statusMSG = "Calling ${contact.name}";
            });

            _speak(statusMSG);

            await FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
          } else {
            setState(() {
              _selectingContact = true;
              _contactList = results;
            });

            handleMultipleSelection();
          }
        }

        break;

      case Command.sendMessage:
        print("✉️ Sending message to ${cmd.value}");
        //
        // setState(() {
        //   _isInstruction = false;
        //   statusMSG = "Sending messages not functional yet, please check later";
        // });
        //
        // _speak(statusMSG);
        // sendMessageTo(cmd.value);

        final results = await callContact(cmd.value);

        if (results.isEmpty) {
          print('✅ No contact found.');
        } else {
          if (results.length == 1) {
            final contact = results.first;
            selectedContact = contact;
            print("📞 Selected contact: ${contact.name}");
            giveSMSInstructions();
            // setState(() {
            //   _isInstruction = false;
            //   statusMSG = "Calling ${contact.name}";
            // });
            //
            // _speak(statusMSG);

            // await FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
          } else {
            setState(() {
              _selectingContact = true;
              _contactList = results;
              isSMSMode = true;
            });

            handleMultipleSelection();
          }
        }
        break;

      case Command.readMessage:
        print(
          "📖 Reading messages${cmd.value.isNotEmpty ? ' for ${cmd.value}' : ''}",
        );
        setState(() {
          _isInstruction = false;
          statusMSG = "Reading messages not functional yet, please check later";
        });

        _speak(statusMSG);
        // readMessages(cmd.value);
        break;
      case Command.unknown:
        print("❓ Couldn't understand the command: \"$spokenCMD\"");
        setState(() {
          _isInstruction = false;
          statusMSG = "Couldn't understand the command: \"$spokenCMD\"";
        });

        _speak(statusMSG);
        break;
    }
  }
  void sendSMS(){

    final message = writtenMSG;
    final contact = selectedContact!.phoneNumber;
    //sending message here;
    //End of message sending;

    telephony.sendSms(
      isMultipart: message.length >= 160,
        to: contact,
        message: message,
        statusListener: SMSlistener
    );

    setState(() {
      _isWritingMSG = false;
      _isInstruction = false;
      _isListeningToInstruction = false;
      _isListeningToCMD = false;
      _contactList = [];
      isSMSMode = false;
      spokenCMD = '';
      statusMSG = 'Sending Message';
    });


  }
  Future<void> handleSPOKENSMS() async {
    _stopListening();
    String lastSpoken = spokenCMD;
    writtenMSG += lastSpoken;
    print('-----||------> Last Spoken: $lastSpoken');
    print('------||-----> Written MSG: $writtenMSG');
    String info =
        'The message is: $writtenMSG. Shake to send to ${selectedContact?.name}';
    setState(() {
      statusMSG = 'SMG: $writtenMSG';
      _isInstruction = false;
    });

    _speak(info);
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

    if (isSMSMode &&
        !_isInstruction &&
        _isWritingMSG &&
        selectedContact != null) {
      sendSMS();
      return;
    }

    if (_selectingContact) {
      handleMultipleSelection();
      return;
    }

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
        onPressed: _isListeningToInstruction ? null : _startListening,
        tooltip: 'Listen',
        child: Icon(
          !_isListeningToCMD ? Icons.mic_off : Icons.mic,
          color: !_isListeningToCMD ? Colors.black54 : Colors.redAccent,
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
