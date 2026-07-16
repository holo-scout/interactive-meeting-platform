import 'package:flutter/material.dart';
import '../../sessions/models/session.dart';
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
  String? _selectedPrimary;
  String? _selectedSecondary;
  final SearchController _searchController = SearchController();
  bool _wasSearchOpen = false;

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

  Future<void> _openSession(Session session) {
    final isShortcut = _sessionService.isSessionShortcut(session.sessionID);
    final page = isShortcut
        ? ParticipantSessionPage(session: session)
        : AdministratorSessionPage(session: session);
    return Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Iterable<Widget> _getSearchSuggestions(SearchController controller) {
    final query = controller.text.toLowerCase();
    final List<Widget> suggestions = [];
    final favoriteSessions = _sessionService.getFavoriteSessions();

    final matchingFavorites = favoriteSessions
        .where((s) =>
    s.title.toLowerCase().contains(query) ||
        s.subtitle.toLowerCase().contains(query))
        .toList();

    if (matchingFavorites.isNotEmpty) {
      suggestions.addAll(matchingFavorites.map((session) =>
          ListTile(
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: Text(session.title),
            subtitle: Text(session.subtitle.isNotEmpty
                ? session.subtitle
                : 'Favorite Session'),
            onTap: () {
              controller.closeView(session.title);
              _openSession(session).then((_) {
                _searchController.clear();
                FocusManager.instance.primaryFocus?.unfocus();
              });
            },
          )));
    }

    if (suggestions.isEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text('No matching favorites found.'),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final favoriteSessions = _sessionService.getFavoriteSessions();

    // Apply sorting & filtering based on primary and secondary chips
    var filteredSessions = List<Session>.from(favoriteSessions);

    if (_selectedPrimary == 'Ownership') {
      if (_selectedSecondary == 'Created') {
        filteredSessions = favoriteSessions.where((session) {
          return !_sessionService.isSessionShortcut(session.sessionID);
        }).toList();
      } else if (_selectedSecondary == 'Shortcuts') {
        filteredSessions = favoriteSessions.where((session) {
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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
                    hintText: 'Search favorites...',
                  );
                },
                suggestionsBuilder: (BuildContext context,
                    SearchController controller) {
                  return _getSearchSuggestions(controller);
                },
              ),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _buildSortFilterChips(colors),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredSessions.isEmpty
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
                          'No Favorites Found',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your favorite sessions will appear here.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  itemCount: filteredSessions.length,
                  itemBuilder: (context, index) {
                    final session = filteredSessions[index];
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
                      onMoveToFolder: () => _showMoveToFolderDialog(session),
                    );
                  },
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
