import 'package:flutter/material.dart';
import '../../authentication/services/auth_service.dart';
import '../../sessions/models/session.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/screens/trash_screen.dart';
import '../../sessions/screens/session_pages.dart';
import 'package:fab_menu_expressive/fab_menu_expressive.dart';

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

  // Formatting function for expiration time
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
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final session = _sessionService.createSession(
                        titleController.text.trim(),
                        subtitleController.text.trim(),
                        selectedDuration,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Created Session "${session.title}" with Join Code: ${session.joinCode}',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final error = _sessionService.joinSessionByCode(
                    codeController.text,
                  );
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
      appBar: AppBar(
        title: Image.asset('assets/images/quest_logo.png', height: 46),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // Nav to Trash Bin
          IconButton(
            tooltip: 'Trash Bin',
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: colors.onSurfaceVariant,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrashScreen()),
              );
            },
          ),
          const SizedBox(width: 8),

          // Logout Button
          IconButton(
            tooltip: 'Sign Out',
            icon: Icon(Icons.logout_outlined, color: colors.error),
            onPressed: () async {
              try {
                await _authService.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
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
                        // Welcome Banner Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.primary, colors.primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back,',
                                style: textTheme.bodyLarge?.copyWith(
                                  color: colors.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                displayName,
                                style: textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colors.onPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Create a live session or enter a code to join one.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

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
                        Row(
                          children: [
                            _buildFilterChip('All'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Created'),
                            const SizedBox(width: 8),
                            _buildFilterChip('Shortcuts'),
                          ],
                        ),
                        const SizedBox(height: 16),

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
                                  final isExpired = session.isExpired;
                                  final expiryText = _getExpiryText(
                                    session.expiry,
                                  );

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
                                      onTap: () {
                                        _openSession(
                                          session: session,
                                          isParticipant: isShortcut,
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Badge for type (Created vs Shortcut)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isShortcut
                                                        ? colors
                                                              .secondaryContainer
                                                        : colors
                                                              .primaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isShortcut
                                                        ? 'Shortcut'
                                                        : 'Created',
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isShortcut
                                                              ? colors
                                                                    .onSecondaryContainer
                                                              : colors
                                                                    .onPrimaryContainer,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Badge for active status
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isExpired
                                                        ? colors.errorContainer
                                                        : colors
                                                              .tertiaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    isExpired
                                                        ? 'Expired (View Only)'
                                                        : 'Active',
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isExpired
                                                              ? colors
                                                                    .onErrorContainer
                                                              : colors
                                                                    .onTertiaryContainer,
                                                        ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                // Popup Menu for options
                                                PopupMenuButton<String>(
                                                  onSelected: (val) {
                                                    if (val == 'delete') {
                                                      _sessionService
                                                          .deleteSession(
                                                            session.sessionID,
                                                          );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            isShortcut
                                                                ? 'Shortcut removed.'
                                                                : 'Session moved to Trash.',
                                                          ),
                                                        ),
                                                      );
                                                    } else if (val == 'view') {
                                                      _openSession(
                                                        session: session,
                                                        isParticipant:
                                                            isShortcut,
                                                      );
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(
                                                      value: 'view',
                                                      child: Text(
                                                        'Enter Session',
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text(
                                                        isShortcut
                                                            ? 'Remove Shortcut'
                                                            : 'Move to Trash',
                                                        style: TextStyle(
                                                          color: colors.error,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  icon: Icon(
                                                    Icons.more_vert_rounded,
                                                    color:
                                                        colors.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              session.title,
                                              style: textTheme.titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: colors.onSurface,
                                                  ),
                                            ),
                                            if (session
                                                .subtitle
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                session.subtitle,
                                                style: textTheme.bodyMedium
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                            const SizedBox(height: 16),
                                            Divider(
                                              color: colors.outlineVariant
                                                  .withValues(alpha: 0.3),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.key_rounded,
                                                  size: 16,
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Join Code: ',
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colors
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                                Text(
                                                  session.joinCode,
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: colors.primary,
                                                      ),
                                                ),
                                                const Spacer(),
                                                Icon(
                                                  Icons.timer_outlined,
                                                  size: 16,
                                                  color: isExpired
                                                      ? colors.error
                                                      : colors.onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  expiryText,
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isExpired
                                                            ? colors.error
                                                            : colors
                                                                  .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButtonMenu(
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
            icon: Icon(Icons.groups_outlined),
            label: const Text('Join'),
          ),
          FloatingActionButtonMenuItem(
            onPressed: () {},
            icon: Icon(Icons.qr_code_scanner),
            label: const Text('Scan'),
          ),
          FloatingActionButtonMenuItem(
            onPressed: () => _showCreateSessionDialog(),
            icon: Icon(Icons.add),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildFabMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 2,
          color: colors.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Icon(icon),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterName) {
    final colors = Theme.of(context).colorScheme;
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
