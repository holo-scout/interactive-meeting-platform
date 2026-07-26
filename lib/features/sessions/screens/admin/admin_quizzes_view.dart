// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads
import 'package:flutter/material.dart';
import '../../models/session.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import 'quiz/quiz_questions_view.dart';
import 'quiz/quiz_submissions_view.dart';

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
          title: const Text('Delete quiz'),
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
                      content: Text('quiz deleted successfully.'),
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
                ? 'quiz set to Draft.'
                : 'quiz released to participants!',
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
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (quiz.isReleased) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You can only edit a draft quiz.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
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
                        '${quiz.questions.length} Question${quiz.questions
                            .length == 1 ? "" : "s"}',
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
                            tooltip: 'Delete quiz',
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
                                : 'Release quiz',
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QuizSubmissionsView(
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
                          IconButton.outlined(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                useSafeArea: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  )),
                                builder: (context) {
                                  return _EditQuizBottomSheet(
                                    sessionID: widget.session.sessionID,
                                    quiz: quiz,
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.edit_outlined),,
                            tooltip: 'Edit quiz Details',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      });
  }
}

class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final int maxLength;

  const _EditFieldDialog({
    required this.title,
    required this.initialValue,
    required this.maxLength,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          counterText: '${_controller.text.length}/${widget.maxLength}',
        ),
        onChanged: (text) {
          setState(() {});
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _controller.text.trim());
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _EditQuizBottomSheet extends StatefulWidget {
  final String sessionID;
  final Quiz quiz;

  const _EditQuizBottomSheet({
    required this.sessionID,
    required this.quiz,
  });

  @override
  State<_EditQuizBottomSheet> createState() => _EditQuizBottomSheetState();
}

class _EditQuizBottomSheetState extends State<_EditQuizBottomSheet> {
  late String _title;
  late String _subtitle;

  @override
  void initState() {
    super.initState();
    _title = widget.quiz.title;
    _subtitle = widget.quiz.description;
  }

  Widget _buildConfigTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colors,
    required TextTheme textTheme,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(width: 16),
            Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value.isEmpty ? 'None' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;
    final bottomPadding = MediaQuery
        .of(context)
        .padding
        .bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery
            .of(context)
            .viewInsets
            .bottom +
            (bottomPadding > 0 ? bottomPadding : 16.0),
        left: 16,
        right: 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Group 1: Title, Subtitle
          Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildConfigTile(
                  icon: Icons.bookmark_outline_rounded,
                  label: 'Title',
                  value: _title,
                  colors: colors,
                  textTheme: textTheme,
                  onTap: () async {
                    final val = await showDialog<String>(
                      context: context,
                      builder: (context) =>
                          _EditFieldDialog(
                            title: 'Edit Title',
                            initialValue: _title,
                            maxLength: 20,
                          ),
                    );
                    if (val != null) {
                      setState(() {
                        _title = val;
                      });
                    }
                  },
                ),
                const Divider(height: 8, thickness: 2, color: Colors.white),
                _buildConfigTile(
                  icon: Icons.notes_rounded,
                  label: 'Subtitle',
                  value: _subtitle,
                  colors: colors,
                  textTheme: textTheme,
                  onTap: () async {
                    final val = await showDialog<String>(
                      context: context,
                      builder: (context) =>
                          _EditFieldDialog(
                            title: 'Edit Subtitle',
                            initialValue: _subtitle,
                            maxLength: 50,
                          ),
                    );
                    if (val != null) {
                      setState(() {
                        _subtitle = val;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Action Row (Cancel / Save)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final titleTrimmed = _title.trim();
                  if (titleTrimmed.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a quiz title'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final updatedQuiz = widget.quiz.copyWith(
                    title: titleTrimmed,
                    description: _subtitle.trim(),
                  );

                  try {
                    await QuizService().createOrUpdateQuiz(
                      widget.sessionID,
                      updatedQuiz,
                    );
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('quiz details updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to update quiz: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
