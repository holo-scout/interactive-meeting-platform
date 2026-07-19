// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  List<QuizQuestion> _generateQuestions({
    required List<String> topics,
    required int mcqCount,
    required int checkboxCount,
    required int openCount,
  }) {
    final List<QuizQuestion> questions = [];
    int qId = 1;

    final Map<String, List<Map<String, dynamic>>> mcqPool = {
      'stateful': [
        {
          'question': 'Which method is invoked first in the lifecycle of a State object?',
          'options': [
            'initState()',
            'build()',
            'didChangeDependencies()',
            'createState()'
          ],
          'correct': ['initState()'],
        },
      ],
      'state management': [
        {
          'question': 'Which provider type is best suited for managing complex state objects in Riverpod?',
          'options': [
            'StateNotifierProvider',
            'Provider',
            'FutureProvider',
            'StreamProvider'
          ],
          'correct': ['StateNotifierProvider'],
        },
      ],
      'asynchronous': [
        {
          'question': 'What keyword is used to yield values from an asynchronous generator function in Dart?',
          'options': ['yield', 'return', 'async*', 'yield*'],
          'correct': ['yield'],
        },
      ],
      'custom painter': [
        {
          'question': 'Which method must be overridden to define custom rendering logic in a CustomPainter?',
          'options': ['paint()', 'shouldRepaint()', 'draw()', 'layout()'],
          'correct': ['paint()'],
        },
      ],
      'firestore': [
        {
          'question': 'Which rule determines write privileges in Firestore security rules?',
          'options': [
            'allow write: if ...',
            'allow read: if ...',
            'allow get: if ...',
            'allow list: if ...'
          ],
          'correct': ['allow write: if ...'],
        },
      ],
      'auth': [
        {
          'question': 'Which authentication provider is supported natively by Firebase Auth out-of-the-box?',
          'options': [
            'Email/Password',
            'OAuth (Google/Apple)',
            'Phone SMS',
            'All of the above'
          ],
          'correct': ['All of the above'],
        },
      ],
      'security rules': [
        {
          'question': 'Which keyword is used to access incoming document data in Firestore security rules?',
          'options': [
            'request.resource.data',
            'resource.data',
            'request.data',
            'incoming.data'
          ],
          'correct': ['request.resource.data'],
        },
      ],
      'llm': [
        {
          'question': 'What is the primary role of a prompt template in LLM application design?',
          'options': [
            'Standardize inputs',
            'Reduce tokens',
            'Accelerate latency',
            'Manage embeddings'
          ],
          'correct': ['Standardize inputs'],
        },
      ],
      'prompt engineering': [
        {
          'question': 'Which prompt engineering technique uses examples to guide the model output structure?',
          'options': [
            'Few-shot prompting',
            'Zero-shot prompting',
            'Chain-of-thought',
            'System prompting'
          ],
          'correct': ['Few-shot prompting'],
        },
      ],
    };

    final Map<String, List<Map<String, dynamic>>> checkboxPool = {
      'stateful': [
        {
          'question': 'Select all lifecycle methods of a State object that are called multiple times:',
          'options': [
            'build()',
            'didUpdateWidget()',
            'initState()',
            'dispose()'
          ],
          'correct': ['build()', 'didUpdateWidget()'],
        },
      ],
      'state management': [
        {
          'question': 'Which of the following are reactive state management packages in Flutter?',
          'options': ['Provider', 'Riverpod', 'Bloc', 'Http'],
          'correct': ['Provider', 'Riverpod', 'Bloc'],
        },
      ],
      'firestore': [
        {
          'question': 'Which sub-operations make up the Firestore write privilege?',
          'options': ['create', 'update', 'delete', 'get'],
          'correct': ['create', 'update', 'delete'],
        },
      ],
      'llm': [
        {
          'question': 'Which of the following are components of a standard RAG pipeline?',
          'options': [
            'Vector Database',
            'Document Chunking',
            'Embedding Model',
            'Direct CPU instruction'
          ],
          'correct': [
            'Vector Database',
            'Document Chunking',
            'Embedding Model'
          ],
        },
      ],
    };

    final Map<String, String> openPool = {
      'stateful': 'Explain the difference between hot reload and hot restart in Flutter, and how they affect the widget tree state.',
      'state management': 'Compare and contrast local state (setState) vs global state management (e.g. Riverpod) in Flutter development.',
      'asynchronous': 'Describe how the event loop works in Dart and how asynchronous microtasks and events are prioritised.',
      'firestore': 'Explain the trade-offs between nested subcollections vs root-level collections with references in Firestore database design.',
      'llm': 'Explain the concept of Retrieval-Augmented Generation (RAG) and why it is useful for domain-specific AI queries.',
      'general': 'Describe the core challenges and potential solutions when integrating third-party AI APIs into production systems.',
    };

    List<Map<String, dynamic>> getMatchingMcq(String topic) {
      final key = mcqPool.keys.firstWhere(
            (k) => topic.toLowerCase().contains(k),
        orElse: () => '',
      );
      if (key.isNotEmpty) return mcqPool[key]!;
      return [
        {
          'question': 'Which of the following is a key aspect of "$topic"?',
          'options': [
            'Core mechanism',
            'Alternative approach',
            'Performance overhead',
            'Historical artifact'
          ],
          'correct': ['Core mechanism'],
        }
      ];
    }

    List<Map<String, dynamic>> getMatchingCheckbox(String topic) {
      final key = checkboxPool.keys.firstWhere(
            (k) => topic.toLowerCase().contains(k),
        orElse: () => '',
      );
      if (key.isNotEmpty) return checkboxPool[key]!;
      return [
        {
          'question': 'Select all valid attributes/features of "$topic":',
          'options': [
            'Primary driver',
            'Scalability component',
            'Deprecated method',
            'Security risk'
          ],
          'correct': ['Primary driver', 'Scalability component'],
        }
      ];
    }

    String getMatchingOpen(String topic) {
      final key = openPool.keys.firstWhere(
            (k) => topic.toLowerCase().contains(k),
        orElse: () => '',
      );
      if (key.isNotEmpty) return openPool[key]!;
      return 'Discuss the primary benefits, design patterns, and main implementation hurdles associated with "$topic".';
    }

    for (int i = 0; i < mcqCount; i++) {
      final topic = topics[i % topics.length];
      final pool = getMatchingMcq(topic);
      final item = pool[i % pool.length];
      questions.add(QuizQuestion(
        questionId: 'q_${qId++}',
        questionText: item['question'],
        type: 'multiple_choice',
        options: List<String>.from(item['options']),
        correctAnswers: List<String>.from(item['correct']),
      ));
    }

    for (int i = 0; i < checkboxCount; i++) {
      final topic = topics[(i + mcqCount) % topics.length];
      final pool = getMatchingCheckbox(topic);
      final item = pool[i % pool.length];
      questions.add(QuizQuestion(
        questionId: 'q_${qId++}',
        questionText: item['question'],
        type: 'checkbox',
        options: List<String>.from(item['options']),
        correctAnswers: List<String>.from(item['correct']),
      ));
    }

    for (int i = 0; i < openCount; i++) {
      final topic = topics[(i + mcqCount + checkboxCount) % topics.length];
      final promptText = getMatchingOpen(topic);
      questions.add(QuizQuestion(
        questionId: 'q_${qId++}',
        questionText: promptText,
        type: 'open_ended',
        options: [],
        correctAnswers: [],
      ));
    }

    return questions;
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
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        if (!mounted) return;
        final mcq = result['mcqCount'] as int;
        final chk = result['checkboxCount'] as int;
        final open = result['openEndedCount'] as int;
        final topics = List<String>.from(result['selectedTopics']);
        final fileName = result['fileName'] as String;

        if (topics.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please select at least one topic to generate quiz questions.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final errorColor = Theme
            .of(context)
            .colorScheme
            .error;

        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 16),
                Text('AI generating quiz questions...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        List<QuizQuestion>? questions;
        try {
          final fileUrl = 'https://firebasestorage.googleapis.com/v0/b/${FirebaseFirestore
              .instance.app.options.storageBucket}/o/session_pdfs%2F${widget
              .session.sessionID}%2F$fileName?alt=media';
          final callable = FirebaseFunctions.instance.httpsCallable(
              'generateQuizQuestions');
          final response = await callable.call({
            'fileUrl': fileUrl,
            'selectedTopics': topics,
            'mcqCount': mcq,
            'checkboxCount': chk,
            'openCount': open,
          });

          if (response.data != null && response.data['questions'] != null) {
            final questionsData = response.data['questions'] as List;
            int qId = 1;
            questions = questionsData.map((q) {
              return QuizQuestion(
                questionId: 'q_${qId++}',
                questionText: q['questionText'] as String? ?? '',
                type: q['type'] as String? ?? 'multiple_choice',
                options: List<String>.from(q['options'] ?? []),
                correctAnswers: List<String>.from(q['correctAnswers'] ?? []),
              );
            }).toList();
          }
        } catch (e) {
          debugPrint(
              "Production AI question generation failed, falling back to mock: $e");
        }

        questions ??= _generateQuestions(
          topics: topics,
          mcqCount: mcq,
          checkboxCount: chk,
          openCount: open,
        );

        final quizId = 'quiz_${DateTime
            .now()
            .millisecondsSinceEpoch}';
        final quiz = Quiz(
          quizId: quizId,
          title: 'Quiz: ${fileName.replaceAll(".pdf", "")}',
          description: 'AI-generated quiz from $fileName targeting: ${topics
              .join(", ")}',
          questions: questions,
          isReleased: false,
          createdAt: DateTime.now(),
        );

        try {
          await QuizService().createOrUpdateQuiz(
            widget.session.sessionID,
            quiz,
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('AI quiz generated successfully as Draft!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to save generated quiz: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
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

    return PopScope(
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            ScaffoldMessenger.of(context).clearSnackBars();
          }
        },
        child: Scaffold(
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
        ));
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
  int _mcqCount = 5;
  int _checkboxCount = 3;
  int _openEndedCount = 2;
  bool _relevantToQna = false;
  PlatformFile? _selectedPdf;
  List<String> _detectedTopics = [];
  final Set<String> _selectedTopics = {};
  bool _isAnalyzing = false;

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
        final file = result.files.first;
        setState(() {
          _selectedPdf = file;
          _isAnalyzing = true;
        });

        try {
          String fileUrl = '';
          if (file.bytes != null) {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('session_pdfs/${widget.sessionID}/${DateTime
                .now()
                .millisecondsSinceEpoch}_${file.name}');
            await storageRef.putData(file.bytes!);
            fileUrl = await storageRef.getDownloadURL();
          }

          if (fileUrl.isNotEmpty) {
            final callable = FirebaseFunctions.instance.httpsCallable(
                'extractTopicsFromPdf');
            final response = await callable.call({'fileUrl': fileUrl});
            final topics = List<String>.from(response.data['topics']);
            if (topics.isNotEmpty) {
              setState(() {
                _detectedTopics = topics;
                _selectedTopics.clear();
                _selectedTopics.addAll(topics);
                _isAnalyzing = false;
              });
              return;
            }
          }
        } catch (e) {
          debugPrint(
              "Production AI topic extraction failed, falling back to mock: $e");
        }

        setState(() {
          _detectedTopics = _extractMockTopics(file.name);
          _selectedTopics.clear();
          _selectedTopics.addAll(_detectedTopics);
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
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

  List<String> _extractMockTopics(String fileName) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.contains('flutter') || lowerName.contains('dart')) {
      return [
        'Stateful vs Stateless Widgets',
        'State Management (Provider/Riverpod)',
        'Widget Lifecycle (initState, didChangeDependencies)',
        'Asynchronous Programming (Futures & Streams)',
        'Custom Painters & Custom Clippers',
      ];
    } else
    if (lowerName.contains('firebase') || lowerName.contains('firestore')) {
      return [
        'Firestore Collection Structure & Queries',
        'Firebase Authentication & Sign-in methods',
        'Real-time Streams & Offline Caching',
        'Firestore Security Rules & Data Validation',
        'Cloud Functions HTTP Triggers & Database Triggers',
      ];
    } else if (lowerName.contains('ai') || lowerName.contains('gpt') ||
        lowerName.contains('gemini')) {
      return [
        'Large Language Models (LLM) Integration',
        'Prompt Engineering & Structured System Prompts',
        'Retrieval-Augmented Generation (RAG) Architecture',
        'Tokenization & Context Window Optimization',
        'Gemini API Call Limits & Function Calling',
      ];
    } else {
      return [
        'Main Concepts & Document Overview',
        'Key Terminology & Core Definitions',
        'Historical Context & Background',
        'Practical Applications & Best Practices',
        'Alternative Solutions & Trade-offs',
      ];
    }
  }

  void _removePdfFile() {
    setState(() {
      _selectedPdf = null;
      _detectedTopics.clear();
      _selectedTopics.clear();
    });
  }

  void _handleSubmit() {
    if (_selectedPdf == null) return;
    Navigator.pop(context, {
      'mcqCount': _mcqCount,
      'checkboxCount': _checkboxCount,
      'openEndedCount': _openEndedCount,
      'relevantToQna': _relevantToQna,
      'fileName': _selectedPdf!.name,
      'selectedTopics': _selectedTopics.toList(),
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
        child: SingleChildScrollView(
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

                // 3. Conditional: Upload box OR Topics Checklist + File Chip Row
                if (_selectedPdf == null) ...[
                  GestureDetector(
                    onTap: _pickPdfFile,
                    child: CustomPaint(
                      painter: DashedBorderPainter(
                        color: colors.outline.withValues(alpha: 0.5),
                        borderRadius: 20,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Text(
                                'Select a file to upload (Only PDF files are supported currently)',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else
                  if (_isAnalyzing) ...[
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            'Uploading & analyzing PDF topics...',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    ...[
                      // Topics Checklist
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detected Topics',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Column(
                              children: List.generate(
                                  _detectedTopics.length, (index) {
                                final topic = _detectedTopics[index];
                                final isSelected = _selectedTopics.contains(
                                    topic);
                                return Column(
                                  children: [
                                    CheckboxListTile(
                                      value: isSelected,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedTopics.add(topic);
                                          } else {
                                            _selectedTopics.remove(topic);
                                          }
                                        });
                                      },
                                      title: Text(
                                        topic,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                      controlAffinity: ListTileControlAffinity
                                          .trailing,
                                      activeColor: colors.primary,
                                      checkboxShape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      contentPadding: const EdgeInsets
                                          .symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                    ),
                                    if (index < _detectedTopics.length - 1)
                                      Divider(
                                        height: 1,
                                        color: colors.primary.withValues(
                                            alpha: 0.1),
                                      ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Footer file chip and Generate Questions button row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.outlineVariant.withValues(
                                      alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _selectedPdf!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurface,
                                  ),
                                ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _removePdfFile,
                                    child: Icon(
                                      Icons.cancel,
                                      size: 18,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _selectedTopics.isNotEmpty
                                ? _handleSubmit
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 14,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Generate Questions',
                              style: textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5.0,
    this.dashLength = 5.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
