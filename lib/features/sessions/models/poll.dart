import 'package:cloud_firestore/cloud_firestore.dart';

class PollOption {
  final String optionId;
  final String text;
  final List<String> voterIds;

  PollOption({
    required this.optionId,
    required this.text,
    required this.voterIds,
  });

  PollOption copyWith({
    String? optionId,
    String? text,
    List<String>? voterIds,
  }) {
    return PollOption(
      optionId: optionId ?? this.optionId,
      text: text ?? this.text,
      voterIds: voterIds ?? this.voterIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {'optionId': optionId, 'text': text, 'voterIds': voterIds};
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      optionId: map['optionId'] ?? '',
      text: map['text'] ?? '',
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }
}

class Poll {
  final String pollId;
  final String question;
  final List<PollOption> options;
  final DateTime createdAt;

  Poll({
    required this.pollId,
    required this.question,
    required this.options,
    required this.createdAt,
  });

  Poll copyWith({
    String? pollId,
    String? question,
    List<PollOption>? options,
    DateTime? createdAt,
  }) {
    return Poll(
      pollId: pollId ?? this.pollId,
      question: question ?? this.question,
      options: options ?? this.options,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'question': question,
      'options': options.map((o) => o.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    final createdAtData = map['createdAt'];
    final DateTime createdAtDate = createdAtData is Timestamp
        ? createdAtData.toDate()
        : DateTime.now();

    final optionsList = List<Map<String, dynamic>>.from(
      map['options'] ?? [],
    ).map((o) => PollOption.fromMap(o)).toList();

    return Poll(
      pollId: map['pollId'] ?? '',
      question: map['question'] ?? '',
      options: optionsList,
      createdAt: createdAtDate,
    );
  }
}
