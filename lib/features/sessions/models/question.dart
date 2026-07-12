import 'package:cloud_firestore/cloud_firestore.dart';

class Question {
  final String questionId;
  final String userId;
  final String username;
  final String content;
  final DateTime timestamp;
  final List<String> upvotes;
  final List<String> downvotes;
  final String? answer;
  final DateTime? answeredAt;

  Question({
    required this.questionId,
    required this.userId,
    required this.username,
    required this.content,
    required this.timestamp,
    required this.upvotes,
    required this.downvotes,
    this.answer,
    this.answeredAt,
  });

  // Calculate the score dynamically
  int get score => upvotes.length - downvotes.length;

  Question copyWith({
    String? questionId,
    String? userId,
    String? username,
    String? content,
    DateTime? timestamp,
    List<String>? upvotes,
    List<String>? downvotes,
    String? answer,
    DateTime? answeredAt,
  }) {
    return Question(
      questionId: questionId ?? this.questionId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      answer: answer ?? this.answer,
      answeredAt: answeredAt ?? this.answeredAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'questionId': questionId,
      'userId': userId,
      'username': username,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'upvotes': upvotes,
      'downvotes': downvotes,
      'answer': answer,
      'answeredAt': answeredAt != null ? Timestamp.fromDate(answeredAt!) : null,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    final timestampData = map['timestamp'];
    final DateTime timestampDate = timestampData is Timestamp
        ? timestampData.toDate()
        : DateTime.now();

    final answeredAtData = map['answeredAt'];
    final DateTime? answeredAtDate = answeredAtData is Timestamp
        ? answeredAtData.toDate()
        : null;

    final upvotesList = List<String>.from(map['upvotes'] ?? []);
    final downvotesList = List<String>.from(map['downvotes'] ?? []);

    return Question(
      questionId: map['questionId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      content: map['content'] ?? '',
      timestamp: timestampDate,
      upvotes: upvotesList,
      downvotes: downvotesList,
      answer: map['answer'],
      answeredAt: answeredAtDate,
    );
  }
}
