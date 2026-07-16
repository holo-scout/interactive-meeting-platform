import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';
import '../models/folder.dart';

class SessionService {
  // Singleton pattern
  static final SessionService _instance = SessionService._internal();

  factory SessionService() => _instance;

  SessionService._internal() {
    _initAuthAndFirestoreListeners();
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

  StreamSubscription? _authSubscription;
  StreamSubscription? _shortcutsSubscription;
  StreamSubscription? _createdSessionsSubscription;
  StreamSubscription? _shortcutSessionsSubscription;
  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _foldersSubscription;

  List<Session> _createdSessions = [];
  List<Session> _shortcutSessions = [];
  final List<String> _favoriteSessionIds = [];
  final List<Folder> _folders = [];

  void _initAuthAndFirestoreListeners() {
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid ?? 'test_user_id';
      _setupFirestoreListeners(uid);
    });
  }

  void _setupFirestoreListeners(String uid) {
    // Cancel any previous subscriptions
    _shortcutsSubscription?.cancel();
    _createdSessionsSubscription?.cancel();
    _shortcutSessionsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    _foldersSubscription?.cancel();

    // Clear caches
    _sessions.clear();
    _shortcuts.clear();
    _createdSessions.clear();
    _shortcutSessions.clear();
    _favoriteSessionIds.clear();
    _folders.clear();
    _notifyListeners();

    // 1. Listen to shortcuts for this user
    _shortcutsSubscription = FirebaseFirestore.instance
        .collection('shortcuts')
        .where('userID', isEqualTo: uid)
        .snapshots()
        .listen((shortcutsSnapshot) {
      _shortcuts.clear();
      final List<String> shortcutSessionIds = [];

      for (var doc in shortcutsSnapshot.docs) {
        final shortcut = SessionShortcut.fromMap(doc.data());
        _shortcuts.add(shortcut);
        shortcutSessionIds.add(shortcut.sessionID);
      }

      _notifyListeners();

      // Update the shortcut sessions subscription
      _updateShortcutSessionsListener(shortcutSessionIds);
    }, onError: (error) {
      debugPrint("Error listening to shortcuts: $error");
    });

    // 2. Listen to created sessions for this user
    _createdSessionsSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .where('creatorId', isEqualTo: uid)
        .snapshots()
        .listen((sessionsSnapshot) {
      _createdSessions = sessionsSnapshot.docs
          .map((doc) => Session.fromMap(doc.data()))
          .toList();
      _mergeAndNotify();
    }, onError: (error) {
      debugPrint("Error listening to created sessions: $error");
    });

    // 3. Listen to favorites for this user
    _favoritesSubscription = FirebaseFirestore.instance
        .collection('favorites')
        .where('userID', isEqualTo: uid)
        .snapshots()
        .listen((favoritesSnapshot) {
      _favoriteSessionIds.clear();
      for (var doc in favoritesSnapshot.docs) {
        final sessionID = doc.data()['sessionID'] as String?;
        if (sessionID != null) {
          _favoriteSessionIds.add(sessionID);
        }
      }
      _notifyListeners();
    }, onError: (error) {
      debugPrint("Error listening to favorites: $error");
    });

    // 4. Listen to folders for this user
    _foldersSubscription = FirebaseFirestore.instance
        .collection('folders')
        .where('userID', isEqualTo: uid)
        .snapshots()
        .listen((foldersSnapshot) {
      _folders.clear();
      for (var doc in foldersSnapshot.docs) {
        _folders.add(Folder.fromMap(doc.data()));
      }
      _notifyListeners();
    }, onError: (error) {
      debugPrint("Error listening to folders: $error");
    });
  }

  void _updateShortcutSessionsListener(List<String> shortcutSessionIds) {
    _shortcutSessionsSubscription?.cancel();
    _shortcutSessionsSubscription = null;

    if (shortcutSessionIds.isEmpty) {
      _shortcutSessions.clear();
      _mergeAndNotify();
      return;
    }

    // Firestore whereIn has a limit of 30 items
    final queryIds = shortcutSessionIds.take(30).toList();

    _shortcutSessionsSubscription = FirebaseFirestore.instance
        .collection('sessions')
        .where(FieldPath.documentId, whereIn: queryIds)
        .snapshots()
        .listen((sessionsSnapshot) {
      _shortcutSessions = sessionsSnapshot.docs
          .map((doc) => Session.fromMap(doc.data()))
          .toList();
      _mergeAndNotify();
    }, onError: (error) {
      debugPrint("Error listening to shortcut sessions: $error");
    });
  }

  void _mergeAndNotify() {
    final Map<String, Session> merged = {};
    for (var s in _createdSessions) {
      merged[s.sessionID] = s;
    }
    for (var s in _shortcutSessions) {
      merged[s.sessionID] = s;
    }
    _sessions.clear();
    _sessions.addAll(merged.values);
    _notifyListeners();
  }

  // Dispose subscriptions when service is disposed
  void dispose() {
    _authSubscription?.cancel();
    _shortcutsSubscription?.cancel();
    _createdSessionsSubscription?.cancel();
    _shortcutSessionsSubscription?.cancel();
    _favoritesSubscription?.cancel();
    _foldersSubscription?.cancel();
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

  // Check if a session is favorited by the current user
  bool isSessionFavorite(String sessionID) {
    return _favoriteSessionIds.contains(sessionID);
  }

  // Toggle favorite status in Firestore
  Future<void> toggleFavorite(String sessionID) async {
    final uid = _currentUserId;
    final favId = '${uid}_$sessionID';
    final docRef = FirebaseFirestore.instance.collection('favorites').doc(
        favId);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'userID': uid,
        'sessionID': sessionID,
      });
    }
  }

  // Get all active sessions that are favorited
  List<Session> getFavoriteSessions() {
    final active = getActiveSessions();
    return active
        .where((s) => _favoriteSessionIds.contains(s.sessionID))
        .toList();
  }

  // Create a new session in Firestore
  Future<Session> createSession(
    String title,
    String subtitle,
    Duration expiryDuration,) async {
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

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(newSession.sessionID)
        .set(newSession.toMap());

    return newSession;
  }

  // Join a session via joinCode (adds to shortcuts if not the creator)
  Future<String?> joinSessionByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    final uid = _currentUserId;

    try {
      // Find the session in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('joinCode', isEqualTo: cleanCode)
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'Session not found or has been deleted.';
      }

      final sessionDoc = querySnapshot.docs.first;
      final session = Session.fromMap(sessionDoc.data());

      // A creator cannot add their own session as a shortcut
      if (session.creatorId == uid) {
        return 'You are the creator of this session. It is already on your dashboard!';
      }

      // Check if shortcut already exists
      final shortcutId = '${uid}_${session.sessionID}';
      final shortcutDoc = await FirebaseFirestore.instance
          .collection('shortcuts')
          .doc(shortcutId)
          .get();

      if (shortcutDoc.exists) {
        return 'You have already added this session to your shortcuts.';
      }

      // Create shortcut
      final shortcut = SessionShortcut(
          userID: uid, sessionID: session.sessionID);
      await FirebaseFirestore.instance
          .collection('shortcuts')
          .doc(shortcutId)
          .set(shortcut.toMap());

      return null; // Success
    } catch (e) {
      return 'Failed to join session: $e';
    }
  }

  // Delete a session (soft-delete if creator, remove shortcut if participant)
  Future<void> deleteSession(String sessionID) async {
    final uid = _currentUserId;
    final docRef = FirebaseFirestore.instance.collection('sessions').doc(
        sessionID);
    final doc = await docRef.get();

    if (doc.exists) {
      final session = Session.fromMap(doc.data()!);
      if (session.creatorId == uid) {
        // Soft delete
        await docRef.update({'isDeleted': true});
      } else {
        // Participant deletes it -> just remove their shortcut
        final shortcutId = '${uid}_$sessionID';
        await FirebaseFirestore.instance
            .collection('shortcuts')
            .doc(shortcutId)
            .delete();
      }
    }
  }

  // Restore a soft-deleted session (only creator can do this)
  Future<void> restoreSession(String sessionID) async {
    final uid = _currentUserId;
    final docRef = FirebaseFirestore.instance.collection('sessions').doc(
        sessionID);
    final doc = await docRef.get();

    if (doc.exists) {
      final session = Session.fromMap(doc.data()!);
      if (session.creatorId == uid) {
        await docRef.update({'isDeleted': false});
      }
    }
  }

  // Permanently delete a session from the list (only creator can do this)
  Future<void> permanentlyDeleteSession(String sessionID) async {
    final uid = _currentUserId;
    final docRef = FirebaseFirestore.instance.collection('sessions').doc(
        sessionID);
    final doc = await docRef.get();

    if (doc.exists) {
      final session = Session.fromMap(doc.data()!);
      if (session.creatorId == uid) {
        await docRef.delete();
        // Clean up shortcuts associated with this session
        final shortcutsQuery = await FirebaseFirestore.instance
            .collection('shortcuts')
            .where('sessionID', isEqualTo: sessionID)
            .get();
        for (var doc in shortcutsQuery.docs) {
          await doc.reference.delete();
        }
      }
    }
  }

  // Get folders for the current user
  List<Folder> getFolders() {
    return _folders;
  }

  // Create a new folder
  Future<void> createFolder(String name) async {
    final uid = _currentUserId;
    final folderID = 'fold_${DateTime
        .now()
        .millisecondsSinceEpoch}';
    final newFolder = Folder(
      folderID: folderID,
      name: name,
      userID: uid,
    );

    await FirebaseFirestore.instance
        .collection('folders')
        .doc(folderID)
        .set(newFolder.toMap());
  }

  // Delete a folder and reset any sessions belonging to it to 'Default'
  Future<void> deleteFolder(String folderID, String folderName) async {
    final uid = _currentUserId;

    // Delete folder document
    await FirebaseFirestore.instance
        .collection('folders')
        .doc(folderID)
        .delete();

    // Reset sessions folder value
    final sessionsQuery = await FirebaseFirestore.instance
        .collection('sessions')
        .where('creatorId', isEqualTo: uid)
        .where('folder', isEqualTo: folderName)
        .get();

    for (var doc in sessionsQuery.docs) {
      await doc.reference.update({'folder': 'Default'});
    }
  }

  // Rename a folder and update any sessions belonging to it to the new folder name
  Future<void> renameFolder(String folderID, String oldName,
      String newName) async {
    final uid = _currentUserId;

    // Update folder document name
    await FirebaseFirestore.instance
        .collection('folders')
        .doc(folderID)
        .update({'name': newName});

    // Update sessions folder value
    final sessionsQuery = await FirebaseFirestore.instance
        .collection('sessions')
        .where('creatorId', isEqualTo: uid)
        .where('folder', isEqualTo: oldName)
        .get();

    for (var doc in sessionsQuery.docs) {
      await doc.reference.update({'folder': newName});
    }
  }

  // Update a session's folder location
  Future<void> updateSessionFolder(String sessionID, String folderName) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionID)
        .update({'folder': folderName});
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
