import 'package:flutter/material.dart';
import '../../sessions/models/session.dart';
import '../../sessions/services/session_service.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final _sessionService = SessionService();

  @override
  void initState() {
    super.initState();
    _sessionService.addListener(_updateState);
  }

  @override
  void dispose() {
    _sessionService.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Permanently?', style: textTheme.titleLarge),
        content: Text(
          'This will permanently delete the session "${session.title}". This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _sessionService.permanentlyDeleteSession(session.sessionID);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted "${session.title}"'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trashedSessions = _sessionService.getTrashedSessions();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: trashedSessions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 80,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Trash is Empty',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sessions you delete will appear here for recovery.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                itemCount: trashedSessions.length,
                itemBuilder: (context, index) {
                  final session = trashedSessions[index];
                  final isExpired = session.isExpired;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.title,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colors.onSurface,
                                        decoration: TextDecoration.lineThrough,
                                        decorationColor: colors.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    if (session.subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        session.subtitle,
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isExpired
                                      ? colors.error.withValues(alpha: 0.1)
                                      : colors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isExpired ? 'Expired' : 'Active',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isExpired
                                        ? colors.error
                                        : colors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _sessionService.restoreSession(
                                    session.sessionID,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Restored "${session.title}"',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.restore_rounded,
                                  size: 18,
                                ),
                                label: const Text('Restore'),
                                style: OutlinedButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () =>
                                    _confirmDelete(context, session),
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  size: 18,
                                ),
                                label: const Text('Delete Forever'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.error,
                                  foregroundColor: colors.onError,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
