import 'package:flutter/material.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/screens/session_pages.dart';
import 'home_screen.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final favoriteSessions = _sessionService.getFavoriteSessions();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: favoriteSessions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 80,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Favorites Yet',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your favorite sessions will appear here.',
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
                itemCount: favoriteSessions.length,
                itemBuilder: (context, index) {
                  final session = favoriteSessions[index];
                  final isShortcut = _sessionService.isSessionShortcut(
                    session.sessionID,
                  );
                  final isFavorite = _sessionService.isSessionFavorite(
                    session.sessionID,
                  );

                  return SessionCard(
                    session: session,
                    isShortcut: isShortcut,
                    isFavorite: isFavorite,
                    onFavoriteToggle: () {
                      _sessionService.toggleFavorite(session.sessionID);
                    },
                    onTap: () {
                      final page = isShortcut
                          ? ParticipantSessionPage(session: session)
                          : AdministratorSessionPage(session: session);
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => page));
                    },
                    onDelete: () {
                      _sessionService.deleteSession(session.sessionID);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isShortcut
                                ? 'Shortcut removed.'
                                : 'Session moved to Trash.',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
