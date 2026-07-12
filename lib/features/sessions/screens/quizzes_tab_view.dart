// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/session.dart';
import '../models/quiz.dart';
import '../services/quiz_service.dart';

class QuizzesTabView extends StatefulWidget {
  const QuizzesTabView({
    super.key,
    required this.session,
    required this.isAdministrator,
  });

  final Session session;
  final bool isAdministrator;

  @override
  State<QuizzesTabView> createState() => _QuizzesTabViewState();
}

class _QuizzesTabViewState extends State<QuizzesTabView> {
  // Confirm Delete Dialog
  void _confirmDeleteQuiz(Quiz quiz) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Delete Quiz'),
          content: const Text(
            'Are you sure you want to delete this quiz and all student submissions? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                try {
                  await QuizService().deleteQuiz(
                    widget.session.sessionID,
                    quiz.quizId,
                  );
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Quiz deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete quiz: $e'),
                      backgroundColor: colors.error,
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Toggle Quiz Release Status
  void _toggleReleaseStatus(Quiz quiz) async {
    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updatedQuiz = quiz.copyWith(isReleased: !quiz.isReleased);
      await QuizService().createOrUpdateQuiz(
        widget.session.sessionID,
        updatedQuiz,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            quiz.isReleased
                ? 'Quiz set to Draft.'
                : 'Quiz released to participants!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to toggle status: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }

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
        final visibleQuizzes = widget.isAdministrator
            ? quizzes
            : quizzes.where((q) => q.isReleased).toList();

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
                    widget.isAdministrator
                        ? 'Create and manage interactive quizzes for this session.'
                        : 'View and complete quizzes shared by the administrator.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isAdministrator
                        ? 'Click the "+" button in the bar below to create a quiz.'
                        : 'No quizzes have been released in this session yet.',
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
                  color: widget.isAdministrator
                      ? Colors.white
                      : colors.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge (For Administrator)
                        if (widget.isAdministrator) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: quiz.isReleased
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              quiz.isReleased ? 'Released' : 'Draft',
                              style: textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: quiz.isReleased
                                    ? colors.onPrimaryContainer
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Quiz Header
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
                        // Action row
                        if (widget.isAdministrator) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _confirmDeleteQuiz(quiz),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: colors.error,
                                    side: BorderSide(
                                      color: colors.error.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _toggleReleaseStatus(quiz),
                                  icon: Icon(
                                    quiz.isReleased
                                        ? Icons.drafts_outlined
                                        : Icons.publish_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    quiz.isReleased
                                        ? 'Revert to Draft'
                                        : 'Release',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            _QuizSubmissionsView(
                                              session: widget.session,
                                              quiz: quiz,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.people_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Submissions'),
                                ),
                                FilledButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ManageQuizQuestionsPage(
                                              session: widget.session,
                                              quiz: quiz,
                                            ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit_note_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Questions'),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (hasTaken) ...[
                                Text(
                                  submission.isGraded
                                      ? 'Score: ${submission.score}/${quiz.questions.length}'
                                      : 'Submitted (Awaiting Grading)',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: submission.isGraded
                                        ? colors.primary
                                        : colors.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                  label: const Text('Take Quiz'),
                                ),
                              ],
                            ],
                          ),
                        ],
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

// ==========================================
// PARTICIPANT QUIZ TAKER PAGE
// ==========================================
class _QuizTakerView extends StatefulWidget {
  const _QuizTakerView({required this.session, required this.quiz});

  final Session session;
  final Quiz quiz;

  @override
  State<_QuizTakerView> createState() => _QuizTakerViewState();
}

class _QuizTakerViewState extends State<_QuizTakerView> {
  final _formKey = GlobalKey<FormState>();

  // Temporary student answers state
  final Map<String, QuizAnswer> _answers = {};

  @override
  void initState() {
    super.initState();
    // Initialize temporary answer states
    for (var question in widget.quiz.questions) {
      _answers[question.questionId] = QuizAnswer(
        selectedOptions: [],
        textResponse: '',
        base64Image: null,
      );
    }
  }

  // Handle image picker, compress, and convert to base64
  Future<void> _pickImage(String questionId) async {
    final colors = Theme.of(context).colorScheme;
    final picker = ImagePicker();

    // Automatically compress to safe presentation sizes (< 100KB)
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
      appBar: AppBar(title: Text('Quiz: ${widget.quiz.title}')),
      body: Form(
        key: _formKey,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: widget.quiz.questions.length + 1,
          itemBuilder: (context, index) {
            // Render submit button at the end
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
                            content: Text('Quiz submitted successfully!'),
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
                      'Submit Quiz Answers',
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question text
                    Text(
                      'Question ${index + 1}: ${question.questionText}',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Render inputs depending on type
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
                      // Image attachment UI
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

// ==========================================
// PARTICIPANT VIEW RESULTS PAGE
// ==========================================
class _QuizResultsView extends StatelessWidget {
  const _QuizResultsView({required this.quiz, required this.submission});

  final Quiz quiz;
  final QuizSubmission submission;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Quiz Results: ${quiz.title}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Score summary card
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

          // Answers breakdown
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
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
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
                            'Question ${idx + 1}: ${question.questionText}',
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

                    // Choice questions feedback
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

// ==========================================
// ADMINISTRATOR SUBMISSIONS LIST PAGE
// ==========================================
class _QuizSubmissionsView extends StatelessWidget {
  const _QuizSubmissionsView({required this.session, required this.quiz});

  final Session session;
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Submissions: ${quiz.title}')),
      body: StreamBuilder<List<QuizSubmission>>(
        stream: QuizService().streamSubmissions(session.sessionID, quiz.quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading submissions: ${snapshot.error}',
                style: TextStyle(color: colors.error),
              ),
            );
          }

          final submissions = snapshot.data ?? [];

          if (submissions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: colors.primary),
                    const SizedBox(height: 16),
                    Text('No Submissions Yet', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'No students have completed this quiz yet.',
                      style: textTheme.bodyMedium?.copyWith(
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
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final sub = submissions[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: Colors.white,
                child: ListTile(
                  title: Text(
                    sub.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    sub.isGraded ? 'Status: Graded' : 'Status: Awaiting Review',
                    style: TextStyle(
                      color: sub.isGraded ? Colors.green : colors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Score: ${sub.score} / ${quiz.questions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _StudentSubmissionGradingView(
                          session: session,
                          quiz: quiz,
                          submission: sub,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// ADMINISTRATOR GRADING PANEL
// ==========================================
class _StudentSubmissionGradingView extends StatefulWidget {
  const _StudentSubmissionGradingView({
    required this.session,
    required this.quiz,
    required this.submission,
  });

  final Session session;
  final Quiz quiz;
  final QuizSubmission submission;

  @override
  State<_StudentSubmissionGradingView> createState() =>
      _StudentSubmissionGradingViewState();
}

class _StudentSubmissionGradingViewState
    extends State<_StudentSubmissionGradingView> {
  final _formKey = GlobalKey<FormState>();
  late int _selectedScore;
  late TextEditingController _feedbackController;

  @override
  void initState() {
    super.initState();
    _selectedScore = widget.submission.score;
    // Cap score at max questions if it exceeds for some reason
    if (_selectedScore > widget.quiz.questions.length) {
      _selectedScore = widget.quiz.questions.length;
    }
    _feedbackController = TextEditingController(
      text: widget.submission.feedback,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Grade: ${widget.submission.username}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Student answers list
            Text(
              'Answers Review',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...widget.quiz.questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final question = entry.value;
              final answer = widget.submission.answers[question.questionId];

              if (answer == null) {
                return const SizedBox();
              }

              bool isCorrect = false;
              if (question.type == 'multiple_choice') {
                isCorrect =
                    question.correctAnswers.isNotEmpty &&
                    answer.selectedOptions.isNotEmpty &&
                    question.correctAnswers.first ==
                        answer.selectedOptions.first;
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
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
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
                              'Question ${idx + 1}: ${question.questionText}',
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
                          'Student selected:',
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
                          'Student response:',
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
                              constraints: const BoxConstraints(maxHeight: 300),
                              width: double.infinity,
                              child: Image.memory(
                                base64Decode(answer.base64Image!),
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
            }).toList(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Grading panel inputs
            Text(
              'Assign Grade & Feedback',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
              ),
              color: colors.primaryContainer.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Score Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Score:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _selectedScore,
                          items: List.generate(
                            widget.quiz.questions.length + 1,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(
                                '$index / ${widget.quiz.questions.length} points',
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedScore = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Feedback Input
                    TextFormField(
                      controller: _feedbackController,
                      decoration: const InputDecoration(
                        labelText: 'Lecturer Feedback',
                        hintText: 'Add notes or corrections for the student...',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 300,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await QuizService().gradeSubmission(
                      widget.session.sessionID,
                      widget.quiz.quizId,
                      widget.submission.userId,
                      _selectedScore,
                      _feedbackController.text.trim(),
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Grade saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    navigator.pop();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to save grade: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Submit Grade & Feedback',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ADMINISTRATOR CREATE/EDIT QUIZ PAGE
// ==========================================
class ManageQuizQuestionsPage extends StatefulWidget {
  const ManageQuizQuestionsPage({
    super.key,
    required this.session,
    required this.quiz,
  });

  final Session session;
  final Quiz quiz;

  @override
  State<ManageQuizQuestionsPage> createState() =>
      _ManageQuizQuestionsPageState();
}

class _ManageQuizQuestionsPageState extends State<ManageQuizQuestionsPage> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    if (widget.quiz.questions.isNotEmpty) {
      for (var question in widget.quiz.questions) {
        int correctIdx = 0;
        List<int> correctIndices = [];

        if (question.type == 'multiple_choice' &&
            question.correctAnswers.isNotEmpty) {
          correctIdx = question.options.indexOf(question.correctAnswers.first);
          if (correctIdx == -1) correctIdx = 0;
        } else if (question.type == 'checkbox') {
          for (var correctAns in question.correctAnswers) {
            final idx = question.options.indexOf(correctAns);
            if (idx != -1) {
              correctIndices.add(idx);
            }
          }
        }

        _questions.add({
          'questionId': question.questionId,
          'type': question.type,
          'questionText': question.questionText,
          'options': List<String>.from(
            question.options.isNotEmpty ? question.options : ['', ''],
          ),
          'correctOptionIndex': correctIdx,
          'correctOptionIndices': correctIndices,
        });
      }
    } else {
      _addQuestion();
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add({
        'questionId':
            'q_${DateTime.now().millisecondsSinceEpoch}_${_questions.length}',
        'type': 'multiple_choice',
        'questionText': '',
        'options': ['', ''], // Starts with 2 option fields
        'correctOptionIndex': 0, // MCQ correct option index
        'correctOptionIndices': <int>[0], // Checkbox correct indices
      });
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _addOption(int qIndex) {
    setState(() {
      final opts = _questions[qIndex]['options'] as List<String>;
      if (opts.length < 10) {
        opts.add('');
      }
    });
  }

  void _removeOption(int qIndex, int optIndex) {
    setState(() {
      final opts = _questions[qIndex]['options'] as List<String>;
      final correctIndices =
          _questions[qIndex]['correctOptionIndices'] as List<int>;
      final correctIdx = _questions[qIndex]['correctOptionIndex'] as int;

      if (opts.length > 2) {
        opts.removeAt(optIndex);
        // Correct single MCQ index
        if (correctIdx == optIndex) {
          _questions[qIndex]['correctOptionIndex'] = 0;
        } else if (correctIdx > optIndex) {
          _questions[qIndex]['correctOptionIndex'] = correctIdx - 1;
        }

        // Correct Checkbox indices
        correctIndices.remove(optIndex);
        final updatedIndices = correctIndices.map((idx) {
          return idx > optIndex ? idx - 1 : idx;
        }).toList();
        _questions[qIndex]['correctOptionIndices'] = updatedIndices;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Questions: ${widget.quiz.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save Questions',
            onPressed: _saveQuestions,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions (${_questions.length})',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addQuestion,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Render each question card
            ..._questions.asMap().entries.map((qEntry) {
              final qIndex = qEntry.key;
              final qMap = qEntry.value;
              final qType = qMap['type'] as String;
              final opts = qMap['options'] as List<String>;
              final correctIdx = qMap['correctOptionIndex'] as int;
              final correctIndices = qMap['correctOptionIndices'] as List<int>;

              return Card(
                margin: const EdgeInsets.only(bottom: 24),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${qIndex + 1}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_questions.length > 1)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: colors.error,
                              ),
                              onPressed: () => _removeQuestion(qIndex),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Question text
                      TextFormField(
                        initialValue: qMap['questionText'] as String,
                        decoration: const InputDecoration(
                          labelText: 'Question Text',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter question text';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          qMap['questionText'] = val.trim();
                        },
                      ),
                      const SizedBox(height: 16),
                      // Question type dropdown
                      DropdownButtonFormField<String>(
                        value: qType,
                        decoration: const InputDecoration(
                          labelText: 'Question Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'multiple_choice',
                            child: Text('Multiple Choice (Single Select)'),
                          ),
                          DropdownMenuItem(
                            value: 'checkbox',
                            child: Text('Checkbox (Multi-Select)'),
                          ),
                          DropdownMenuItem(
                            value: 'open_ended',
                            child: Text('Open-Ended (with optional image)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              qMap['type'] = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // MCQ / Checkbox options rendering
                      if (qType == 'multiple_choice' ||
                          qType == 'checkbox') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Options',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Mark correct answers',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...opts.asMap().entries.map((optEntry) {
                          final optIndex = optEntry.key;
                          final optText = optEntry.value;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                // Selection indicator
                                if (qType == 'multiple_choice')
                                  Radio<int>(
                                    value: optIndex,
                                    groupValue: correctIdx,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          qMap['correctOptionIndex'] = val;
                                        });
                                      }
                                    },
                                  )
                                else
                                  Checkbox(
                                    value: correctIndices.contains(optIndex),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          correctIndices.add(optIndex);
                                        } else {
                                          correctIndices.remove(optIndex);
                                        }
                                      });
                                    },
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: optText,
                                    decoration: InputDecoration(
                                      labelText: 'Option ${optIndex + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      opts[optIndex] = val.trim();
                                    },
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter option text';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (opts.length > 2) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: colors.error,
                                    ),
                                    onPressed: () =>
                                        _removeOption(qIndex, optIndex),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        if (opts.length < 10) ...[
                          TextButton.icon(
                            onPressed: () => _addOption(qIndex),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saveQuestions,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save Questions', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _saveQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final List<QuizQuestion> parsedQuestions = [];

    for (var qMap in _questions) {
      final qType = qMap['type'] as String;
      final qText = qMap['questionText'] as String;
      final qId = qMap['questionId'] as String;
      final opts = qMap['options'] as List<String>;
      final correctIdx = qMap['correctOptionIndex'] as int;
      final correctIndices = qMap['correctOptionIndices'] as List<int>;

      List<String> correctAnswers = [];
      if (qType == 'multiple_choice') {
        if (correctIdx >= opts.length) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Please select a valid correct option for Multiple Choice.',
              ),
              backgroundColor: colors.error,
            ),
          );
          return;
        }
        correctAnswers = [opts[correctIdx]];
      } else if (qType == 'checkbox') {
        if (correctIndices.isEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Please select at least one correct option for each Checkbox question.',
              ),
              backgroundColor: colors.error,
            ),
          );
          return;
        }
        correctAnswers = correctIndices.map((idx) => opts[idx]).toList();
      }

      parsedQuestions.add(
        QuizQuestion(
          questionId: qId,
          type: qType,
          questionText: qText,
          options: (qType == 'open_ended') ? [] : opts,
          correctAnswers: (qType == 'open_ended') ? [] : correctAnswers,
        ),
      );
    }

    final updatedQuiz = widget.quiz.copyWith(questions: parsedQuestions);

    try {
      await QuizService().createOrUpdateQuiz(
        widget.session.sessionID,
        updatedQuiz,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Quiz questions saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save questions: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }
}
