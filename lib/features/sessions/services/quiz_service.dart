import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/quiz.dart';

class QuizService {
  // Singleton pattern
  static final QuizService _instance = QuizService._internal();

  factory QuizService() => _instance;

  QuizService._internal();

  // Helper to get current user ID
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

  // Helper to get current username
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

  // Stream quizzes in real-time
  Stream<List<Quiz>> streamQuizzes(String sessionId) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Quiz.fromMap(doc.data())).toList();
        });
  }

  // Stream submissions for a specific quiz (for admins)
  Stream<List<QuizSubmission>> streamSubmissions(
    String sessionId,
    String quizId,
  ) {
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => QuizSubmission.fromMap(doc.data()))
              .toList();
        });
  }

  // Stream a single user's submission for a quiz (for participants and views)
  Stream<QuizSubmission?> streamUserSubmission(
    String sessionId,
    String quizId,
  ) {
    final userId = _currentUserId;
    return FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return QuizSubmission.fromMap(doc.data()!);
          }
          return null;
        });
  }

  // Create or Update a quiz
  Future<void> createOrUpdateQuiz(String sessionId, Quiz quiz) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quiz.quizId)
        .set(quiz.toMap());
  }

  // Delete a quiz
  Future<void> deleteQuiz(String sessionId, String quizId) async {
    // Delete submissions subcollection first
    final submissionsQuery = await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .get();

    for (var doc in submissionsQuery.docs) {
      await doc.reference.delete();
    }

    // Delete the quiz
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .delete();
  }

  // Submit quiz answers (handles automatic grading for MC/Checkbox)
  Future<void> submitQuiz(
    String sessionId,
    String quizId,
    Quiz quiz,
    Map<String, QuizAnswer> answers,
  ) async {
    final userId = _currentUserId;
    final username = _currentUsername;
    int calculatedScore = 0;

    for (var question in quiz.questions) {
      final answer = answers[question.questionId];
      if (answer == null) continue;

      if (question.type == 'multiple_choice') {
        if (question.correctAnswers.isNotEmpty &&
            answer.selectedOptions.isNotEmpty &&
            question.correctAnswers.first == answer.selectedOptions.first) {
          calculatedScore += 1;
        }
      } else if (question.type == 'checkbox') {
        final correctSet = question.correctAnswers.toSet();
        final selectedSet = answer.selectedOptions.toSet();
        if (correctSet.isNotEmpty &&
            correctSet.length == selectedSet.length &&
            correctSet.difference(selectedSet).isEmpty) {
          calculatedScore += 1;
        }
      }
      // Open-ended questions earn 0 auto-graded points. Points will be manually graded (max 1 point).
    }

    final newSubmission = QuizSubmission(
      userId: userId,
      username: username,
      answers: answers,
      score: calculatedScore,
      submittedAt: DateTime.now(),
      isGraded: false,
      feedback: '',
    );

    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .doc(userId)
        .set(newSubmission.toMap());
  }

  // Grade open-ended response manually (Lecturer action)
  Future<void> gradeSubmission(
    String sessionId,
    String quizId,
    String studentId,
    int score,
    String feedback,
  ) async {
    await FirebaseFirestore.instance
        .collection('sessions')
        .doc(sessionId)
        .collection('quizzes')
        .doc(quizId)
        .collection('submissions')
        .doc(studentId)
        .update({
          'score': score,
          'isGraded': true,
          'feedback': feedback.trim(),
        });
  }
}
