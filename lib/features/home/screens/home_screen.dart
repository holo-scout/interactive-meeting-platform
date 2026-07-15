import 'package:flutter/material.dart';
import '../../authentication/services/auth_service.dart';
import '../../sessions/models/session.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/screens/session_pages.dart';
import 'package:fab_menu_expressive/fab_menu_expressive.dart';
import 'package:flutter/services.dart';
import 'favorites_page.dart';
import 'trash_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _sessionService = SessionService();
  String _selectedFilter = 'All'; // 'All', 'Created', 'Shortcuts'
  bool _isFabExpanded = false;
  int _currentIndex = 0;

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


  void _showCreateSessionDialog() {
    final titleController = TextEditingController();
    final subtitleController = TextEditingController();
    Duration selectedDuration = const Duration(hours: 1);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Create New Session', style: textTheme.titleLarge),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Session Title',
                          hintText: 'e.g. CS101 Web Development Lecture',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: subtitleController,
                        decoration: const InputDecoration(
                          labelText: 'Subtitle (Optional)',
                          hintText: 'e.g. Q&A, Quiz and Live Polls',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Duration>(
                        initialValue: selectedDuration,
                        decoration: const InputDecoration(
                          labelText: 'Expiry Duration',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: Duration(minutes: 30),
                            child: Text('30 Minutes'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 1),
                            child: Text('1 Hour'),
                          ),
                          DropdownMenuItem(
                            value: Duration(hours: 3),
                            child: Text('3 Hours'),
                          ),
                          DropdownMenuItem(
                            value: Duration(days: 1),
                            child: Text('24 Hours'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedDuration = val;
                            });
                          }
                        },
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
                      // Capture navigator and messenger BEFORE the async gap,
                      // because the Firestore write triggers a snapshot listener
                      // that rebuilds HomeScreen, which can unmount this context.
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        final session = await _sessionService.createSession(
                          titleController.text.trim(),
                          subtitleController.text.trim(),
                          selectedDuration,
                        );

                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Created Session "${session
                                  .title}" with Join Code: ${session.joinCode}',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create session: $e'),
                              backgroundColor: Theme
                                  .of(context)
                                  .colorScheme
                                  .error,
                            ),
                          );
                        }
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

  void _showJoinSessionDialog() {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AlertDialog(
          title: Text('Join Session', style: textTheme.titleLarge),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: codeController,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: '6-digit Join Code',
                hintText: 'e.g. AGENT1',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 5) {
                  return 'Please enter a valid code';
                }
                return null;
              },
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
                  final error = await _sessionService.joinSessionByCode(
                    codeController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);

                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: colors.error,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session shortcut added successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  void _openSession({required Session session, required bool isParticipant}) {
    final page = isParticipant
        ? ParticipantSessionPage(session: session)
        : AdministratorSessionPage(session: session);

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  List<Widget> _buildAppBarActions(ColorScheme colors) {
    return [
      IconButton(
        tooltip: 'Sign Out',
        icon: Icon(Icons.logout_outlined, color: colors.error),
        onPressed: () async {
          try {
            await _authService.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error logging out: $e'),
                  backgroundColor: colors.error,
                ),
              );
            }
          }
        },
      ),
      const SizedBox(width: 8),
    ];
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colors, TextTheme textTheme,
      String displayName) {
    if (_currentIndex == 0) {
      return AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 16),
            Image.asset('assets/images/quest_logo.png', height: 46),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back,',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  displayName,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _buildAppBarActions(colors),
      );
    } else if (_currentIndex == 1) {
      return AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Favorites',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _buildAppBarActions(colors),
      );
    } else {
      return AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Trash Bin',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _buildAppBarActions(colors),
      );
    }
  }

  Widget _buildHomeBody(ColorScheme colors, TextTheme textTheme,
      List<Session> filteredSessions) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // List Header & Tabs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Sessions',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Created'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Shortcuts'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Session list or empty states
                filteredSessions.isEmpty
                    ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 60.0,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 64,
                          color: colors.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Sessions Found',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedFilter == 'Shortcuts'
                              ? 'Join a session to add it as a shortcut.'
                              : 'Create a session or join one to get started.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
                    final isShortcut = _sessionService
                        .isSessionShortcut(session.sessionID);
                    final isFavorite = _sessionService
                        .isSessionFavorite(session.sessionID);

                    return SessionCard(
                      session: session,
                      isShortcut: isShortcut,
                      isFavorite: isFavorite,
                      onFavoriteToggle: () {
                        _sessionService.toggleFavorite(session.sessionID);
                      },
                      onTap: () {
                        _openSession(
                          session: session,
                          isParticipant: isShortcut,
                        );
                      },
                      onDelete: () {
                        _sessionService.deleteSession(
                          session.sessionID,
                        );
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    final currentUser = _authService.currentUser;
    final displayName = currentUser?.displayName?.isNotEmpty == true
        ? currentUser!.displayName!
        : (currentUser?.email != null
        ? currentUser!.email!.split('@')[0]
        : 'User');

    // Retrieve active sessions
    final allActiveSessions = _sessionService.getActiveSessions();

    // Filter sessions based on selected category tab
    final filteredSessions = allActiveSessions.where((session) {
      final isShortcut = _sessionService.isSessionShortcut(session.sessionID);

      if (_selectedFilter == 'Created') {
        return !isShortcut;
      } else if (_selectedFilter == 'Shortcuts') {
        return isShortcut;
      }

      return true; // 'All'
    }).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: _buildAppBar(colors, textTheme, displayName),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeBody(colors, textTheme, filteredSessions),
            const FavoritesPage(),
            const TrashPage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          NavigationDestination(
            icon: Icon(Icons.delete_outline),
            selectedIcon: Icon(Icons.delete),
            label: 'Trash',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButtonMenu(
        expanded: _isFabExpanded,
        button: ToggleFloatingActionButton(
          checked: _isFabExpanded,
          onCheckedChange: (checked) {
            setState(() {
              _isFabExpanded = checked;
            });
          },
          child: AnimatedRotation(
            turns: _isFabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
        children: [
          FloatingActionButtonMenuItem(
            onPressed: () => _showJoinSessionDialog(),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Join'),
          ),
          FloatingActionButtonMenuItem(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
          ),
          FloatingActionButtonMenuItem(
            onPressed: () => _showCreateSessionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      )
          : null,
    );
  }

  Widget _buildFilterChip(String filterName) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final isSelected = _selectedFilter == filterName;

    return FilterChip(
      label: Text(filterName),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedFilter = filterName;
        });
      },
      selectedColor: colors.primaryContainer,
      checkmarkColor: colors.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.isShortcut,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
    required this.onDelete,
  });

  final Session session;
  final bool isShortcut;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String _getExpiryText(DateTime expiry) {
    final now = DateTime.now();
    final difference = expiry.difference(now);

    if (now.isAfter(expiry)) {
      return 'Expired';
    }

    if (difference.inDays > 0) {
      return 'Expires in ${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return 'Expires in ${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return 'Expires in ${difference.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;
    final isExpired = session.isExpired;
    final expiryText = _getExpiryText(session.expiry);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colors.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      color: colors.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge for type (Created vs Shortcut)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isShortcut
                          ? colors.secondaryContainer
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isShortcut ? 'Shortcut' : 'Created',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isShortcut
                            ? colors.onSecondaryContainer
                            : colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge for active status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? colors.errorContainer
                          : colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isExpired ? 'Expired (View Only)' : 'Active',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isExpired
                            ? colors.onErrorContainer
                            : colors.onTertiaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: isFavorite
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : colors.onSurfaceVariant,
                    ),
                    iconSize: 22,
                    onPressed: onFavoriteToggle,
                  ),
                  // Popup Menu for options
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'delete') {
                        onDelete();
                      } else if (val == 'view') {
                        onTap();
                      }
                    },
                    itemBuilder: (context) =>
                    [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('Enter Session'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          isShortcut ? 'Remove Shortcut' : 'Move to Trash',
                          style: TextStyle(
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                session.title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
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
              const SizedBox(height: 24),
              // Expiry row moved here to prevent overflow
              Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isExpired ? colors.error : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    expiryText,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isExpired ? colors.error : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.key_rounded,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Join Code: ',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    session.joinCode,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    icon: const Icon(Icons.content_copy),
                    iconSize: 18,
                    tooltip: 'Copy Join Code',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: session.joinCode),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Join code copied!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code),
                    iconSize: 18,
                    tooltip: 'Show QR code',
                    onPressed: () async {
                      // Action details
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
