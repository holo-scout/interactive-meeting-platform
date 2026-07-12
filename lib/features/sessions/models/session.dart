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
}

class SessionShortcut {
  final String userID;
  final String sessionID;

  SessionShortcut({required this.userID, required this.sessionID});
}
