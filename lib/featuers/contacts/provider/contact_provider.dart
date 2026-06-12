// import 'package:flutter/foundation.dart';
// import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:whoxa/core/error/app_error.dart';
// import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
// import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
// import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';

// class ContactListProvider with ChangeNotifier {
//   final ContactRepo _contactRepo;

//   ContactListProvider(this._contactRepo);

//   bool _isLoading = false;
//   bool _isInitialized = false;
//   String? _errorMessage;
//   bool _isInternetIssue = false;

//   List<ContactModel> _allContacts = [];
//   List<ContactModel> _filteredChatContacts = [];
//   List<ContactModel> _filteredInviteContacts = [];
//   List<ContactModel> _chatContacts = [];
//   List<ContactModel> _inviteContacts = [];

//   // Getters
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   bool get isInternetIssue => _isInternetIssue;
//   List<ContactModel> get chatContacts => _filteredChatContacts;
//   List<ContactModel> get inviteContacts => _filteredInviteContacts;

//   // Initialize contacts only once
//   Future<void> initializeContacts() async {
//     if (!_isInitialized) {
//       await loadContacts();
//       _isInitialized = true;
//     }
//   }

//   // Load contacts from both device and API
//   Future<void> loadContacts() async {
//     _isLoading = true;
//     _errorMessage = null;
//     _isInternetIssue = false;
//     notifyListeners();

//     try {
//       // 1. Request contacts permission
//       bool permissionGranted = await FlutterContacts.requestPermission();

//       if (!permissionGranted) {
//         _errorMessage = 'Contact permission denied';
//         _isLoading = false;
//         notifyListeners();
//         return;
//       }

//       // 2. Fetch contacts from device
//       final deviceContacts = await FlutterContacts.getContacts(
//         withProperties: true,
//         withPhoto: true,
//       );

//       // 3. Prepare contact details for API
//       List<Map<String, dynamic>> contactsForApi = [];
//       for (var contact in deviceContacts) {
//         if (contact.phones.isNotEmpty) {
//           for (var phone in contact.phones) {
//             String cleanNumber = _cleanPhoneNumber(phone.number);
//             if (cleanNumber.isNotEmpty) {
//               contactsForApi.add({
//                 'name': contact.displayName,
//                 'number': cleanNumber, // Send as string to avoid parsing issues
//               });
//             }
//           }
//         }
//       }

//       // 4. Send contacts to API to get matches
//       final apiResponse = await _contactRepo.contactGet(contactsForApi);

//       if (apiResponse.status == true && apiResponse.data != null) {
//         // 5. Process API response - Filter out null values and add logging
//         debugPrint(
//           'API Response received. Contact details length: ${apiResponse.data!.contactDetails?.length ?? 0}',
//         );

//         final validContactDetails =
//             (apiResponse.data!.contactDetails ?? [])
//                 .where((contact) => contact != null)
//                 .cast<ContactDetails>()
//                 .toList();

//         debugPrint(
//           'Valid contacts after filtering nulls: ${validContactDetails.length}',
//         );

//         processContacts(deviceContacts, validContactDetails);
//       } else {
//         _errorMessage = apiResponse.message ?? 'Failed to load contacts';
//         debugPrint('API Response failed: ${apiResponse.message}');
//       }
//     } on AppError catch (e) {
//       final errorData = extractErrorData(e);
//       _errorMessage = errorData?['message'] ?? 'Unknown error';
//       _isInternetIssue = _errorMessage!.contains('No internet connection');
//     } catch (e) {
//       _errorMessage = 'Failed to load contacts: ${e.toString()}';
//       debugPrint('Contact loading error: $e');
//     } finally {
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   // Clean phone number to ensure consistent format
//   String _cleanPhoneNumber(String phoneNumber) {
//     // Remove all non-numeric characters
//     String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

//     // Remove leading zeros
//     while (cleanNumber.startsWith('0')) {
//       cleanNumber = cleanNumber.substring(1);
//     }

//     // Ensure it's not too short
//     if (cleanNumber.length < 6) {
//       return '';
//     }

//     return cleanNumber;
//   }

//   // Process and categorize contacts
//   void processContacts(
//     List<Contact> deviceContacts,
//     List<ContactDetails> apiContacts,
//   ) {
//     _allContacts = [];
//     _chatContacts = [];
//     _inviteContacts = [];

//     // Create a map of API contacts for quick lookup
//     Map<String, ContactDetails> apiContactsMap = {};
//     for (var contact in apiContacts) {
//       // Add null check for contact and its properties
//       if (contact != null && contact.number != null) {
//         // Clean the API contact number for consistent matching
//         String cleanApiNumber = _cleanPhoneNumber(contact.number!);
//         if (cleanApiNumber.isNotEmpty) {
//           apiContactsMap[cleanApiNumber] = contact;
//         }
//       }
//     }

//     // Process device contacts and categorize based on API data
//     for (var contact in deviceContacts) {
//       if (contact.phones.isEmpty) continue;

//       for (var phone in contact.phones) {
//         String cleanNumber = _cleanPhoneNumber(phone.number);
//         if (cleanNumber.isEmpty) continue;

//         // Check if this contact exists in API results
//         final apiContact = apiContactsMap[cleanNumber];

//         // Create model
//         final contactModel = ContactModel(
//           name: contact.displayName,
//           phoneNumber: cleanNumber,
//           userId: apiContact?.userId?.toString(),
//           photo: contact.photo,
//         );

//         _allContacts.add(contactModel);

//         // Categorize based on userId
//         if (apiContact?.userId != null) {
//           _chatContacts.add(contactModel);
//         } else {
//           _inviteContacts.add(contactModel);
//         }
//       }
//     }

//     // Sort contacts alphabetically
//     _chatContacts.sort((a, b) => a.name.compareTo(b.name));
//     _inviteContacts.sort((a, b) => a.name.compareTo(b.name));

//     // Initialize filtered lists
//     _filteredChatContacts = List.from(_chatContacts);
//     _filteredInviteContacts = List.from(_inviteContacts);
//   }

//   // Search functionality
//   void searchContacts(String query) {
//     if (query.isEmpty) {
//       _filteredChatContacts = List.from(_chatContacts);
//       _filteredInviteContacts = List.from(_inviteContacts);
//     } else {
//       _filteredChatContacts =
//           _chatContacts
//               .where(
//                 (contact) =>
//                     contact.name.toLowerCase().contains(query.toLowerCase()) ||
//                     contact.phoneNumber.contains(query),
//               )
//               .toList();

//       _filteredInviteContacts =
//           _inviteContacts
//               .where(
//                 (contact) =>
//                     contact.name.toLowerCase().contains(query.toLowerCase()) ||
//                     contact.phoneNumber.contains(query),
//               )
//               .toList();
//     }
//     notifyListeners();
//   }

//   // Refresh contacts
//   Future<void> refreshContacts() async {
//     await loadContacts();
//   }

//   // Invite a contact
//   Future<void> inviteContact(ContactModel contact) async {
//     // Implement SMS invitation logic here
//     // This could use a platform channel to send an SMS or share via other methods
//     debugPrint('Inviting contact: ${contact.name} - ${contact.phoneNumber}');

//     // For demonstration purposes, we'll just show a success message
//     // In a real app, you'd implement the actual invitation logic
//   }
// }
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoxa/core/error/app_error.dart';
import 'package:whoxa/featuers/chat/services/contact_name_service.dart';
import 'package:whoxa/featuers/contacts/data/model/contact_model.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';
import 'package:whoxa/featuers/contacts/data/repository/contact_repo.dart';
import 'package:whoxa/featuers/contacts/services/countrycode_service.dart';
import 'package:whoxa/main.dart';
import 'package:whoxa/utils/preference_key/preference_key.dart';
import 'package:whoxa/utils/preference_key/sharedpref_key.dart';
import 'package:whoxa/widgets/global.dart' as global;
import 'package:whoxa/widgets/global.dart';

class ContactListProvider with ChangeNotifier {
  final ContactRepo _contactRepo;

  ContactListProvider(this._contactRepo) {
    _initializeCountryCodeService();
  }

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isInternetIssue = false;
  bool _countryCodeServiceInitialized = false;
  String? _defaultCountryCode; // User's country code from storage

  List<ContactModel> _allContacts = [];
  List<ContactModel> _filteredChatContacts = [];
  List<ContactModel> _filteredInviteContacts = [];
  List<ContactModel> _chatContacts = [];
  List<ContactModel> _inviteContacts = [];
  final List<ContactDetails> _demoContactList = [];

  List<int> selectedUserIds = [];

  void addUserSelection(int id) {
    selectedUserIds.add(id);
    notifyListeners();
  }

  void removeUserSelection(int id) {
    selectedUserIds.remove(id);
    notifyListeners();
  }

  int tabIndex = 0;

  void updateTabIndex(int val) {
    tabIndex = val;
    notifyListeners();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isInternetIssue => _isInternetIssue;
  List<ContactModel> get fullContactList => _allContacts;

  /// ✅ For demo accounts, return only API contacts (no device contacts)
  /// For regular accounts, return only registered contacts (like WhatsApp)
  List<ContactModel> get chatContacts {
    if (isDemo) {
      // Demo account: Show only API contacts (already processed in processContacts)
      debugPrint('📱 DEMO MODE: Returning API contacts only (${_filteredChatContacts.length})');
      return _filteredChatContacts;
    } else {
      // Regular account: Show only registered contacts
      return _filteredChatContacts;
    }
  }

  List<ContactModel> get inviteContacts => _filteredInviteContacts;
  List<ContactDetails> get demoContactList => _demoContactList;

  // Initialize country code service and get user's default country code
  Future<void> _initializeCountryCodeService() async {
    if (!_countryCodeServiceInitialized) {
      await CountryCodeService.initialize();

      // Get user's country code from secure storage
      try {
        String? rawCountryCode = await SecurePrefs.getString(
          SecureStorageKeys.COUNTRY_CODE,
        );

        // Clean the country code - remove + sign if present
        if (rawCountryCode != null && rawCountryCode.isNotEmpty) {
          _defaultCountryCode =
              rawCountryCode.startsWith('+')
                  ? rawCountryCode.substring(1)
                  : rawCountryCode;
          debugPrint(
            'Default country code from storage: $rawCountryCode -> cleaned: $_defaultCountryCode',
          );
        } else {
          _defaultCountryCode = null;
          debugPrint('No country code found in storage');
        }
      } catch (e) {
        debugPrint('Error getting country code from storage: $e');
        _defaultCountryCode = null;
      }

      _countryCodeServiceInitialized = true;
    }
  }

  // Initialize contacts only once
  Future<void> initializeContacts() async {
    debugPrint(
      '🔍 ContactListProvider.initializeContacts() called - _isInitialized: $_isInitialized',
    );
    if (!_isInitialized) {
      debugPrint('🚀 Starting contact initialization and upload...');
      await _initializeCountryCodeService();
      await loadContacts();
      _isInitialized = true;
      debugPrint(
        '✅ Contact initialization completed - _isInitialized set to true',
      );
    } else {
      debugPrint('⏭️ Skipping contact initialization - already initialized');
    }
  }

  // Force contact upload regardless of initialization state (use after logout)
  Future<void> forceUploadContacts() async {
    debugPrint(
      '🔄 forceUploadContacts() called - forcing contact upload regardless of initialization state',
    );
    await _initializeCountryCodeService();
    await loadContacts();
    _isInitialized = true;
    debugPrint('✅ Force contact upload completed');
  }

  // Load contacts from both device and API
  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    _isInternetIssue = false;
    notifyListeners();

    try {
      // Ensure country code service is initialized
      await _initializeCountryCodeService();

      // 1. ✅ FIX: Check contacts permission status first to avoid duplicate iOS prompts
      debugPrint('🔍 Checking contact permission status...');

      // First check if we already have permission without triggering a new request
      final currentPermission = await Permission.contacts.status;
      debugPrint('📱 Current contact permission status: $currentPermission');

      bool permissionGranted = currentPermission.isGranted;

      if (!permissionGranted) {
        debugPrint(
          '🔐 Contact permission not granted, requesting permission...',
        );
        // Only request permission if we don't already have it
        permissionGranted = await FlutterContacts.requestPermission(
          readonly: false,
        );

        if (!permissionGranted) {
          debugPrint('❌ Contact permission request denied');
          _errorMessage = 'Contact permission denied';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      debugPrint('✅ Contact permission confirmed: $permissionGranted');

      // 2. Fetch contacts from device
      final deviceContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      // 3. Prepare contact details for API
      List<Map<String, dynamic>> contactsForApi = [];
      for (var contact in deviceContacts) {
        if (contact.phones.isNotEmpty) {
          for (var phone in contact.phones) {
            final phoneData = _parsePhoneNumber(phone.number);
            if (phoneData['number']!.isNotEmpty) {
              contactsForApi.add({
                'name': contact.displayName,
                'number': phoneData['number'], // Number without country code
                'country_code':
                    phoneData['country_code'], // Country code separate
              });
            }
          }
        }
      }

      debugPrint('Contacts prepared for API: ${contactsForApi.length}');
      debugPrint(
        'Sample contact: ${contactsForApi.isNotEmpty ? contactsForApi.first : 'None'}',
      );

      // 4. Send contacts to API (create-contacts) to register them with backend
      final createResponse = await _contactRepo.contactGet(contactsForApi);
      if (createResponse.status == true) {
        debugPrint(
          '✅ Contacts successfully sent to backend via create-contacts API',
        );

        // 5. Now fetch updated contacts with profile pictures from get-contacts API
        debugPrint(
          '🔄 Fetching updated contacts with profile pictures via get-contacts API...',
        );
        try {
          final validContactDetails = await _contactRepo.getContactsList();

          debugPrint(
            'Get-contacts API Response received. Contact details length: ${validContactDetails.length}',
          );
          debugPrint(
            'Sample contact from get-contacts: ${validContactDetails.isNotEmpty ? "${validContactDetails.first.name} - ${validContactDetails.first.profilePic}" : "None"}',
          );
          _demoContactList.clear();
          if (mobileNum == "5628532467") {
            _demoContactList.addAll(validContactDetails);
            logger.i("_demoContactList :::: ${jsonEncode(_demoContactList)}");
          }
          processContacts(deviceContacts, validContactDetails);

          // 🎯 SIMPLIFIED: Sync API names as single source of truth (no device overrides)
          await ContactNameService.instance.syncContactDataFromApi(
            validContactDetails,
          );
          debugPrint(
            '✅ API names synced as single source of truth for display names',
          );

          // 🔄 FORCE REFRESH: Clear final name cache to ensure all screens show updated names
          debugPrint(
            '🔄 Clearing final name cache to force UI updates with latest contact names',
          );
          ContactNameService.instance.clearFinalNameCache();

          // 🔄 NOTIFY UI: Trigger UI rebuild to show updated contact names
          debugPrint(
            '🔔 Notifying listeners of contact updates for UI refresh',
          );
          notifyListeners();
        } catch (e) {
          _errorMessage =
              'Failed to get updated contacts with profile pictures: $e';
          debugPrint('Get-contacts API failed: $e');
        }
      } else {
        _errorMessage =
            createResponse.message ?? 'Failed to send contacts to backend';
        debugPrint('Create-contacts API failed: ${createResponse.message}');
      }
    } on AppError catch (e) {
      final errorData = extractErrorData(e);
      _errorMessage = errorData?['message'] ?? 'Unknown error';
      _isInternetIssue = _errorMessage!.contains('No internet connection');
    } catch (e) {
      _errorMessage = 'Failed to load contacts: ${e.toString()}';
      debugPrint('Contact loading error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Parse phone number to extract country code and number using the service
  Map<String, String> _parsePhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\+0-9]'), '');

    String countryCode = '';
    String number = '';

    if (cleanNumber.startsWith('+')) {
      // Phone number has country code - use the service to find it
      final matchedCode = CountryCodeService.findBestMatchingCountryCode(
        cleanNumber,
      );

      if (matchedCode != null) {
        countryCode = matchedCode;
        number = cleanNumber.substring(
          matchedCode.length + 1,
        ); // +1 for the '+' sign
      } else {
        // Fallback: try to extract first 1-4 digits as country code
        for (int i = 1; i <= 4 && i < cleanNumber.length; i++) {
          String potentialCode = cleanNumber.substring(1, i + 1);
          if (CountryCodeService.isValidCountryCode(potentialCode)) {
            countryCode = potentialCode;
            number = cleanNumber.substring(i + 1);
            break;
          }
        }
      }
    } else {
      // No country code present, assume it's a local number
      // Remove leading zeros
      while (cleanNumber.startsWith('0')) {
        cleanNumber = cleanNumber.substring(1);
      }

      // Use default country code from user's profile if available
      if (_defaultCountryCode != null && _defaultCountryCode!.isNotEmpty) {
        // Validate that the default country code exists in our data
        if (CountryCodeService.isValidCountryCode(_defaultCountryCode!)) {
          countryCode = _defaultCountryCode!;
          debugPrint(
            'Using default country code: $countryCode for local number: $cleanNumber',
          );
        } else {
          debugPrint(
            'Invalid default country code: $_defaultCountryCode, leaving empty',
          );
          countryCode = ''; // Leave empty if invalid
        }
      } else {
        debugPrint(
          'No default country code available for local number: $cleanNumber',
        );
        countryCode = ''; // Leave empty for local numbers
      }

      number = cleanNumber;
    }

    // Clean the number part
    number = _cleanPhoneNumber(number);

    // Validate minimum length
    if (number.length < 6) {
      return {'country_code': '', 'number': ''};
    }

    debugPrint(
      'Parsed: $phoneNumber -> countryCode: $countryCode, number: $number',
    );

    return {'country_code': countryCode, 'number': number};
  }

  // Clean phone number to ensure consistent format (number part only)
  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // Remove leading zeros
    while (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    return cleanNumber;
  }

  // Helper method to check if a contact is the user's own number
  bool _isOwnNumber(String contactNumber) {
    if (global.mobileNum.isEmpty) return false;

    // Clean both numbers for comparison using the same function from global.dart
    String cleanOwnNumber = global.getMobile(global.mobileNum);
    String cleanContactNumber = global.getMobile(contactNumber);

    // Also try cleaning with the provider's method
    String cleanOwnNumberProvider = _cleanPhoneNumber(global.mobileNum);
    String cleanContactNumberProvider = _cleanPhoneNumber(contactNumber);

    // Additional comprehensive cleaning approaches
    String ownNumberDigitsOnly = global.mobileNum.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    String contactNumberDigitsOnly = contactNumber.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // Remove leading zeros and country codes for comparison
    String ownNumberNoLeadingZeros = ownNumberDigitsOnly.replaceFirst(
      RegExp(r'^0+'),
      '',
    );
    String contactNumberNoLeadingZeros = contactNumberDigitsOnly.replaceFirst(
      RegExp(r'^0+'),
      '',
    );

    // Handle common country code scenarios (like +91 for India)
    if (ownNumberNoLeadingZeros.startsWith('91') &&
        ownNumberNoLeadingZeros.length > 10) {
      ownNumberNoLeadingZeros = ownNumberNoLeadingZeros.substring(
        2,
      ); // Remove country code
    }
    if (contactNumberNoLeadingZeros.startsWith('91') &&
        contactNumberNoLeadingZeros.length > 10) {
      contactNumberNoLeadingZeros = contactNumberNoLeadingZeros.substring(
        2,
      ); // Remove country code
    }

    /* enable to check debugging own number filter
    debugPrint('=== DEBUGGING OWN NUMBER FILTER ===');
    debugPrint('  Own number from global: "${global.mobileNum}"');
    debugPrint('  Contact number: "$contactNumber"');
    debugPrint('  Clean own (global method): "$cleanOwnNumber"');
    debugPrint('  Clean own (provider method): "$cleanOwnNumberProvider"');
    debugPrint('  Clean contact (global method): "$cleanContactNumber"');
    debugPrint(
      '  Clean contact (provider method): "$cleanContactNumberProvider"',
    );
    debugPrint('  Own digits only: "$ownNumberDigitsOnly"');
    debugPrint('  Contact digits only: "$contactNumberDigitsOnly"');
    debugPrint('  Own no leading zeros: "$ownNumberNoLeadingZeros"');
    debugPrint('  Contact no leading zeros: "$contactNumberNoLeadingZeros"'); 
    */

    // Check all possible combinations for a match
    bool isMatch =
        cleanOwnNumber == cleanContactNumber ||
        cleanOwnNumberProvider == cleanContactNumberProvider ||
        cleanOwnNumber == cleanContactNumberProvider ||
        cleanOwnNumberProvider == cleanContactNumber ||
        ownNumberDigitsOnly == contactNumberDigitsOnly ||
        ownNumberNoLeadingZeros == contactNumberNoLeadingZeros ||
        ownNumberNoLeadingZeros == cleanContactNumber ||
        cleanOwnNumber == contactNumberNoLeadingZeros;

    debugPrint('  FINAL MATCH RESULT: $isMatch');
    debugPrint('=== END OWN NUMBER FILTER DEBUG ===');

    return isMatch;
  }

  // Process and categorize contacts
  void processContacts(
    List<Contact> deviceContacts,
    List<ContactDetails> apiContacts,
  ) {
    _allContacts = [];
    _chatContacts = [];
    _inviteContacts = [];

    // ✅ DEMO MODE: For demo accounts, ONLY show contacts from API (no device contacts)
    if (isDemo) {
      debugPrint('🎭 DEMO MODE: Processing ${apiContacts.length} API contacts only (ignoring device contacts)');

      for (var apiContact in apiContacts) {
        if (apiContact.number == null || apiContact.number!.isEmpty) continue;

        final contactModel = ContactModel(
          name: apiContact.name ?? 'Unknown',
          phoneNumber: _cleanPhoneNumber(apiContact.number!),
          userId: apiContact.userId?.toString(),
          photo: null,
          profilePicUrl: apiContact.profilePic,
        );

        _allContacts.add(contactModel);
        _chatContacts.add(contactModel); // All API contacts treated as registered for demo
      }

      // Sort contacts alphabetically
      _chatContacts.sort((a, b) => a.name.compareTo(b.name));

      // Set filtered lists
      _filteredChatContacts = List.from(_chatContacts);
      _filteredInviteContacts = []; // No invite contacts for demo mode

      debugPrint('🎭 DEMO MODE: Showing ${_filteredChatContacts.length} API contacts');

      // Notify listeners and return early
      _notifyContactNameService();
      notifyListeners();
      return;
    }

    // ✅ REGULAR MODE: Process device contacts and match with API
    // Create a map of API contacts for quick lookup
    Map<String, ContactDetails> apiContactsMap = {};
    for (var contact in apiContacts) {
      // Add null check for contact's number property
      if (contact.number != null) {
        // Clean the API contact number for consistent matching
        String cleanApiNumber = _cleanPhoneNumber(contact.number!);
        if (cleanApiNumber.isNotEmpty) {
          apiContactsMap[cleanApiNumber] = contact;
        }
      }
    }

    debugPrint('Processing ${deviceContacts.length} device contacts');
    int filteredOutCount = 0;

    // Process device contacts and categorize based on API data
    for (var contact in deviceContacts) {
      if (contact.phones.isEmpty) continue;

      for (var phone in contact.phones) {
        final phoneData = _parsePhoneNumber(phone.number);
        String cleanNumber = phoneData['number']!;
        if (cleanNumber.isEmpty) continue;

        // Skip if this is the user's own number - check multiple formats
        String fullNumberWithCountryCode = '';
        if (phoneData['country_code']!.isNotEmpty) {
          fullNumberWithCountryCode =
              '+${phoneData['country_code']}${phoneData['number']}';
        }

        if (_isOwnNumber(phone.number) ||
            _isOwnNumber(cleanNumber) ||
            _isOwnNumber(fullNumberWithCountryCode) ||
            _isOwnNumber(
              '+${phoneData['country_code']} ${phoneData['number']}',
            )) {
          debugPrint('*** FILTERING OUT OWN NUMBER ***');
          debugPrint('Contact: ${contact.displayName}');
          debugPrint('Original: ${phone.number}');
          debugPrint('Clean: $cleanNumber');
          debugPrint('With country code: $fullNumberWithCountryCode');
          debugPrint('*** END FILTER OUT ***');
          filteredOutCount++;
          continue;
        }

        // Check if this contact exists in API results
        final apiContact = apiContactsMap[cleanNumber];

        // Create model
        final contactModel = ContactModel(
          name: contact.displayName,
          phoneNumber: cleanNumber,
          userId: apiContact?.userId?.toString(),
          photo: null, // Don't use device photo anymore
          profilePicUrl: apiContact?.profilePic, // Use backend profile picture
        );

        _allContacts.add(contactModel);

        // Categorize based on userId
        if (apiContact?.userId != null) {
          _chatContacts.add(contactModel);
        } else {
          _inviteContacts.add(contactModel);
        }
      }
    }

    debugPrint('Filtered out $filteredOutCount own numbers from contact list');
    debugPrint(
      'Final contact counts - Chat: ${_chatContacts.length}, Invite: ${_inviteContacts.length}',
    );

    // Sort contacts alphabetically
    _chatContacts.sort((a, b) => a.name.compareTo(b.name));
    _inviteContacts.sort((a, b) => a.name.compareTo(b.name));

    // Initialize filtered lists with additional own number filtering as final safety check
    _filteredChatContacts =
        _chatContacts
            .where(
              (contact) =>
                  !_isOwnNumber(contact.phoneNumber) &&
                  !_isOwnNumber(
                    '+${global.contrycode.replaceAll('+', '')} ${contact.phoneNumber}',
                  ),
            )
            .toList();

    _filteredInviteContacts =
        _inviteContacts
            .where(
              (contact) =>
                  !_isOwnNumber(contact.phoneNumber) &&
                  !_isOwnNumber(
                    '+${global.contrycode.replaceAll('+', '')} ${contact.phoneNumber}',
                  ),
            )
            .toList();

    debugPrint('Final safety filter applied:');
    debugPrint('  Chat contacts before final filter: ${_chatContacts.length}');
    debugPrint(
      '  Chat contacts after final filter: ${_filteredChatContacts.length}',
    );
    debugPrint(
      '  Invite contacts before final filter: ${_inviteContacts.length}',
    );
    debugPrint(
      '  Invite contacts after final filter: ${_filteredInviteContacts.length}',
    );

    // ✅ NEW: Log demo mode behavior
    if (isDemo) {
      debugPrint('🎭 DEMO MODE ACTIVE:');
      debugPrint('  - Registered contacts: ${_filteredChatContacts.length}');
      debugPrint('  - Unregistered contacts: ${_filteredInviteContacts.length}');
      debugPrint('  - Total contacts visible to demo user: ${_filteredChatContacts.length + _filteredInviteContacts.length}');
    } else {
      debugPrint('👤 REGULAR MODE:');
      debugPrint('  - Only showing registered contacts: ${_filteredChatContacts.length}');
    }

    // Notify the contact name service that contacts have been updated
    _notifyContactNameService();
  }

  // Search functionality
  void searchContacts(String query) {
    if (query.isEmpty) {
      _filteredChatContacts = List.from(_chatContacts);
      _filteredInviteContacts = List.from(_inviteContacts);
    } else {
      _filteredChatContacts =
          _chatContacts
              .where(
                (contact) =>
                    !_isOwnNumber(
                      contact.phoneNumber,
                    ) && // Additional safety check
                    (contact.name.toLowerCase().contains(query.toLowerCase()) ||
                        contact.phoneNumber.contains(query)),
              )
              .toList();

      _filteredInviteContacts =
          _inviteContacts
              .where(
                (contact) =>
                    !_isOwnNumber(
                      contact.phoneNumber,
                    ) && // Additional safety check
                    (contact.name.toLowerCase().contains(query.toLowerCase()) ||
                        contact.phoneNumber.contains(query)),
              )
              .toList();
    }

    // ✅ NEW: Debug log for demo mode
    if (isDemo) {
      debugPrint('🔍 DEMO MODE SEARCH: Total visible contacts after search: ${_filteredChatContacts.length + _filteredInviteContacts.length}');
    }

    notifyListeners();
  }

  // Refresh contacts
  Future<void> refreshContacts() async {
    await loadContacts();
  }

  // Invite a contact
  Future<void> inviteContact(ContactModel contact) async {
    // Implement SMS invitation logic here
    // This could use a platform channel to send an SMS or share via other methods
    debugPrint('Inviting contact: ${contact.name} - ${contact.phoneNumber}');
    inviteMe(contact.phoneNumber);
    // For demonstration purposes, we'll just show a success message
    // In a real app, you'd implement the actual invitation logic
  }

  Future<void> inviteMe(String phone) async {
    final uri = Uri.parse('sms:$phone?body=');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  // Get country info for a phone number (utility method)
  String? getCountryInfoForNumber(String phoneNumber) {
    final phoneData = _parsePhoneNumber(phoneNumber);
    if (phoneData['country_code']!.isNotEmpty) {
      final countryInfo = CountryCodeService.getCountryInfo(
        phoneData['country_code']!,
      );
      return countryInfo?['name'];
    }
    return null;
  }

  // Utility method to format phone number with country code
  String formatPhoneNumberWithCountryCode(String phoneNumber) {
    final phoneData = _parsePhoneNumber(phoneNumber);
    if (phoneData['country_code']!.isNotEmpty &&
        phoneData['number']!.isNotEmpty) {
      return '+${phoneData['country_code']} ${phoneData['number']}';
    }
    return phoneNumber;
  }

  // Method to update default country code (call this when user's country code changes)
  Future<void> updateDefaultCountryCode(String? newCountryCode) async {
    // Clean the country code - remove + sign if present
    if (newCountryCode != null && newCountryCode.isNotEmpty) {
      _defaultCountryCode =
          newCountryCode.startsWith('+')
              ? newCountryCode.substring(1)
              : newCountryCode;
    } else {
      _defaultCountryCode = null;
    }

    debugPrint('Updated default country code to: $_defaultCountryCode');

    // Optionally, you can save it to storage here if needed
    if (_defaultCountryCode != null && _defaultCountryCode!.isNotEmpty) {
      try {
        // Save with + sign to storage for consistency
        await SecurePrefs.setString(
          SecureStorageKeys.COUNTRY_CODE,
          '+$_defaultCountryCode',
        );
      } catch (e) {
        debugPrint('Error saving country code to storage: $e');
      }
    }

    // If contacts are already loaded, you might want to refresh them
    // to apply the new default country code
    if (_isInitialized) {
      await refreshContacts();
    }
  }

  // Get the current default country code
  String? get defaultCountryCode => _defaultCountryCode;

  // Reset contact provider state (call this on user logout)
  void resetContactProvider() {
    debugPrint('🔄 Resetting ContactListProvider for user logout/login');
    debugPrint('   Previous state - _isInitialized: $_isInitialized');
    _isInitialized = false;
    _countryCodeServiceInitialized = false;
    _defaultCountryCode = null;
    _allContacts = [];
    _filteredChatContacts = [];
    _filteredInviteContacts = [];
    _chatContacts = [];
    _inviteContacts = [];
    _isLoading = false;
    _errorMessage = null;
    _isInternetIssue = false;

    // Clear the contact name service cache as well
    try {
      ContactNameService.instance.clearCache();
      debugPrint('✅ ContactNameService cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing ContactNameService cache: $e');
    }

    notifyListeners();
    debugPrint(
      '✅ ContactListProvider reset completed - _isInitialized now: $_isInitialized',
    );
  }

  // Method to notify contact name service when contacts are loaded
  void _notifyContactNameService() {
    // This will be called after contacts are processed to update the cache
    try {
      final contactNameService = ContactNameService.instance;

      // ✅ CRITICAL FIX: Create a map of userId to LOCAL DEVICE contact name, not API name
      Map<int, String> localContactMap = {};
      for (final contact in _chatContacts) {
        if (contact.userId != null && contact.userId!.isNotEmpty) {
          final userId = int.tryParse(contact.userId!);
          if (userId != null) {
            // Use LOCAL device contact name (contact.name is from device contacts)
            localContactMap[userId] = contact.name;

            if (kDebugMode) {
              debugPrint(
                '🏆 _notifyContactNameService: userId=$userId → LOCAL NAME: "${contact.name}" (Priority 1)',
              );
            }
          }
        }
      }

      debugPrint(
        '✅ Updating contact name service with ${localContactMap.length} LOCAL device contact names',
      );
      contactNameService
          .updateCacheWithContacts(localContactMap)
          .then((_) {
            debugPrint(
              '✅ ContactNameService cache updated with ${localContactMap.length} LOCAL device contact names (Priority 1)',
            );
          })
          .catchError((e) {
            debugPrint(
              '❌ Error updating ContactNameService with local device contact names: $e',
            );
          });
    } catch (e) {
      debugPrint('❌ Error notifying contact name service: $e');
    }
  }

  // Update the existing processContacts method to include cache notification
  // Note: processContacts is already defined in this class, so we add the notification there
}
