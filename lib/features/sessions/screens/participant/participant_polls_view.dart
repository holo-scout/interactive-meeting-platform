import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/session.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';

class ParticipantPollsView extends StatefulWidget {
  const ParticipantPollsView({super.key, required this.session});

  final Session session;

  @override
  State<ParticipantPollsView> createState() => _ParticipantPollsViewState();
}

class _ParticipantPollsViewState extends State<ParticipantPollsView> {
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
                    'View and answer polls shared by the administrator.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No polls have been launched in this session yet.',
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
                            onTap: () => PollService().toggleVote(
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
