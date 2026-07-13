import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session.dart';
import '../../models/question.dart';
import '../../services/qna_service.dart';

class ParticipantQnaView extends StatefulWidget {
  const ParticipantQnaView({super.key, required this.session});

  final Session session;

  @override
  State<ParticipantQnaView> createState() => _ParticipantQnaViewState();
}

class _ParticipantQnaViewState extends State<ParticipantQnaView> {
  String _sortBy = 'votes'; // 'votes' or 'recent'

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Question>>(
      stream: QnaService().streamQuestions(widget.session.sessionID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading questions: ${snapshot.error}',
              style: TextStyle(color: colors.error),
            ),
          );
        }

        final questions = snapshot.data ?? [];

        if (questions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 56, color: colors.primary),
                  const SizedBox(height: 16),
                  Text('Q&A', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    'Ask questions and browse the session discussion.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Click the "+" button in the bar below to ask a question.',
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

        // Sort the list
        if (_sortBy == 'votes') {
          questions.sort((a, b) {
            final scoreComparison = b.score.compareTo(a.score);
            if (scoreComparison != 0) return scoreComparison;
            return b.timestamp.compareTo(a.timestamp);
          });
        } else {
          questions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '${questions.length} Question${questions.length == 1 ? "" : "s"}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  ChoiceChip(
                    label: const Text('Top'),
                    selected: _sortBy == 'votes',
                    onSelected: (selected) {
                      if (selected) setState(() => _sortBy = 'votes');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Recent'),
                    selected: _sortBy == 'recent',
                    onSelected: (selected) {
                      if (selected) setState(() => _sortBy = 'recent');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  final hasUpvoted = question.upvotes.contains(currentUserId);
                  final hasDownvoted = question.downvotes.contains(
                    currentUserId,
                  );
                  final hasAnswer =
                      question.answer != null && question.answer!.isNotEmpty;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: colors.primaryContainer,
                                child: Text(
                                  question.username.isNotEmpty
                                      ? question.username[0].toUpperCase()
                                      : 'A',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      question.username,
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _formatTimestamp(question.timestamp),
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasAnswer) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Answered',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            question.content,
                            style: textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_upward_rounded,
                                        size: 20,
                                        color: hasUpvoted
                                            ? Colors.green
                                            : colors.onSurfaceVariant,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        QnaService().toggleVote(
                                          widget.session.sessionID,
                                          question.questionId,
                                          true,
                                        );
                                      },
                                    ),
                                    Text(
                                      '${question.score}',
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: question.score > 0
                                            ? Colors.green
                                            : (question.score < 0
                                                  ? Colors.red
                                                  : colors.onSurfaceVariant),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_downward_rounded,
                                        size: 20,
                                        color: hasDownvoted
                                            ? Colors.red
                                            : colors.onSurfaceVariant,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        QnaService().toggleVote(
                                          widget.session.sessionID,
                                          question.questionId,
                                          false,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasAnswer) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.secondaryContainer.withValues(
                                  alpha: 0.2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colors.secondaryContainer.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.school_outlined,
                                        size: 16,
                                        color: colors.onSecondaryContainer,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Lecturer\'s Answer',
                                        style: textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colors.onSecondaryContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    question.answer!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
