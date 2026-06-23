import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:whoxa/core/api/api_client.dart';
import 'package:whoxa/core/api/api_endpoint.dart';
import 'package:whoxa/featuers/contacts/data/model/get_contact_model.dart';

class ContactRepo {
  final ApiClient _apiClient;

  ContactRepo(this._apiClient);

  GetContactModel contactModel = GetContactModel();

  Future<GetContactModel> contactGet(List<Map<String, dynamic>> contact) async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.userCreateContact,
        method: "POST",
        body: {'contact_details': contact},
      );

      contactModel = GetContactModel.fromJson(response);

      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  Future<GetContactModel> getContacts() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getContacts,
        method: "GET",
      );

      final contactModel = GetContactModel.fromJson(response);
      return contactModel;
    } catch (e) {
      rethrow;
    }
  }

  // New method specifically for parsing get-contacts response
  Future<List<ContactDetails>> getContactsList() async {
    try {
      final response = await _apiClient.request(
        ApiEndpoints.getContacts,
        method: "GET",
      );

      if (response == null) return [];

      if (response is Map) {
        if (response['status'] == true && response['data'] != null) {
          final dataVal = response['data'];
          List<dynamic> contactDataList = [];
          if (dataVal is String) {
            try {
              final decoded = jsonDecode(dataVal);
              if (decoded is List) {
                contactDataList = decoded;
              }
            } catch (e) {
              debugPrint('Error decoding response data string: $e');
            }
          } else if (dataVal is List) {
            contactDataList = dataVal;
          }

          return contactDataList
              .where((contact) => contact != null)
              .map((contact) {
                if (contact is String) {
                  try {
                    final decoded = jsonDecode(contact);
                    if (decoded is Map<String, dynamic>) {
                      return ContactDetails.fromJson(decoded);
                    } else if (decoded is Map) {
                      return ContactDetails.fromJson(Map<String, dynamic>.from(decoded));
                    }
                  } catch (e) {
                    debugPrint('Error decoding contact JSON string: $e');
                  }
                  return ContactDetails();
                } else if (contact is Map<String, dynamic>) {
                  return ContactDetails.fromJson(contact);
                } else if (contact is Map) {
                  return ContactDetails.fromJson(Map<String, dynamic>.from(contact));
                }
                return ContactDetails();
              })
              .toList();
        }
      } else if (response is List) {
        return response
            .where((contact) => contact != null)
            .map((contact) {
              if (contact is String) {
                try {
                  final decoded = jsonDecode(contact);
                  if (decoded is Map<String, dynamic>) {
                    return ContactDetails.fromJson(decoded);
                  } else if (decoded is Map) {
                    return ContactDetails.fromJson(Map<String, dynamic>.from(decoded));
                  }
                } catch (e) {
                  debugPrint('Error decoding contact JSON string: $e');
                }
                return ContactDetails();
              } else if (contact is Map<String, dynamic>) {
                return ContactDetails.fromJson(contact);
              } else if (contact is Map) {
                return ContactDetails.fromJson(Map<String, dynamic>.from(contact));
              }
              return ContactDetails();
            })
            .toList();
      }
      
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
