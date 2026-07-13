import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import '../models/session.dart';
import '../models/question.dart';
import '../models/quiz.dart';
import '../services/qna_service.dart';
import '../services/poll_service.dart';
import '../services/quiz_service.dart';
import 'admin/admin_qna_view.dart';
import 'admin/admin_polls_view.dart';
import 'admin/admin_quizzes_view.dart';
import 'participant/participant_qna_view.dart';
import 'participant/participant_polls_view.dart';
import 'participant/participant_quizzes_view.dart';

class AdministratorSessionPage extends StatelessWidget {
  const AdministratorSessionPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return _SessionPageTemplate(
      session: session,
      isAdministrator: true,
      tabDescriptions: const [
        'Review and manage questions from participants.',
        'Create and manage live polls for this session.',
        'Create quizzes and review participant results.',
      ],
    );
  }
}

class ParticipantSessionPage extends StatelessWidget {
  const ParticipantSessionPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return _SessionPageTemplate(
      session: session,
      isAdministrator: false,
      tabDescriptions: const [
        'Ask questions and browse the session discussion.',
        'View and answer polls shared by the administrator.',
        'Take quizzes made available in this session.',
      ],
    );
  }
}

class _SessionPageTemplate extends StatefulWidget {
  const _SessionPageTemplate({
    required this.session,
    required this.isAdministrator,
    required this.tabDescriptions,
  });

  final Session session;
  final bool isAdministrator;
  final List<String> tabDescriptions;

  @override
  State<_SessionPageTemplate> createState() => _SessionPageTemplateState();
}

class _SessionPageTemplateState extends State<_SessionPageTemplate> {
  int _index = 0;

  void _showAskQuestionDialog() {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme
            .of(context)
            .colorScheme;
        final textTheme = Theme
            .of(context)
            .textTheme;

        return AlertDialog(
          title: Text('Ask a Question', style: textTheme.titleLarge),
          content: SizedBox(
            width: 450,
            height: 180,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: textController,
                autofocus: true,
                maxLength: 500,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Your Question',
                  hintText: 'Type your question for the lecturer here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value
                      .trim()
                      .isEmpty) {
                    return 'Please enter your question';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await QnaService().addQuestion(
                      widget.session.sessionID,
                      textController.text.trim(),
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Question submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit question: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showAnswerDialog(Question question, {String? existingAnswer}) {
    final textController = TextEditingController(text: existingAnswer);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme
            .of(context)
            .colorScheme;
        final textTheme = Theme
            .of(context)
            .textTheme;

        return AlertDialog(
          title: Text(
              existingAnswer != null ? 'Edit Answer' : 'Answer Question',
              style: textTheme.titleLarge),
          content: SizedBox(
            width: 450,
            height: 180,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: textController,
                autofocus: true,
                maxLength: 500,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Your Answer',
                  hintText: 'Type your answer here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value
                      .trim()
                      .isEmpty) {
                    return 'Please enter an answer';
                  }
                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await QnaService().submitAnswer(
                      widget.session.sessionID,
                      question.questionId,
                      textController.text.trim(),
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(existingAnswer != null
                            ? 'Answer updated successfully!'
                            : 'Answer submitted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to save answer: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteQuestion(Question question) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme
            .of(context)
            .colorScheme;

        return AlertDialog(
          title: const Text('Delete Question'),
          content: const Text(
              'Are you sure you want to delete this question? This action cannot be undone.'),
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
                  await QnaService().deleteQuestion(
                    widget.session.sessionID,
                    question.questionId,
                  );
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Question deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete question: $e'),
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

  void _showCreatePollDialog() {
    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme
            .of(context)
            .colorScheme;
        final textTheme = Theme
            .of(context)
            .textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Create New Poll', style: textTheme.titleLarge),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 450,
                  maxHeight: MediaQuery
                      .of(context)
                      .size
                      .height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: questionController,
                          decoration: const InputDecoration(
                            labelText: 'Poll Question',
                            hintText: 'e.g. Which programming language do you prefer?',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value
                                .trim()
                                .isEmpty) {
                              return 'Please enter a question';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ...optionControllers
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final controller = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    decoration: InputDecoration(
                                      labelText: 'Option ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value
                                          .trim()
                                          .isEmpty) {
                                        return 'Please enter an option';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                if (optionControllers.length > 2) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: colors.error),
                                    onPressed: () {
                                      setDialogState(() {
                                        optionControllers.removeAt(index);
                                      });
                                    },
                                  ),
                                ]
                              ],
                            ),
                          );
                        }),
                        if (optionControllers.length < 10) ...[
                          TextButton.icon(
                            onPressed: () {
                              setDialogState(() {
                                optionControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      try {
                        final optionTexts = optionControllers.map((c) =>
                            c.text.trim()).toList();
                        await PollService().createPoll(
                          widget.session.sessionID,
                          questionController.text.trim(),
                          optionTexts,
                        );
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Poll created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to create poll: $e'),
                            backgroundColor: colors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateQuizDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme
            .of(context)
            .colorScheme;
        final textTheme = Theme
            .of(context)
            .textTheme;

        return AlertDialog(
          title: Text('Create New Quiz', style: textTheme.titleLarge),
          content: SizedBox(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Quiz Title',
                      hintText: 'e.g. Midterm Quiz',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value
                          .trim()
                          .isEmpty) {
                        return 'Please enter a quiz title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'e.g. Test understanding of chapters 1-3...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    final quizId = 'quiz_${DateTime
                        .now()
                        .millisecondsSinceEpoch}';
                    final newQuiz = Quiz(
                      quizId: quizId,
                      title: titleController.text.trim(),
                      description: descriptionController.text.trim(),
                      questions: [],
                      isReleased: false,
                      createdAt: DateTime.now(),
                    );
                    await QuizService().createOrUpdateQuiz(
                      widget.session.sessionID,
                      newQuiz,
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Quiz created successfully! Click "Questions" to add questions.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to create quiz: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showAdd =
        (widget.isAdministrator && (_index == 1 || _index == 2)) ||
        (!widget.isAdministrator && _index == 0);
    final showSubmit = !widget.isAdministrator && _index == 2;
    final actionIcon = showAdd
        ? Icons.add
        : showSubmit
        ? Icons.send_rounded
        : null;
    final actionTooltip = showAdd ? 'Add' : 'Submit quiz';
    final tabPages = widget.isAdministrator
        ? [
      AdminQnaView(
        session: widget.session,
        onAnswerPressed: _showAnswerDialog,
        onDeletePressed: _confirmDeleteQuestion,
      ),
      AdminPollsView(
        session: widget.session,
      ),
      AdminQuizzesView(
        session: widget.session,
      ),
    ]
        : [
      ParticipantQnaView(
        session: widget.session,
      ),
      ParticipantPollsView(
        session: widget.session,
      ),
      ParticipantQuizzesView(
        session: widget.session,
      ),
    ];

    return BottomBar(
      layout: BottomBarLayout(
        width: actionIcon == null ? 220 : 280,
        borderRadius: BorderRadius.circular(50),
      ),
      theme: BottomBarThemeData(
        barDecoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
      motion: const BottomBarMotion.cupertino(
        preset: BottomBarCupertinoMotion.bouncy,
        extraBounce: 0.02,
        transition: BottomBarTransition.slide,
      ),
      scrollBehavior: const BottomBarScrollBehavior(hideOnScroll: true),
      showIcon: false,
      body: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
          [
            SliverAppBar(
              title: Text(widget.session.title),
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
          ],
          body: IndexedStack(index: _index, children: tabPages),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavigationIcon(
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum,
              index: 0,
              tooltip: 'Q&A',
            ),
            _buildNavigationIcon(
              icon: Icons.poll_outlined,
              selectedIcon: Icons.poll,
              index: 1,
              tooltip: 'Polls',
            ),
            _buildNavigationIcon(
              icon: Icons.quiz_outlined,
              selectedIcon: Icons.quiz,
              index: 2,
              tooltip: 'Quizzes',
            ),
            if (actionIcon != null) ...[
              SizedBox(
                height: 28,
                child: VerticalDivider(color: colors.outlineVariant),
              ),
              _buildActionIcon(
                icon: actionIcon,
                tooltip: actionTooltip,
                onPressed: () {
                  if (!widget.isAdministrator && _index == 0) {
                    _showAskQuestionDialog();
                  } else if (widget.isAdministrator && _index == 1) {
                    _showCreatePollDialog();
                  } else if (widget.isAdministrator && _index == 2) {
                    _showCreateQuizDialog();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              '$actionTooltip action is coming soon.')),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationIcon({
    required IconData icon,
    required IconData selectedIcon,
    required int index,
    required String tooltip,
  }) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final isSelected = _index == index;

    return IconButton(
      tooltip: tooltip,
      onPressed: () => setState(() => _index = index),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colors.secondaryContainer : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? colors.onSecondaryContainer : colors
              .onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colors = Theme
        .of(context)
        .colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}


