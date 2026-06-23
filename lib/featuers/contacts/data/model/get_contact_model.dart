import 'package:flutter/material.dart';
import 'dart:convert';

class GetContactModel {
  final bool? status;
  final GetContactData? data;
  final String? message;
  final bool? toast;

  GetContactModel({this.status, this.data, this.message, this.toast});

  factory GetContactModel.fromJson(Map<String, dynamic> json) {
    return GetContactModel(
      status: json['status'] as bool?,
      data:
          json['data'] != null
              ? GetContactData.fromJson(json['data'] as Map<String, dynamic>)
              : null,
      message: json['message'] as String?,
      toast: json['toast'] as bool?,
    );
  }
}

class GetContactData {
  final String? userName;
  final String? email;
  final int? mobileNum;
  final String? profilePic;
  final int? userId;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? countryCode;
  final String? country;
  final List<ContactDetails?>? contactDetails;

  GetContactData({
    this.userName,
    this.email,
    this.mobileNum,
    this.profilePic,
    this.userId,
    this.fullName,
    this.firstName,
    this.lastName,
    this.countryCode,
    this.country,
    this.contactDetails,
  });

  factory GetContactData.fromJson(Map<String, dynamic> json) {
    return GetContactData(
      userName: json['user_name'] as String?,
      email: json['email'] as String?,
      mobileNum: _parseInt(json['mobile_num']), // ✅ fixed
      profilePic: json['profile_pic'] as String?,
      userId: _parseInt(json['user_id']), // ✅ fixed (potentially same issue)
      fullName: json['full_name'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      countryCode: json['country_code'] as String?,
      country: json['country'] as String?,
      contactDetails: _parseContactDetails(json['contact_details']),
    );
  }

  static List<ContactDetails?>? _parseContactDetails(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded.map((item) => _parseSingleContactDetail(item)).toList();
        }
      } catch (e) {
        debugPrint('Error decoding contact_details string: $e');
      }
    } else if (value is List) {
      return value.map((item) => _parseSingleContactDetail(item)).toList();
    }
    return null;
  }

  static ContactDetails? _parseSingleContactDetail(dynamic item) {
    if (item == null) return null;
    if (item is String) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          return ContactDetails.fromJson(decoded);
        } else if (decoded is Map) {
          return ContactDetails.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('Error decoding single contact detail: $e');
      }
    } else if (item is Map<String, dynamic>) {
      return ContactDetails.fromJson(item);
    } else if (item is Map) {
      return ContactDetails.fromJson(Map<String, dynamic>.from(item));
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class ContactDetails {
  final String? name;
  final String? number; // Changed to String to handle both string and int
  final int? userId;
  final String? userName;
  final String? profilePic; // Add profile picture URL

  ContactDetails({
    this.name,
    this.number,
    this.userId,
    this.userName,
    this.profilePic,
  });

  factory ContactDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ContactDetails();
    }

    return ContactDetails(
      name: json['name'] as String?,
      number: _parseNumber(json['number']), // Safe parsing
      userId: _parseUserId(json['user_id']), // Safe parsing
      userName: json['user_name'] as String?, // Add user_name parsing
      profilePic: json['profile_pic'] as String?, // Add profile picture parsing
    );
  }

  // Helper method to safely parse number (can be string or int)
  static String? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  // Helper method to safely parse user_id (can be string or int)
  static int? _parseUserId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'number': number,
      'user_id': userId,
      'user_name': userName,
      'profile_pic': profilePic,
    };
  }
}
