// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/session.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';

class ParticipantQuizzesView extends StatefulWidget {
  const ParticipantQuizzesView({super.key, required this.session});

  final Session session;

  @override
  State<ParticipantQuizzesView> createState() => _ParticipantQuizzesViewState();
}

class _ParticipantQuizzesViewState extends State<ParticipantQuizzesView> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<Quiz>>(
      stream: QuizService().streamQuizzes(widget.session.sessionID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading quizzes: ${snapshot.error}',
              style: TextStyle(color: colors.error),
            ),
          );
        }

        final quizzes = snapshot.data ?? [];

        // For participants, filter out unreleased drafts
        final visibleQuizzes = quizzes.where((q) => q.isReleased).toList();

        if (visibleQuizzes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 56, color: colors.primary),
                  const SizedBox(height: 16),
                  Text('Quizzes', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'View and complete quizzes shared by the administrator.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No quizzes have been released in this session yet.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visibleQuizzes.length,
          itemBuilder: (context, index) {
            final quiz = visibleQuizzes[index];

            return StreamBuilder<QuizSubmission?>(
              stream: QuizService().streamUserSubmission(
                widget.session.sessionID,
                quiz.quizId,
              ),
              builder: (context, submissionSnapshot) {
                final submission = submissionSnapshot.data;
                final bool hasTaken = submission != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  color: colors.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: hasTaken
                                    ? colors.primaryContainer
                                    : colors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasTaken ? 'Submitted' : 'Not Submitted',
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: hasTaken
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (hasTaken) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: submission.isGraded
                                      ? colors.tertiaryContainer
                                      : colors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  submission.isGraded ? 'Graded' : 'Pending',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: submission.isGraded
                                        ? colors.onTertiaryContainer
                                        : colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          quiz.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        if (quiz.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            quiz.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${quiz.questions.length} Question${quiz.questions.length == 1 ? "" : "s"}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (hasTaken) ...[
                              if (submission.isGraded) ...[
                                Text(
                                  'Score: ${submission.score}/${quiz.questions.length}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => _QuizResultsView(
                                        quiz: quiz,
                                        submission: submission,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 18,
                                ),
                                label: const Text('View Results'),
                              ),
                            ] else ...[
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => _QuizTakerView(
                                        session: widget.session,
                                        quiz: quiz,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.play_arrow_outlined,
                                  size: 18,
                                ),
                                label: const Text('Take quiz'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _QuizTakerView extends StatefulWidget {
  const _QuizTakerView({required this.session, required this.quiz});

  final Session session;
  final Quiz quiz;

  @override
  State<_QuizTakerView> createState() => _QuizTakerViewState();
}

class _QuizTakerViewState extends State<_QuizTakerView> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, QuizAnswer> _answers = {};

  @override
  void initState() {
    super.initState();
    for (var question in widget.quiz.questions) {
      _answers[question.questionId] = QuizAnswer(
        selectedOptions: [],
        textResponse: '',
        base64Image: null,
      );
    }
  }

  Future<void> _pickImage(String questionId) async {
    final colors = Theme.of(context).colorScheme;
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        final current = _answers[questionId]!;
        _answers[questionId] = current.copyWith(base64Image: base64String);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _removeImage(String questionId) {
    setState(() {
      final current = _answers[questionId]!;
      _answers[questionId] = current.copyWith(base64Image: null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('quiz: ${widget.quiz.title}'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: colors.onSurface,
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: widget.quiz.questions.length + 1,
          itemBuilder: (context, index) {
            if (index == widget.quiz.questions.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 40),
                child: FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        await QuizService().submitQuiz(
                          widget.session.sessionID,
                          widget.quiz.quizId,
                          widget.quiz,
                          _answers,
                        );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('quiz submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        navigator.pop();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit quiz: $e'),
                            backgroundColor: colors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      'Submit quiz Answers',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            }

            final question = widget.quiz.questions[index];
            final answer = _answers[question.questionId]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ${question.questionText}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (question.type == 'multiple_choice') ...[
                      Column(
                        children: question.options.map((option) {
                          return RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: answer.selectedOptions.isNotEmpty
                                ? answer.selectedOptions.first
                                : null,
                            onChanged: (val) {
                              setState(() {
                                _answers[question.questionId] = answer.copyWith(
                                  selectedOptions: val != null ? [val] : [],
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ] else if (question.type == 'checkbox') ...[
                      Column(
                        children: question.options.map((option) {
                          final selected = answer.selectedOptions.contains(
                            option,
                          );
                          return CheckboxListTile(
                            title: Text(option),
                            value: selected,
                            onChanged: (val) {
                              setState(() {
                                final selectedList = List<String>.from(
                                  answer.selectedOptions,
                                );
                                if (val == true) {
                                  selectedList.add(option);
                                } else {
                                  selectedList.remove(option);
                                }
                                _answers[question.questionId] = answer.copyWith(
                                  selectedOptions: selectedList,
                                );
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        }).toList(),
                      ),
                    ] else if (question.type == 'open_ended') ...[
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Your Answer',
                          hintText: 'Type your response here...',
                          border: OutlineInputBorder(),
                        ),
                        maxLength: 500,
                        maxLines: 5,
                        onChanged: (val) {
                          _answers[question.questionId] = answer.copyWith(
                            textResponse: val.trim(),
                          );
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a response';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (answer.base64Image != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                width: double.infinity,
                                child: Image.memory(
                                  base64Decode(answer.base64Image!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.6,
                                ),
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _removeImage(question.questionId),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () => _pickImage(question.questionId),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Attach Screenshot / Image'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuizResultsView extends StatelessWidget {
  const _QuizResultsView({required this.quiz, required this.submission});

  final Quiz quiz;
  final QuizSubmission submission;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('quiz Results: ${quiz.title}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            color: colors.primaryContainer.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    submission.isGraded ? 'Final Score' : 'Auto-Graded Score',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${submission.score} / ${quiz.questions.length}',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    submission.isGraded
                        ? 'This quiz has been graded by the lecturer.'
                        : 'Awaiting lecturer review for open-ended questions.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (submission.feedback.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      'Lecturer Feedback:',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      submission.feedback,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Questions Review',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...quiz.questions.asMap().entries.map((entry) {
            final idx = entry.key;
            final question = entry.value;
            final answer = submission.answers[question.questionId];

            if (answer == null) {
              return const SizedBox();
            }

            bool isCorrect = false;
            if (question.type == 'multiple_choice') {
              isCorrect =
                  question.correctAnswers.isNotEmpty &&
                  answer.selectedOptions.isNotEmpty &&
                  question.correctAnswers.first == answer.selectedOptions.first;
            } else if (question.type == 'checkbox') {
              final correctSet = question.correctAnswers.toSet();
              final selectedSet = answer.selectedOptions.toSet();
              isCorrect =
                  correctSet.isNotEmpty &&
                  correctSet.length == selectedSet.length &&
                  correctSet.difference(selectedSet).isEmpty;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 20),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${idx + 1}. ${question.questionText}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (question.type != 'open_ended')
                          Icon(
                            isCorrect
                                ? Icons.check_circle_outline
                                : Icons.cancel_outlined,
                            color: isCorrect ? Colors.green : Colors.red,
                          ),
                      ],
                    ),
                    const Divider(height: 24),

                    if (question.type == 'multiple_choice' ||
                        question.type == 'checkbox') ...[
                      Text(
                        'Your selection:',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...answer.selectedOptions.map(
                        (opt) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '- $opt',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Correct answer:',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      ...question.correctAnswers.map(
                        (opt) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '- $opt',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else if (question.type == 'open_ended') ...[
                      Text(
                        'Your response:',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        answer.textResponse ?? '',
                        style: textTheme.bodyLarge,
                      ),
                      if (answer.base64Image != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            width: double.infinity,
                            child: Image.memory(
                              base64Decode(answer.base64Image!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      if (question.correctAnswers.isNotEmpty &&
                          question.correctAnswers.first.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Suggested Correct Answer Reference:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.correctAnswers.first,
                          style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                      if (question.correctImageBase64 != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            width: double.infinity,
                            child: Image.memory(
                              base64Decode(question.correctImageBase64!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
