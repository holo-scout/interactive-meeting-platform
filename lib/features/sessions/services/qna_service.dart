import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question.dart';

class QnaService {
  // Singleton pattern
  static final QnaService _instance = QnaService._internal();

  factory QnaService() => _instance;

  QnaService._internal();

  // Helper to get current user ID
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

  // Helper to get current user's display name
  String get _currentUsername {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Anonymous';
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.split('@')[0];
    }
    return 'Anonymous';
  }

  // Stream questions in real-time
  Stream<List<Question>> streamQuestions(String sessionId) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('questions')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Question.fromMap(doc.data()))
              .toList();
        });
  }

  // Add a new question to a session
  Future<void> addQuestion(String sessionId, String content) async {
    final String cleanContent = content.trim();
    if (cleanContent.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('questions')
        .doc();

    final newQuestion = Question(
      questionId: docRef.id,
      userId: _currentUserId,
      username: _currentUsername,
      content: cleanContent,
      timestamp: DateTime.now(),
      upvotes: [],
      downvotes: [],
    );

    await docRef.set(newQuestion.toMap());
  }

  // Delete a question from a session
  Future<void> deleteQuestion(String sessionId, String questionId) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('questions')
        .doc(questionId)
        .delete();
  }

  // Answer a question (lecturer action)
  Future<void> submitAnswer(
    String sessionId,
    String questionId,
    String answer,
  ) async {
    final cleanAnswer = answer.trim();

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('questions')
        .doc(questionId)
        .update({
          'answer': cleanAnswer.isEmpty ? null : cleanAnswer,
          'answeredAt': cleanAnswer.isEmpty ? null : Timestamp.now(),
        });
  }

  // Toggle upvote or downvote for a question
  Future<void> toggleVote(
    String sessionId,
    String questionId,
    bool isUpvote,
  ) async {
    final userId = _currentUserId;
    final docRef = FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('questions')
        .doc(questionId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final upvotes = List<String>.from(data['upvotes'] ?? []);
      final downvotes = List<String>.from(data['downvotes'] ?? []);

      if (isUpvote) {
        if (upvotes.contains(userId)) {
          // Already upvoted -> remove vote
          upvotes.remove(userId);
        } else {
          // Add upvote, remove downvote if exists
          upvotes.add(userId);
          downvotes.remove(userId);
        }
      } else {
        if (downvotes.contains(userId)) {
          // Already downvoted -> remove vote
          downvotes.remove(userId);
        } else {
          // Add downvote, remove upvote if exists
          downvotes.add(userId);
          upvotes.remove(userId);
        }
      }

      transaction.update(docRef, {'upvotes': upvotes, 'downvotes': downvotes});
    });
  }
}
