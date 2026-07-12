import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/session.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';

class PollsTabView extends StatefulWidget {
  const PollsTabView({
    super.key,
    required this.session,
    required this.isAdministrator,
  });

  final Session session;
  final bool isAdministrator;

  @override
  State<PollsTabView> createState() => _PollsTabViewState();
}

class _PollsTabViewState extends State<PollsTabView> {
  // Confirmation delete dialog
  void _confirmDeletePoll(Poll poll) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;

        return AlertDialog(
          title: const Text('Delete Poll'),
          content: const Text(
            'Are you sure you want to delete this poll? This action cannot be undone.',
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
                  await PollService().deletePoll(
                    widget.session.sessionID,
                    poll.pollId,
                  );
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Poll deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete poll: $e'),
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

  // Edit dialog with reorderable list of options
  void _showEditPollDialog(Poll poll) {
    final questionController = TextEditingController(text: poll.question);
    final List<PollOption> tempOptions = List.from(poll.options);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Poll', style: textTheme.titleLarge),
              content: SizedBox(
                width: 450,
                height: 450,
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
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a question';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Options (${tempOptions.length})',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Drag to reorder',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ReorderableListView.builder(
                          itemCount: tempOptions.length,
                          // ignore: deprecated_member_use
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = tempOptions.removeAt(oldIndex);
                              tempOptions.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final option = tempOptions[index];
                            return Padding(
                              key: ValueKey(option.optionId),
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  // Drag handle (ReorderableListView builder supplies standard gesture,
                                  // we add a visual drag icon)
                                  Icon(
                                    Icons.drag_indicator,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: option.text,
                                      decoration: InputDecoration(
                                        labelText: 'Option ${index + 1}',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        tempOptions[index] = option.copyWith(
                                          text: val.trim(),
                                        );
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  if (tempOptions.length > 2) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: colors.error,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          tempOptions.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      if (tempOptions.length < 10) ...[
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              final newId =
                                  'opt_new_${DateTime.now().millisecondsSinceEpoch}';
                              tempOptions.add(
                                PollOption(
                                  optionId: newId,
                                  text: '',
                                  voterIds: [],
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Option'),
                        ),
                      ],
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
                        await PollService().updatePoll(
                          widget.session.sessionID,
                          poll.pollId,
                          questionController.text.trim(),
                          tempOptions,
                        );
                        navigator.pop();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Poll updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Failed to update poll: $e'),
                            backgroundColor: colors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<Poll>>(
      stream: PollService().streamPolls(widget.session.sessionID),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading polls: ${snapshot.error}',
              style: TextStyle(color: colors.error),
            ),
          );
        }

        final polls = snapshot.data ?? [];

        if (polls.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.poll_outlined, size: 56, color: colors.primary),
                  const SizedBox(height: 16),
                  Text('Polls', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    widget.isAdministrator
                        ? 'Create and manage live polls for this session.'
                        : 'View and answer polls shared by the administrator.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isAdministrator
                        ? 'Click the "+" button in the bar below to create a poll.'
                        : 'No polls have been launched in this session yet.',
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
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final poll = polls[index];

            // Calculate total unique votes
            final totalUniqueVoters = poll.options
                .expand((o) => o.voterIds)
                .toSet()
                .length;

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
                    // Question
                    Text(
                      poll.question,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalUniqueVoters participant${totalUniqueVoters == 1 ? "" : "s"} voted',
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Options
                    Column(
                      children: poll.options.map((option) {
                        final hasVoted = option.voterIds.contains(
                          currentUserId,
                        );
                        final voteCount = option.voterIds.length;
                        final percent = totalUniqueVoters > 0
                            ? voteCount / totalUniqueVoters
                            : 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: hasVoted
                                  ? colors.primary
                                  : colors.outlineVariant.withValues(
                                      alpha: 0.4,
                                    ),
                              width: hasVoted ? 2 : 1,
                            ),
                          ),
                          color: hasVoted
                              ? colors.primaryContainer.withValues(alpha: 0.1)
                              : colors.surfaceContainerLowest,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: widget.isAdministrator
                                ? null // Admins cannot vote
                                : () => PollService().toggleVote(
                                    widget.session.sessionID,
                                    poll.pollId,
                                    option.optionId,
                                  ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          option.text,
                                          style: textTheme.bodyLarge?.copyWith(
                                            fontWeight: hasVoted
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$voteCount vote${voteCount == 1 ? "" : "s"} (${(percent * 100).toStringAsFixed(0)}%)',
                                        style: textTheme.bodySmall?.copyWith(
                                          fontWeight: hasVoted
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: hasVoted
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: percent,
                                      minHeight: 6,
                                      backgroundColor: colors.surfaceContainer,
                                      color: hasVoted
                                          ? colors.primary
                                          : colors.primary.withValues(
                                              alpha: 0.5,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Action Buttons for Administrator
                    if (widget.isAdministrator) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _confirmDeletePoll(poll),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              side: BorderSide(
                                color: colors.error.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showEditPollDialog(poll),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.onPrimary,
                            ),
                          ),
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
  }
}
