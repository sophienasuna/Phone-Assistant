import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents a simplified contact with just name and one phone number
class SimpleContact {
  final String name;
  final String phoneNumber;

  SimpleContact({required this.name, required this.phoneNumber});
}

/// Tries to call a contact by name.
/// If one match is found, dials the first number immediately.
/// If multiple, returns a list of [SimpleContact] for UI to choose from.
Future<List<SimpleContact>> callContact(String nameQuery) async {
  // 1. Request permission
  if (!await FlutterContacts.requestPermission()) {
    return [];
  }

  // 2. Get contacts with properties (e.g., phone numbers)
  final contacts = await FlutterContacts.getContacts(withProperties: true);
  final query = nameQuery.toLowerCase();

  // 3. Match by fuzzy name
  final matches = contacts.where((contact) {
    final name = contact.displayName.toLowerCase();
    print('-------------YYYY--${name}  ------${tokenSortRatio(name, query)}');
    return tokenSortRatio(name, query) >= 75 && contact.phones.isNotEmpty;
  }).toList();

  if (matches.isEmpty) {
    print('❌ No contact found for "$nameQuery"');
    return [];
  }

  // 4. Extract only first number per match
  final simplifiedMatches = matches.map((c) {
    final number = c.phones.first.number.replaceAll(RegExp(r'\s+'), '');
    return SimpleContact(name: c.displayName, phoneNumber: number);
  }).toList();

  if (simplifiedMatches.length == 1) {
    final contact = simplifiedMatches.first;
    await FlutterPhoneDirectCaller.callNumber(contact.phoneNumber);
    // final uri = Uri(scheme: 'tel', path: contact.phoneNumber);
    // if (await canLaunchUrl(uri)) {
    //   await launchUrl(uri);
    //   return []; // Dialed successfully
    // } else {
    //   // throw Exception('Could not launch dialer for ${contact.phoneNumber}');
    //   return [];
    // }
    return [];
  }

  // 5. Return list to present options to user
  return simplifiedMatches;
}
