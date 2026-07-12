import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session.dart';

class SessionService {
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();

  factory SessionService() => _instance;

  SessionService._internal() {
    _populateMocks();
  }

  final List<Session> _sessions = [];
  final List<SessionShortcut> _shortcuts = [];

  // Get current user ID dynamically from Firebase Auth
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

  // Listener pattern to notify UI when state changes
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);

  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  void _populateMocks() {
    // A mock active session created by the current user
    _sessions.add(
      Session(
        sessionID: 'sess_1',
        title: 'Advanced Agentic Coding Lecture',
        subtitle: 'Understanding autonomous reasoning loops and tool calling.',
        folder: 'Lectures',
        expiry: DateTime.now().add(const Duration(hours: 2)),
        joinCode: 'AGENT1',
        creatorId: 'test_user_id',
        isDeleted: false,
      ),
    );

    // An expired mock session created by the current user
    _sessions.add(
      Session(
        sessionID: 'sess_2',
        title: 'Intro to Dart & Flutter (Expired)',
        subtitle: 'Building responsive layouts and working with widgets.',
        folder: 'Seminars',
        expiry: DateTime.now().subtract(const Duration(days: 1)),
        joinCode: 'FLUTT2',
        creatorId: 'test_user_id',
        isDeleted: false,
      ),
    );

    // A session created by a different user
    _sessions.add(
      Session(
        sessionID: 'sess_3',
        title: 'Mobile Architecture Seminar',
        subtitle: 'Discussing Clean Architecture vs Riverpod vs Bloc.',
        folder: 'Architecture',
        expiry: DateTime.now().add(const Duration(hours: 5)),
        joinCode: 'CLEAN3',
        creatorId: 'other_user_id',
        isDeleted: false,
      ),
    );

    // Add a shortcut link for the current user to sess_3
    _shortcuts.add(
      SessionShortcut(userID: 'test_user_id', sessionID: 'sess_3'),
    );
  }

  // Get all active sessions for the current user (either created by them or in their shortcuts)
  List<Session> getActiveSessions() {
    final uid = _currentUserId;
    final shortcutIds = _shortcuts
        .where((s) => s.userID == uid)
        .map((s) => s.sessionID)
        .toSet();

    return _sessions.where((session) {
      if (session.isDeleted) return false;
      return session.creatorId == uid ||
          shortcutIds.contains(session.sessionID);
    }).toList();
  }

  // Get all soft-deleted sessions created by the current user
  List<Session> getTrashedSessions() {
    final uid = _currentUserId;
    return _sessions.where((session) {
      return session.isDeleted && session.creatorId == uid;
    }).toList();
  }

  // Check if a session ID is a shortcut for the current user
  bool isSessionShortcut(String sessionID) {
    final uid = _currentUserId;
    return _shortcuts.any((s) => s.userID == uid && s.sessionID == sessionID);
  }

  // Create a new session
  Session createSession(
    String title,
    String subtitle,
    Duration expiryDuration,
  ) {
    final code = _generateRandomCode();
    final newSession = Session(
      sessionID: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      folder: 'Default',
      expiry: DateTime.now().add(expiryDuration),
      joinCode: code,
      creatorId: _currentUserId,
      isDeleted: false,
    );
    _sessions.add(newSession);
    _notifyListeners();
    return newSession;
  }

  // Join a session via joinCode (adds to shortcuts if not the creator)
  String? joinSessionByCode(String code) {
    final cleanCode = code.trim().toUpperCase();

    // Find the session
    final sessionIndex = _sessions.indexWhere(
      (s) => s.joinCode == cleanCode && !s.isDeleted,
    );
    if (sessionIndex == -1) {
      return 'Session not found or has been deleted.';
    }

    final session = _sessions[sessionIndex];
    final uid = _currentUserId;

    // A creator cannot add their own session as a shortcut
    if (session.creatorId == uid) {
      return 'You are the creator of this session. It is already on your dashboard!';
    }

    // Check if shortcut already exists
    final exists = _shortcuts.any(
      (s) => s.userID == uid && s.sessionID == session.sessionID,
    );
    if (exists) {
      return 'You have already added this session to your shortcuts.';
    }

    // Create shortcut
    _shortcuts.add(SessionShortcut(userID: uid, sessionID: session.sessionID));
    _notifyListeners();
    return null; // Success
  }

  // Delete a session (soft-delete if creator, remove shortcut if participant)
  void deleteSession(String sessionID) {
    final uid = _currentUserId;
    final sessionIndex = _sessions.indexWhere((s) => s.sessionID == sessionID);

    if (sessionIndex != -1) {
      final session = _sessions[sessionIndex];
      if (session.creatorId == uid) {
        // Soft delete
        _sessions[sessionIndex] = session.copyWith(isDeleted: true);
      } else {
        // Participant deletes it -> just remove their shortcut
        _shortcuts.removeWhere(
          (s) => s.userID == uid && s.sessionID == sessionID,
        );
      }
      _notifyListeners();
    }
  }

  // Restore a soft-deleted session (only creator can do this)
  void restoreSession(String sessionID) {
    final uid = _currentUserId;
    final sessionIndex = _sessions.indexWhere((s) => s.sessionID == sessionID);

    if (sessionIndex != -1) {
      final session = _sessions[sessionIndex];
      if (session.creatorId == uid) {
        _sessions[sessionIndex] = session.copyWith(isDeleted: false);
        _notifyListeners();
      }
    }
  }

  // Permanently delete a session from the list (only creator can do this)
  void permanentlyDeleteSession(String sessionID) {
    final uid = _currentUserId;
    _sessions.removeWhere(
      (s) => s.sessionID == sessionID && s.creatorId == uid,
    );
    _notifyListeners();
  }

  // Helper to generate a random 6-character alphanumeric code
  String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      6,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
