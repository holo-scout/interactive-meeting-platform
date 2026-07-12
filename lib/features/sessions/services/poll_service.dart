import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/poll.dart';

class PollService {
  // Singleton pattern
  static final PollService _instance = PollService._internal();

  factory PollService() => _instance;

  PollService._internal();

  // Helper to get current user ID
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

  // Stream polls in real-time
  Stream<List<Poll>> streamPolls(String sessionId) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Poll.fromMap(doc.data())).toList();
        });
  }

  // Create a new poll
  Future<void> createPoll(
    String sessionId,
    String question,
    List<String> optionTexts,
  ) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('polls')
        .doc();

    final rand = Random();
    final List<PollOption>
    options = optionTexts.where((text) => text.trim().isNotEmpty).map((text) {
      final optionId =
          'opt_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(10000)}';
      return PollOption(optionId: optionId, text: text.trim(), voterIds: []);
    }).toList();

    if (options.length < 2) {
      throw Exception('A poll must have at least 2 options.');
    }

    final newPoll = Poll(
      pollId: docRef.id,
      question: cleanQuestion,
      options: options,
      createdAt: DateTime.now(),
    );

    await docRef.set(newPoll.toMap());
  }

  // Update a poll (change question text, rename, add, delete or reorder options)
  Future<void> updatePoll(
    String sessionId,
    String pollId,
    String question,
    List<PollOption> options,
  ) async {
    final cleanQuestion = question.trim();
    if (cleanQuestion.isEmpty) return;

    if (options.length < 2) {
      throw Exception('A poll must have at least 2 options.');
    }

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('polls')
        .doc(pollId)
        .update({
          'question': cleanQuestion,
          'options': options.map((o) => o.toMap()).toList(),
        });
  }

  // Delete a poll
  Future<void> deletePoll(String sessionId, String pollId) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('polls')
        .doc(pollId)
        .delete();
  }

  // Toggle user vote for a specific option inside a poll
  Future<void> toggleVote(
    String sessionId,
    String pollId,
    String optionId,
  ) async {
    final userId = _currentUserId;
    final docRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('polls')
        .doc(pollId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final poll = Poll.fromMap(snapshot.data()!);

      final updatedOptions = poll.options.map((option) {
        if (option.optionId == optionId) {
          final voterIds = List<String>.from(option.voterIds);
          if (voterIds.contains(userId)) {
            voterIds.remove(userId);
          } else {
            voterIds.add(userId);
          }
          return option.copyWith(voterIds: voterIds);
        }
        return option;
      }).toList();

      transaction.update(docRef, {
        'options': updatedOptions.map((o) => o.toMap()).toList(),
      });
    });
  }
}
