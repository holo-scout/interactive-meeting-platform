import 'package:flutter/material.dart';
import '../../sessions/models/session.dart';
import '../../sessions/services/session_service.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key, this.isLargeScreen = false});

  final bool isLargeScreen;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
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
    final trashedSessions = _sessionService.getTrashedSessions();

    final matchingTrashed = trashedSessions
        .where((s) =>
    s.title.toLowerCase().contains(query) ||
        s.subtitle.toLowerCase().contains(query))
        .toList();

    if (matchingTrashed.isNotEmpty) {
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
          child: Text('No matching deleted sessions found.'),
        ),
      ));
    }

    return suggestions;
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

    // Apply sorting & filtering based on primary and secondary chips
    var filteredSessions = List<Session>.from(trashedSessions);

    if (_selectedPrimary == 'Ownership') {
      if (_selectedSecondary == 'Created') {
        filteredSessions = trashedSessions.where((session) {
          return !_sessionService.isSessionShortcut(session.sessionID);
        }).toList();
      } else if (_selectedSecondary == 'Shortcuts') {
        filteredSessions = trashedSessions.where((session) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isLargeScreen) ...[
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
                  hintText: 'Search trash...',
                );
              },
              suggestionsBuilder:
                  (BuildContext context, SearchController controller) {
                return _getSearchSuggestions(controller);
              },
            ),
            const SizedBox(height: 24),
          ],
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
                      Icons.delete_outline_rounded,
                      size: 80,
                      color:
                      colors.onSurfaceVariant.withValues(alpha: 0.4),
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
                        color: colors.onSurfaceVariant
                            .withValues(alpha: 0.7),
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
                return _buildTrashSessionCard(
                  filteredSessions[index],
                  colors,
                  textTheme,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashSessionCard(Session session, ColorScheme colors,
      TextTheme textTheme) {
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
