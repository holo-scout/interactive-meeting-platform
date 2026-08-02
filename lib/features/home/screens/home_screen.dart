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
                          hintText: 'e.g. Q&A, quiz and Live Polls',
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

  Widget _buildSearchBarWidget(ColorScheme colors,
      {String hint = 'Search sessions, folders, favorites...'}) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          elevation: const WidgetStatePropertyAll<double>(0.0),
          backgroundColor: WidgetStatePropertyAll<Color>(
            colors.surfaceContainerHigh,
          ),
          constraints: const BoxConstraints(
            maxWidth: 600,
            minHeight: 52,
            maxHeight: 52,
          ),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 18.0),
          ),
          onTap: () {
            controller.openView();
          },
          onChanged: (_) {
            controller.openView();
          },
          leading: const Icon(Icons.search, size: 22),
          trailing: <Widget>[
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  controller.clear();
                },
              ),
          ],
          hintText: hint,
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) {
        return _getSearchSuggestions(controller);
      },
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme colors, TextTheme textTheme,
      String displayName, bool isLargeScreen) {
    Widget titleWidget;

    final welcomeLogoWidget = Row(
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
    );

    if (isLargeScreen) {
      String searchHint = 'Search sessions, folders, favorites...';
      if (_currentIndex == 1) {
        searchHint = 'Search favorites...';
      } else if (_currentIndex == 2) {
        searchHint = 'Search trash...';
      }

      titleWidget = Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: welcomeLogoWidget,
          ),
          Center(
            child: SizedBox(
              width: 580,
              child: _buildSearchBarWidget(colors, hint: searchHint),
            ),
          ),
        ],
      );
    } else {
      if (_currentIndex == 0) {
        titleWidget = welcomeLogoWidget;
      } else if (_currentIndex == 1) {
        titleWidget = Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Favorites',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        );
      } else {
        titleWidget = Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Text(
            'Trash Bin',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
        );
      }
    }

    return AppBar(
      titleSpacing: 0,
      title: titleWidget,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: _buildAppBarActions(colors),
    );
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
      List<Session> filteredSessions, bool isLargeScreen) {
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
                if (!isLargeScreen) ...[
                  SearchAnchor(
                    searchController: _searchController,
                    builder:
                        (BuildContext context, SearchController controller) {
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
                ],
                // Folders Grid Section
                if (!isLargeScreen && folders.isNotEmpty) ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 48,
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
                if (!isLargeScreen) ...[
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const FoldersPage()),
                        );
                      },
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('More folders'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

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


    final isLargeScreen = MediaQuery
        .of(context)
        .size
        .width >= 700;

    final mainBody = Stack(
      children: [
        SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeBody(
                  colors, textTheme, filteredSessions, isLargeScreen),
              FavoritesPage(isLargeScreen: isLargeScreen),
              TrashPage(isLargeScreen: isLargeScreen),
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
    );

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isLargeScreen ? 76 : kToolbarHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: isLargeScreen ? 8.0 : 0.0,
            horizontal: isLargeScreen ? 12.0 : 0.0,
          ),
          child: AbsorbPointer(
            absorbing: _isFabExpanded,
            child: _buildAppBar(colors, textTheme, displayName, isLargeScreen),
          ),
        ),
      ),
      body: isLargeScreen
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSideNavPane(colors, textTheme),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                ),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: mainBody,
            ),
          ),
        ],
      )
          : mainBody,
      bottomNavigationBar: isLargeScreen
          ? null
          : AbsorbPointer(
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

  Widget _buildSideNavPane(ColorScheme colors, TextTheme textTheme) {
    final items = [
      {
        'icon': Icons.home_outlined,
        'selectedIcon': Icons.home,
        'label': 'Home',
      },
      {
        'icon': Icons.favorite_outline,
        'selectedIcon': Icons.favorite,
        'label': 'Favorites',
      },
      {
        'icon': Icons.delete_outline,
        'selectedIcon': Icons.delete,
        'label': 'Trash',
      },
    ];

    final folders = _sessionService.getFolders();

    return Container(
      width: 240,
      color: colors.surface,
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _buildSideNavItem(
                index: i,
                icon: items[i]['icon'] as IconData,
                selectedIcon: items[i]['selectedIcon'] as IconData,
                label: items[i]['label'] as String,
                isSelected: _currentIndex == i,
                colors: colors,
                textTheme: textTheme,
              ),
              const SizedBox(height: 4),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Folders',
                style: textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            for (final folder in folders) ...[
              _buildFolderNavItem(
                icon: Icons.folder_outlined,
                label: folder.name,
                colors: colors,
                textTheme: textTheme,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FolderDetailsPage(folder: folder),
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
            ],
            _buildFolderNavItem(
              icon: Icons.folder_copy_outlined,
              label: 'View all folders',
              colors: colors,
              textTheme: textTheme,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FoldersPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderNavItem({
    required IconData icon,
    required String label,
    required ColorScheme colors,
    required TextTheme textTheme,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required ColorScheme colors,
    required TextTheme textTheme,
  }) {
    final backgroundColor =
    isSelected ? colors.primaryContainer : Colors.transparent;
    final foregroundColor =
    isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: foregroundColor,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
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
    if (expiry.year >= 2100) {
      return 'No Expiry';
    }
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
                  IconButton(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    iconSize: 22,
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        useSafeArea: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius
                              .circular(24)),
                        ),
                        builder: (context) {
                          return _SessionOptionsBottomSheet(
                            session: session,
                            isShortcut: isShortcut,
                            onDelete: onDelete,
                          );
                        },
                      );
                    },
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
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: colors.surfaceContainer,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius
                              .circular(28)),
                        ),
                        builder: (context) {
                          final sheetColors = Theme
                              .of(context)
                              .colorScheme;
                          final sheetTextTheme = Theme
                              .of(context)
                              .textTheme;

                          return SafeArea(
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: sheetColors.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Scan to Join',
                                      style: sheetTextTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: sheetColors.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.all(32),
                                      child: SizedBox(
                                        width: 200,
                                        height: 200,
                                        child: QrImageView(
                                          data: session.joinCode,
                                          version: QrVersions.auto,
                                          gapless: false,
                                          eyeStyle: QrEyeStyle(
                                            eyeShape: QrEyeShape.circle,
                                            color: sheetColors.primary,
                                          ),
                                          dataModuleStyle: QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape
                                                .circle,
                                            color: sheetColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Join Code: ${session.joinCode}',
                                      style: sheetTextTheme.titleMedium
                                          ?.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: sheetColors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        await Clipboard.setData(
                                          ClipboardData(text: session.joinCode),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger
                                              .of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Join code copied!'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                          Icons.copy_rounded, size: 16),
                                      label: const Text('Copy Code'),
                                      style: OutlinedButton.styleFrom(
                                        shape: const StadiumBorder(),
                                        side: BorderSide(
                                          color: sheetColors.outline.withValues(
                                              alpha: 0.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
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

class _SessionOptionsBottomSheet extends StatefulWidget {
  final Session session;
  final bool isShortcut;
  final VoidCallback onDelete;

  const _SessionOptionsBottomSheet({
    required this.session,
    required this.isShortcut,
    required this.onDelete,
  });

  @override
  State<_SessionOptionsBottomSheet> createState() =>
      _SessionOptionsBottomSheetState();
}

class _SessionOptionsBottomSheetState
    extends State<_SessionOptionsBottomSheet> {
  late String _title;
  late String _subtitle;
  late String _folder;
  late bool _isActive;
  late DateTime _expiry;
  late String _expiryLabel;

  @override
  void initState() {
    super.initState();
    _title = widget.session.title;
    _subtitle = widget.session.subtitle;
    _folder = widget.session.folder;
    _isActive = !widget.session.isExpired;
    _expiry = widget.session.expiry;
    _expiryLabel = _getExpiryOptionLabel(_expiry);
  }

  String _getExpiryOptionLabel(DateTime expiry) {
    if (expiry.year >= 2100) return 'None';
    final now = DateTime.now();
    if (now.isAfter(expiry)) return 'Expired';
    final diff = expiry.difference(now);
    if (diff.inDays > 0) {
      return '${diff.inDays} Hours';
    }
    final totalMinutes = diff.inMinutes;
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0) {
      return '$hours Hours $mins Minutes';
    } else {
      return '$mins Minutes';
    }
  }

  void _showFolderSelectorDialog() {
    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;
    final folders = SessionService().getFolders();

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
                    trailing: _folder == 'Default' || _folder.isEmpty
                        ? Icon(Icons.check, color: colors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _folder = 'Default';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(),
                  ...folders.map(
                        (folder) =>
                        ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(folder.name),
                          trailing: _folder == folder.name
                              ? Icon(Icons.check, color: colors.primary)
                              : null,
                          onTap: () {
                            setState(() {
                              _folder = folder.name;
                            });
                            Navigator.pop(context);
                          },
                        ),
                  ),
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

  void _showExpirySelectionDialog() {
    final textTheme = Theme
        .of(context)
        .textTheme;

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text('Select Expiry', style: textTheme.titleLarge),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('30 Minutes'),
                    onTap: () {
                      setState(() {
                        _expiry =
                            DateTime.now().add(const Duration(minutes: 30));
                        _expiryLabel = '30 Minutes';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('1 Hour'),
                    onTap: () {
                      setState(() {
                        _expiry = DateTime.now().add(const Duration(hours: 1));
                        _expiryLabel = '1 Hour';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('3 Hours'),
                    onTap: () {
                      setState(() {
                        _expiry = DateTime.now().add(const Duration(hours: 3));
                        _expiryLabel = '3 Hours';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('24 Hours'),
                    onTap: () {
                      setState(() {
                        _expiry = DateTime.now().add(const Duration(days: 1));
                        _expiryLabel = '24 Hours';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('None'),
                    onTap: () {
                      setState(() {
                        _expiry = DateTime(2100, 1, 1);
                        _expiryLabel = 'None';
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildConfigTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colors,
    required TextTheme textTheme,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? colors.onSurfaceVariant : Colors.grey.shade400,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: enabled ? colors.onSurface : Colors.grey.shade400,
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
                          color: enabled ? colors.onSurfaceVariant : Colors.grey
                              .shade400,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: enabled ? colors.onSurfaceVariant : Colors.grey
                            .shade400,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colors,
    required TextTheme textTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
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
            .bottom + (bottomPadding > 0 ? bottomPadding : 16.0),
        left: 16,
        right: 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Group 1: Title, Subtitle, Folder
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
                const Divider(height: 8, thickness: 2, color: Colors.white),
                _buildConfigTile(
                  icon: Icons.folder_open_rounded,
                  label: 'Folder',
                  value: _folder.isEmpty ? 'Default' : _folder,
                  colors: colors,
                  textTheme: textTheme,
                  onTap: _showFolderSelectorDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Group 2: Active, Expiry
          Container(
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildActiveTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Active',
                  value: _isActive,
                  onChanged: (val) {
                    setState(() {
                      _isActive = val;
                      if (_isActive) {
                        _expiry = DateTime(2100, 1, 1);
                        _expiryLabel = 'None';
                      } else {
                        _expiry = DateTime(2000, 1, 1);
                        _expiryLabel = 'Expired';
                      }
                    });
                  },
                  colors: colors,
                  textTheme: textTheme,
                ),
                const Divider(height: 8, thickness: 2, color: Colors.white),
                _buildConfigTile(
                  icon: Icons.timer_outlined,
                  label: 'Expiry',
                  value: _expiryLabel,
                  colors: colors,
                  textTheme: textTheme,
                  enabled: _isActive,
                  onTap: _showExpirySelectionDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bottom Action Row (Delete / Save)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete();
                },
                icon: const Icon(
                    Icons.delete_outline_rounded, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final titleTrimmed = _title.trim();
                  if (titleTrimmed.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a session title'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  final updatedSession = widget.session.copyWith(
                    title: titleTrimmed,
                    subtitle: _subtitle.trim(),
                    folder: _folder,
                    expiry: _expiry,
                  );

                  try {
                    await SessionService().updateSession(updatedSession);
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Session updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to update session: $e'),
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
