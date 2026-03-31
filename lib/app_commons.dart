// import 'package:contacts_service/contacts_service.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

enum Command { call, sendMessage, readMessage, unknown }

class VoiceCommand {
  final Command cmd;
  final String value;

  VoiceCommand(this.cmd, this.value);
}

VoiceCommand parseVoiceCommand(String spokenWord) {
  final cleaned = spokenWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

  const callKeywords = ['call', 'dial'];
  const sendKeywords = ['send message', 'send', 'text'];
  const readKeywords = ['read message', 'read', 'check messages'];

  final commandMap = {
    Command.call: callKeywords,
    Command.sendMessage: sendKeywords,
    Command.readMessage: readKeywords,
  };

  Command matchedCommand = Command.unknown;
  String matchedKeyword = '';
  int bestScore = 0;

  for (var entry in commandMap.entries) {
    for (var keyword in entry.value) {
      final score = tokenSortRatio(cleaned, keyword);
      // print('>>>>>>>>>>>>>${keyword}<<<<<<<<<<<>>>>>$score');
      if (score > bestScore && score >= 50) {
        bestScore = score;
        matchedCommand = entry.key;
        matchedKeyword = keyword;
      }
    }
  }

  // Strip matched keyword from spoken phrase to get value
  String value = cleaned;
  if (matchedKeyword.isNotEmpty) {
    final pattern = RegExp(RegExp.escape(matchedKeyword), caseSensitive: false);
    value = cleaned.replaceFirst(pattern, '').trim();
  }

  return VoiceCommand(matchedCommand, value);
}


int parseNumberFromSpeech(String spokenWord) {
  print('------X->SPOKEN WORD-<X----> $spokenWord');
  final cleaned = spokenWord.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

  const numberWords = {
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20
    // Add more if needed
  };

  // Try exact match
  if (numberWords.containsKey(cleaned)) {
    return numberWords[cleaned]!;
  }

  // Try fuzzy match using tokenSortRatio
  int bestScore = 0;
  int matchedNumber = -1;
  for (var entry in numberWords.entries) {
    final score = tokenSortRatio(cleaned, entry.key);
    if (score > bestScore && score >= 80) {
      bestScore = score;
      matchedNumber = entry.value;
    }
  }

  return matchedNumber; // Returns -1 if no match
}

