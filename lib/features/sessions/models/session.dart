import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String sessionID;
  final String title;
  final String subtitle;
  final String folder;
  final DateTime expiry;
  final String joinCode;
  final bool isDeleted;
  final String creatorId;

  Session({
    required this.sessionID,
    required this.title,
    required this.subtitle,
    required this.folder,
    required this.expiry,
    required this.joinCode,
    this.isDeleted = false,
    required this.creatorId,
  });

  // Getter to determine if the session has expired
  bool get isExpired => DateTime.now().isAfter(expiry);

  Session copyWith({
    String? sessionID,
    String? title,
    String? subtitle,
    String? folder,
    DateTime? expiry,
    String? joinCode,
    bool? isDeleted,
    String? creatorId,
  }) {
    return Session(
      sessionID: sessionID ?? this.sessionID,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      folder: folder ?? this.folder,
      expiry: expiry ?? this.expiry,
      joinCode: joinCode ?? this.joinCode,
      isDeleted: isDeleted ?? this.isDeleted,
      creatorId: creatorId ?? this.creatorId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionID': sessionID,
      'title': title,
      'subtitle': subtitle,
      'folder': folder,
      'expiry': Timestamp.fromDate(expiry),
      'joinCode': joinCode,
      'isDeleted': isDeleted,
      'creatorId': creatorId,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    final expiryData = map['expiry'];
    DateTime expiryDate;
    if (expiryData is Timestamp) {
      expiryDate = expiryData.toDate();
    } else if (expiryData is int) {
      expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryData);
    } else if (expiryData is String) {
      expiryDate = DateTime.parse(expiryData);
    } else {
      expiryDate = DateTime.now();
    }

    return Session(
      sessionID: map['sessionID'] ?? '',
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      folder: map['folder'] ?? '',
      expiry: expiryDate,
      joinCode: map['joinCode'] ?? '',
      isDeleted: map['isDeleted'] ?? false,
      creatorId: map['creatorId'] ?? '',
    );
  }
}

class SessionShortcut {
  final String userID;
  final String sessionID;

  SessionShortcut({required this.userID, required this.sessionID});

  Map<String, dynamic> toMap() {
    return {
      'userID': userID,
      'sessionID': sessionID,
    };
  }

  factory SessionShortcut.fromMap(Map<String, dynamic> map) {
    return SessionShortcut(
      userID: map['userID'] ?? '',
      sessionID: map['sessionID'] ?? '',
    );
  }
}
