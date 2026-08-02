import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
  final String questionId;
  final String type; // 'multiple_choice', 'checkbox', 'open_ended'
  final String questionText;
  final List<String> options; // empty for open_ended
  final List<String> correctAnswers; // empty for open_ended
  final String? correctImageBase64; // open-ended correct image reference

  QuizQuestion({
    required this.questionId,
    required this.type,
    required this.questionText,
    required this.options,
    required this.correctAnswers,
    this.correctImageBase64,
  });

  QuizQuestion copyWith({
    String? questionId,
    String? type,
    String? questionText,
    List<String>? options,
    List<String>? correctAnswers,
    String? correctImageBase64,
  }) {
    return QuizQuestion(
      questionId: questionId ?? this.questionId,
      type: type ?? this.type,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      correctImageBase64: correctImageBase64 ?? this.correctImageBase64,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'type': type,
      'questionText': questionText,
      'options': options,
      'correctAnswers': correctAnswers,
      'correctImageBase64': correctImageBase64,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      questionId: map['questionId'] ?? '',
      type: map['type'] ?? 'multiple_choice',
      questionText: map['questionText'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctAnswers: List<String>.from(map['correctAnswers'] ?? []),
      correctImageBase64: map['correctImageBase64'],
    );
  }
}

class Quiz {
  final String quizId;
  final String title;
  final String description;
  final List<QuizQuestion> questions;
  final bool isReleased;
  final DateTime createdAt;

  Quiz({
    required this.quizId,
    required this.title,
    required this.description,
    required this.questions,
    required this.isReleased,
    required this.createdAt,
  });

  Quiz copyWith({
    String? quizId,
    String? title,
    String? description,
    List<QuizQuestion>? questions,
    bool? isReleased,
    DateTime? createdAt,
  }) {
    return Quiz(
      quizId: quizId ?? this.quizId,
      title: title ?? this.title,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      isReleased: isReleased ?? this.isReleased,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quizId': quizId,
      'title': title,
      'description': description,
      'questions': questions.map((q) => q.toMap()).toList(),
      'isReleased': isReleased,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Quiz.fromMap(Map<String, dynamic> map) {
    final createdAtData = map['createdAt'];
    final DateTime createdAtDate = createdAtData is Timestamp
        ? createdAtData.toDate()
        : DateTime.now();

    final questionsList = List<Map<String, dynamic>>.from(
      map['questions'] ?? [],
    ).map((q) => QuizQuestion.fromMap(q)).toList();

    return Quiz(
      quizId: map['quizId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      questions: questionsList,
      isReleased: map['isReleased'] ?? false,
      createdAt: createdAtDate,
    );
  }
}

class QuizAnswer {
  final List<String> selectedOptions; // for MC and Checkbox
  final String? textResponse; // for open-ended text
  final String? base64Image; // for open-ended optional image
  final bool? isCorrect; // for open-ended manual grading
  final String? teacherFeedback; // for per-question lecturer feedback

  QuizAnswer({
    required this.selectedOptions,
    this.textResponse,
    this.base64Image,
    this.isCorrect,
    this.teacherFeedback,
  });

  QuizAnswer copyWith({
    List<String>? selectedOptions,
    String? textResponse,
    String? base64Image,
    bool? isCorrect,
    String? teacherFeedback,
  }) {
    return QuizAnswer(
      selectedOptions: selectedOptions ?? this.selectedOptions,
      textResponse: textResponse ?? this.textResponse,
      base64Image: base64Image ?? this.base64Image,
      isCorrect: isCorrect ?? this.isCorrect,
      teacherFeedback: teacherFeedback ?? this.teacherFeedback,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedOptions': selectedOptions,
      'textResponse': textResponse,
      'base64Image': base64Image,
      'isCorrect': isCorrect,
      'teacherFeedback': teacherFeedback,
    };
  }

  factory QuizAnswer.fromMap(Map<String, dynamic> map) {
    return QuizAnswer(
      selectedOptions: List<String>.from(map['selectedOptions'] ?? []),
      textResponse: map['textResponse'],
      base64Image: map['base64Image'],
      isCorrect: map['isCorrect'] as bool?,
      teacherFeedback: map['teacherFeedback'] as String?,
    );
  }
}

class QuizSubmission {
  final String userId;
  final String username;
  final Map<String, QuizAnswer> answers; // key is questionId
  final int score;
  final DateTime submittedAt;
  final bool isGraded;
  final String feedback;

  QuizSubmission({
    required this.userId,
    required this.username,
    required this.answers,
    required this.score,
    required this.submittedAt,
    required this.isGraded,
    required this.feedback,
  });

  QuizSubmission copyWith({
    String? userId,
    String? username,
    Map<String, QuizAnswer>? answers,
    int? score,
    DateTime? submittedAt,
    bool? isGraded,
    String? feedback,
  }) {
    return QuizSubmission(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      submittedAt: submittedAt ?? this.submittedAt,
      isGraded: isGraded ?? this.isGraded,
      feedback: feedback ?? this.feedback,
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, Map<String, dynamic>> answersMap = {};
    answers.forEach((key, value) {
      answersMap[key] = value.toMap();
    });

    return {
      'userId': userId,
      'username': username,
      'answers': answersMap,
      'score': score,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'isGraded': isGraded,
      'feedback': feedback,
    };
  }

  factory QuizSubmission.fromMap(Map<String, dynamic> map) {
    final submittedAtData = map['submittedAt'];
    final DateTime submittedAtDate = submittedAtData is Timestamp
        ? submittedAtData.toDate()
        : DateTime.now();

    final Map<String, dynamic> rawAnswers = map['answers'] ?? {};
    final Map<String, QuizAnswer> parsedAnswers = {};
    rawAnswers.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedAnswers[key] = QuizAnswer.fromMap(value);
      }
    });

    return QuizSubmission(
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      answers: parsedAnswers,
      score: map['score'] ?? 0,
      submittedAt: submittedAtDate,
      isGraded: map['isGraded'] ?? false,
      feedback: map['feedback'] ?? '',
    );
  }
}
