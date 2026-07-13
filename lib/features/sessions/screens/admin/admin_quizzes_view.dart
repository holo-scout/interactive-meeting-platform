// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/session.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';

class AdminQuizzesView extends StatefulWidget {
  const AdminQuizzesView({super.key, required this.session});

  final Session session;

  @override
  State<AdminQuizzesView> createState() => _AdminQuizzesViewState();
}

class _AdminQuizzesViewState extends State<AdminQuizzesView> {
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

        if (quizzes.isEmpty) {
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
                    'Create and manage interactive quizzes for this session.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click the "+" button in the bar below to create a quiz.',
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
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            final quiz = quizzes[index];

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
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton.outlined(
                          onPressed: () => _confirmDeleteQuiz(quiz),
                          icon: const Icon(Icons.delete_outline),
                          style: IconButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(
                              color: colors.error.withValues(alpha: 0.5),
                            ),
                          ),
                          tooltip: 'Delete Quiz',
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () => _toggleReleaseStatus(quiz),
                          icon: Icon(
                            quiz.isReleased
                                ? Icons.drafts_outlined
                                : Icons.publish_outlined,
                          ),
                          tooltip: quiz.isReleased
                              ? 'Revert to Draft'
                              : 'Release Quiz',
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _QuizSubmissionsView(
                                  session: widget.session,
                                  quiz: quiz,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people_outline),
                          tooltip: 'View Submissions',
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ManageQuizQuestionsPage(
                                  session: widget.session,
                                  quiz: quiz,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_note_outlined),
                          tooltip: 'Manage Questions',
                        ),
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
  }
}

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
            }).toList(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

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
          'correctAnswerText': question.type == 'open_ended' &&
              question.correctAnswers.isNotEmpty
              ? question.correctAnswers.first
              : '',
          'correctImageBase64': question.correctImageBase64,
        });
      }
    } else {
      _addQuestion('multiple_choice');
    }
  }

  void _addQuestion(String type) {
    setState(() {
      _questions.add({
        'questionId':
            'q_${DateTime.now().millisecondsSinceEpoch}_${_questions.length}',
        'type': type,
        'questionText': '',
        'options': type == 'open_ended' ? <String>[] : <String>['', ''],
        'correctOptionIndex': 0,
        'correctOptionIndices': <int>[0],
        'correctAnswerText': '',
        'correctImageBase64': null,
      });
    });
  }

  Future<void> _pickSuggestedAnswerImage(int qIndex) async {
    final colors = Theme
        .of(context)
        .colorScheme;
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
        _questions[qIndex]['correctImageBase64'] = base64String;
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

  void _showAiGenerationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AiGenerationBottomSheet(sessionID: widget.session.sessionID);
      },
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        if (!mounted) return;
        final mcq = result['mcqCount'] as int;
        final chk = result['checkboxCount'] as int;
        final open = result['openEndedCount'] as int;
        final qna = result['relevantToQna'] as bool;
        final prompt = result['prompt'] as String;
        final files = result['files'] as List<PlatformFile>;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI Generation Triggered:\n'
                  'MCQ: $mcq, Checkbox: $chk, Open: $open, Q&A: $qna\n'
                  'Prompt: "$prompt"\n'
                  'PDF Files attached: ${files.map((f) => f.name).join(', ')}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _showAddQuestionBottomSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        Widget buildOptionItem({
          required IconData icon,
          required Color iconBgColor,
          required Color iconColor,
          required String title,
          required String description,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: iconBgColor,
                    radius: 24,
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Choose Question Type',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      buildOptionItem(
                        icon: Icons.radio_button_checked,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        title: 'Multiple Choice',
                        description: 'Single correct option, auto-graded.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('multiple_choice');
                        },
                      ),
                      const Divider(height: 1, indent: 72, color: Colors.white),
                      buildOptionItem(
                        icon: Icons.check_box_outlined,
                        iconBgColor: Colors.purple.shade50,
                        iconColor: Colors.purple.shade700,
                        title: 'Checkbox',
                        description: 'Multiple correct options, auto-graded.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('checkbox');
                        },
                      ),
                      const Divider(height: 1, indent: 72, color: Colors.white),
                      buildOptionItem(
                        icon: Icons.text_fields_outlined,
                        iconBgColor: Colors.orange.shade50,
                        iconColor: Colors.orange.shade700,
                        title: 'Open-Ended',
                        description:
                            'Text response with optional screenshot upload.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('open_ended');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        if (correctIdx == optIndex) {
          _questions[qIndex]['correctOptionIndex'] = 0;
        } else if (correctIdx > optIndex) {
          _questions[qIndex]['correctOptionIndex'] = correctIdx - 1;
        }

        correctIndices.remove(optIndex);
        final updatedIndices = correctIndices.map((idx) {
          return idx > optIndex ? idx - 1 : idx;
        }).toList();
        _questions[qIndex]['correctOptionIndices'] = updatedIndices;
      }
    });
  }

  Widget _buildTypeBadge(String type, ColorScheme colors, TextTheme textTheme) {
    String label = '';
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.black87;

    if (type == 'multiple_choice') {
      label = 'Multiple Choice';
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    } else if (type == 'checkbox') {
      label = 'Checkbox';
      bgColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
    } else if (type == 'open_ended') {
      label = 'Open-Ended';
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 200,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: _showAiGenerationBottomSheet,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: colors.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showAddQuestionBottomSheet,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: colors.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0, top: 8.0, bottom: 8.0),
            child: FilledButton(
              onPressed: _saveQuestions,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Questions (${_questions.length})',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ..._questions.asMap().entries.map((qEntry) {
              final qIndex = qEntry.key;
              final qMap = qEntry.value;
              final qType = qMap['type'] as String;
              final opts = qMap['options'] as List<String>;
              final correctIdx = qMap['correctOptionIndex'] as int;
              final correctIndices = qMap['correctOptionIndices'] as List<int>;

              return Card(
                margin: const EdgeInsets.only(bottom: 24),
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
                          Row(
                            children: [
                              Text(
                                'Question ${qIndex + 1}',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTypeBadge(qType, colors, textTheme),
                            ],
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
                      TextFormField(
                        initialValue: qMap['questionText'] as String,
                        decoration: InputDecoration(
                          labelText: 'Question Text',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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

                      if (qType == 'open_ended') ...[
                        Text(
                          'Suggested Answer',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: qMap['correctAnswerText'] as String? ??
                              '',
                          decoration: InputDecoration(
                            labelText: 'Reference Answer (Optional)',
                            hintText: 'Type suggested correct answer guidelines for students...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          maxLines: 3,
                          onChanged: (val) {
                            qMap['correctAnswerText'] = val.trim();
                          },
                        ),
                        const SizedBox(height: 12),
                        if (qMap['correctImageBase64'] != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'suggested_answer.png',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          qMap['correctImageBase64'] = null;
                                        });
                                      },
                                      child: const Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              child: Image.memory(
                                base64Decode(
                                    qMap['correctImageBase64'] as String),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ] else
                          ...[
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickSuggestedAnswerImage(qIndex),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text(
                                  'Attach Reference Image / Screenshot'),
                            ),
                          ],
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),

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
      } else if (qType == 'open_ended') {
        final answerText = qMap['correctAnswerText'] as String? ?? '';
        correctAnswers = answerText.isNotEmpty ? [answerText] : [];
      }

      parsedQuestions.add(
        QuizQuestion(
          questionId: qId,
          type: qType,
          questionText: qText,
          options: (qType == 'open_ended') ? [] : opts,
          correctAnswers: correctAnswers,
          correctImageBase64: qMap['correctImageBase64'] as String?,
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

class _AiGenerationBottomSheet extends StatefulWidget {
  const _AiGenerationBottomSheet({required this.sessionID});

  final String sessionID;

  @override
  State<_AiGenerationBottomSheet> createState() =>
      _AiGenerationBottomSheetState();
}

class _AiGenerationBottomSheetState extends State<_AiGenerationBottomSheet> {
  int _mcqCount = 0;
  int _checkboxCount = 0;
  int _openEndedCount = 0;
  bool _relevantToQna = false;
  final TextEditingController _promptController = TextEditingController();
  final List<PlatformFile> _uploadedFiles = [];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickPdfFile() async {
    final colors = Theme
        .of(context)
        .colorScheme;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick PDF file: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _removePdfFile(PlatformFile file) {
    setState(() {
      _uploadedFiles.remove(file);
    });
  }

  void _handleSubmit() {
    Navigator.pop(context, {
      'mcqCount': _mcqCount,
      'checkboxCount': _checkboxCount,
      'openEndedCount': _openEndedCount,
      'relevantToQna': _relevantToQna,
      'prompt': _promptController.text.trim(),
      'files': _uploadedFiles,
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;

    Widget buildCounterItem({
      required IconData icon,
      required Color iconBgColor,
      required Color iconColor,
      required String title,
      required int count,
      required VoidCallback onDecrement,
      required VoidCallback onIncrement,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconBgColor,
              radius: 24,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: count > 0 ? onDecrement : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$count',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: onIncrement,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery
                .of(context)
                .viewInsets
                .bottom + 16,
            left: 16,
            right: 16,
            top: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Text(
                  'Number of questions',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 1. First Container: Counters
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    buildCounterItem(
                      icon: Icons.radio_button_checked,
                      iconBgColor: Colors.blue.shade50,
                      iconColor: Colors.blue.shade700,
                      title: 'Multiple Choice',
                      count: _mcqCount,
                      onDecrement: () => setState(() => _mcqCount--),
                      onIncrement: () => setState(() => _mcqCount++),
                    ),
                    const Divider(height: 1, indent: 64, color: Colors.white),
                    buildCounterItem(
                      icon: Icons.check_box_outlined,
                      iconBgColor: Colors.purple.shade50,
                      iconColor: Colors.purple.shade700,
                      title: 'Checkbox',
                      count: _checkboxCount,
                      onDecrement: () => setState(() => _checkboxCount--),
                      onIncrement: () => setState(() => _checkboxCount++),
                    ),
                    const Divider(height: 1, indent: 64, color: Colors.white),
                    buildCounterItem(
                      icon: Icons.text_fields_outlined,
                      iconBgColor: Colors.orange.shade50,
                      iconColor: Colors.orange.shade700,
                      title: 'Open-Ended',
                      count: _openEndedCount,
                      onDecrement: () => setState(() => _openEndedCount--),
                      onIncrement: () => setState(() => _openEndedCount++),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Second Container: Relevant to Q&A Switch Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Relevant to student Q&A',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Generate questions based on student queries from this session',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: _relevantToQna,
                      onChanged: (val) {
                        setState(() {
                          _relevantToQna = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Third Container: Chat input prompt box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Uploaded files list
                    if (_uploadedFiles.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _uploadedFiles.map((file) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => _removePdfFile(file),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Input prompt text field
                    TextField(
                      controller: _promptController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Ask Gemini...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _pickPdfFile,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: colors.onSurface,
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: _handleSubmit,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.shade100,
                            foregroundColor: Colors.blue.shade800,
                            minimumSize: const Size(40, 40),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
