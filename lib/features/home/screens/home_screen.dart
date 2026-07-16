import 'package:flutter/material.dart';
import '../../authentication/services/auth_service.dart';
import '../../sessions/models/session.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/screens/session_pages.dart';
import 'package:fab_menu_expressive/fab_menu_expressive.dart';
import 'package:flutter/services.dart';
import 'favorites_page.dart';
import 'trash_page.dart';
import 'folders_page.dart';
import 'folder_details_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _sessionService = SessionService();
  final SearchController _searchController = SearchController();
  bool _wasSearchOpen = false;
  String? _selectedPrimary;
  String? _selectedSecondary;
  bool _isFabExpanded = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _sessionService.addListener(_updateState);
    _searchController.addListener(_onSearchControllerChanged);
  }

  @override
  void dispose() {
    _sessionService.removeListener(_updateState);
    _searchController.removeListener(_onSearchControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchControllerChanged() {
    final isOpen = _searchController.isOpen;
    if (_wasSearchOpen && !isOpen) {
      _searchController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _wasSearchOpen = isOpen;
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

  Future<void> _openSession(
      {required Session session, required bool isParticipant}) {
    final page = isParticipant
        ? ParticipantSessionPage(session: session)
        : AdministratorSessionPage(session: session);

    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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

  void _showRestoreConfirmDialog(Session session) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Restore Session?'),
            content: Text(
                'Do you want to restore the session "${session.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  _sessionService.restoreSession(session.sessionID);
                  Navigator.pop(context);
                  _searchController.clear();
                  FocusManager.instance.primaryFocus?.unfocus();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Restored "${session.title}"')),
                  );
                },
                child: const Text('Restore'),
              ),
            ],
          ),
    );
  }

  Iterable<Widget> _getSearchSuggestions(SearchController controller) {
    final query = controller.text.toLowerCase();
    final List<Widget> suggestions = [];

    final activeSessions = _sessionService.getActiveSessions();
    final favoriteSessions = _sessionService.getFavoriteSessions();
    final trashedSessions = _sessionService.getTrashedSessions();
    final folders = _sessionService.getFolders();

    // 1. Folders suggestions
    final matchingFolders = folders
        .where((f) => f.name.toLowerCase().contains(query))
        .toList();
    if (matchingFolders.isNotEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
        child: Text('Folders',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ));
      suggestions.addAll(matchingFolders.map((folder) =>
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: Text(folder.name),
            onTap: () {
              controller.closeView(folder.name);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderDetailsPage(folder: folder),
                ),
              ).then((_) {
                _searchController.clear();
                FocusManager.instance.primaryFocus?.unfocus();
              });
            },
          )));
    }

    // 2. Favorites suggestions
    final matchingFavorites = favoriteSessions
        .where((s) =>
    s.title.toLowerCase().contains(query) ||
        s.subtitle.toLowerCase().contains(query))
        .toList();
    if (matchingFavorites.isNotEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
        child: Text('Favorites',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ));
      suggestions.addAll(matchingFavorites.map((session) =>
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: Text(session.title),
            subtitle: Text(session.subtitle.isNotEmpty
                ? session.subtitle
                : 'Active Favorite Session'),
            onTap: () {
              controller.closeView(session.title);
              final isShortcut = _sessionService.isSessionShortcut(
                  session.sessionID);
              _openSession(session: session, isParticipant: isShortcut).then((
                  _) {
                _searchController.clear();
                FocusManager.instance.primaryFocus?.unfocus();
              });
            },
          )));
    }

    // 3. Active Sessions suggestions
    final favoriteIds = favoriteSessions.map((s) => s.sessionID).toSet();
    final matchingSessions = activeSessions
        .where((s) => !favoriteIds.contains(s.sessionID))
        .where((s) =>
    s.title.toLowerCase().contains(query) ||
        s.subtitle.toLowerCase().contains(query))
        .toList();
    if (matchingSessions.isNotEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
        child: Text('Sessions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ));
      suggestions.addAll(matchingSessions.map((session) =>
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(session.title),
            subtitle: Text(session.subtitle.isNotEmpty
                ? session.subtitle
                : 'Active Session'),
            onTap: () {
              controller.closeView(session.title);
              final isShortcut = _sessionService.isSessionShortcut(
                  session.sessionID);
              _openSession(session: session, isParticipant: isShortcut).then((
                  _) {
                _searchController.clear();
                FocusManager.instance.primaryFocus?.unfocus();
              });
            },
          )));
    }

    // 4. Trashed Sessions suggestions
    final matchingTrashed = trashedSessions
        .where((s) =>
    s.title.toLowerCase().contains(query) ||
        s.subtitle.toLowerCase().contains(query))
        .toList();
    if (matchingTrashed.isNotEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.only(left: 16.0, top: 12.0, bottom: 4.0),
        child: Text('Deleted Sessions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ));
      suggestions.addAll(matchingTrashed.map((session) =>
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.grey),
            title: Text(
              session.title,
              style: const TextStyle(decoration: TextDecoration.lineThrough),
            ),
            subtitle: const Text('Restore from Trash'),
            trailing: const Icon(Icons.restore_rounded),
            onTap: () {
              controller.closeView(session.title);
              _showRestoreConfirmDialog(session);
            },
          )));
    }

    if (suggestions.isEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text('No matching items found.'),
        ),
      ));
    }

    return suggestions;
  }

  void _showMoveToFolderDialog(Session session) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;
    final folders = _sessionService.getFolders();

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Move to Folder', style: textTheme.titleLarge),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Default'),
                    trailing: session.folder == 'Default' ||
                        session.folder.isEmpty
                        ? Icon(Icons.check, color: colors.primary)
                        : null,
                    onTap: () {
                      _sessionService.updateSessionFolder(
                          session.sessionID, 'Default');
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Session moved to Default.')),
                      );
                    },
                  ),
                  const Divider(),
                  ...folders.map((folder) =>
                      ListTile(
                        leading: const Icon(Icons.folder),
                        title: Text(folder.name),
                        trailing: session.folder == folder.name
                            ? Icon(Icons.check, color: colors.primary)
                            : null,
                        onTap: () {
                          _sessionService.updateSessionFolder(
                              session.sessionID, folder.name);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Session moved to "${folder
                                .name}".')),
                          );
                        },
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Widget _buildHomeBody(ColorScheme colors, TextTheme textTheme,
      List<Session> filteredSessions) {
    final folders = _sessionService.getFolders();

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
                SearchAnchor(
                  searchController: _searchController,
                  builder: (BuildContext context, SearchController controller) {
                    return SearchBar(
                      controller: controller,
                      elevation: const WidgetStatePropertyAll<double>(0.0),
                      backgroundColor: WidgetStatePropertyAll<Color>(
                        colors.surfaceContainerHigh,
                      ),
                      padding: const WidgetStatePropertyAll<EdgeInsets>(
                        EdgeInsets.symmetric(horizontal: 16.0),
                      ),
                      onTap: () {
                        controller.openView();
                      },
                      onChanged: (_) {
                        controller.openView();
                      },
                      leading: const Icon(Icons.search),
                      trailing: <Widget>[
                        if (controller.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                            },
                          ),
                      ],
                      hintText: 'Search sessions, folders, favorites...',
                    );
                  },
                  suggestionsBuilder: (BuildContext context,
                      SearchController controller) {
                    return _getSearchSuggestions(controller);
                  },
                ),
                const SizedBox(height: 24),
                // Folders Grid Section
                if (folders.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3.5,
                    ),
                    itemCount: folders.length > 4 ? 4 : folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      return OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FolderDetailsPage(folder: folder),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.folder,
                          color: colors.onSurfaceVariant,
                        ),
                        label: Text(
                          folder.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.5),
                          ),
                          foregroundColor: colors.onSurface,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                // More Folders text button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (
                            context) => const FoldersPage()),
                      );
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text('More folders'),
                  ),
                ),
                const SizedBox(height: 24),

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
                    children: _buildSortFilterChips(colors),
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
                          (_selectedPrimary == 'Ownership' &&
                              _selectedSecondary == 'Shortcuts')
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
                      onMoveToFolder: () => _showMoveToFolderDialog(session),
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

    // Apply sorting & filtering based on primary and secondary chips
    var filteredSessions = List<Session>.from(allActiveSessions);

    if (_selectedPrimary == 'Ownership') {
      if (_selectedSecondary == 'Created') {
        filteredSessions = allActiveSessions.where((session) {
          return !_sessionService.isSessionShortcut(session.sessionID);
        }).toList();
      } else if (_selectedSecondary == 'Shortcuts') {
        filteredSessions = allActiveSessions.where((session) {
          return _sessionService.isSessionShortcut(session.sessionID);
        }).toList();
      }
    }

    if (_selectedPrimary == 'Name') {
      if (_selectedSecondary == 'Z-A') {
        filteredSessions.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      } else {
        filteredSessions.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      }
    } else if (_selectedPrimary == 'Date') {
      int getCreationTime(Session session) {
        final id = session.sessionID;
        if (id.startsWith('sess_')) {
          final timeStr = id.substring(5);
          final time = int.tryParse(timeStr);
          if (time != null) return time;
        }
        return 0;
      }

      if (_selectedSecondary == 'Oldest') {
        filteredSessions.sort((a, b) =>
            getCreationTime(a).compareTo(getCreationTime(b)));
      } else {
        filteredSessions.sort((a, b) =>
            getCreationTime(b).compareTo(getCreationTime(a)));
      }
    }



    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AbsorbPointer(
          absorbing: _isFabExpanded,
          child: _buildAppBar(colors, textTheme, displayName),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeBody(colors, textTheme, filteredSessions),
                const FavoritesPage(),
                const TrashPage(),
              ],
            ),
          ),
          if (_isFabExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isFabExpanded = false;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: _isFabExpanded,
        child: NavigationBar(
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

  List<Widget> _buildSortFilterChips(ColorScheme colors) {
    final List<Widget> chips = [];

    if (_selectedPrimary == null) {
      chips.add(_buildPrimaryChip('Name', colors));
      chips.add(const SizedBox(width: 8));
      chips.add(_buildPrimaryChip('Date', colors));
      chips.add(const SizedBox(width: 8));
      chips.add(_buildPrimaryChip('Ownership', colors));
    } else {
      chips.add(_buildPrimaryChip(_selectedPrimary!, colors));
      chips.add(const SizedBox(width: 8));

      if (_selectedPrimary == 'Name') {
        chips.add(_buildSecondaryChip('Z-A', colors));
      } else if (_selectedPrimary == 'Date') {
        chips.add(_buildSecondaryChip('Oldest', colors));
      } else if (_selectedPrimary == 'Ownership') {
        chips.add(_buildSecondaryChip('Created', colors));
        chips.add(const SizedBox(width: 8));
        chips.add(_buildSecondaryChip('Shortcuts', colors));
      }
    }

    return chips;
  }

  Widget _buildPrimaryChip(String label, ColorScheme colors) {
    final isSelected = _selectedPrimary == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (isSelected) {
            _selectedPrimary = null;
            _selectedSecondary = null;
          } else {
            _selectedPrimary = label;
            _selectedSecondary = null;
          }
        });
      },
      selectedColor: colors.primaryContainer,
      checkmarkColor: colors.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildSecondaryChip(String label, ColorScheme colors) {
    final isSelected = _selectedSecondary == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedSecondary = isSelected ? null : label;
        });
      },
      selectedColor: colors.secondaryContainer,
      checkmarkColor: colors.onSecondaryContainer,
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
    required this.onMoveToFolder,
  });

  final Session session;
  final bool isShortcut;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onMoveToFolder;

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
                      color: isFavorite ? colors.primary : colors
                          .onSurfaceVariant,
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
                      } else if (val == 'folder') {
                        onMoveToFolder();
                      }
                    },
                    itemBuilder: (context) =>
                    [
                      const PopupMenuItem(
                        value: 'view',
                        child: Text('Enter Session'),
                      ),
                      const PopupMenuItem(
                        value: 'folder',
                        child: Text('Move to Folder...'),
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
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) {
                          final dialogColors = Theme
                              .of(context)
                              .colorScheme;
                          final dialogTextTheme = Theme
                              .of(context)
                              .textTheme;

                          return AlertDialog(
                            title: Text(
                              'Scan to Join',
                              style: dialogTextTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  session.title,
                                  style: dialogTextTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: dialogColors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  child: QrImageView(
                                    data: session.joinCode,
                                    version: QrVersions.auto,
                                    size: 200.0,
                                    gapless: false,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Join Code: ${session.joinCode}',
                                  style: dialogTextTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: dialogColors.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
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
