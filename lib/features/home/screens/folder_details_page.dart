import 'package:flutter/material.dart';
import '../../sessions/models/session.dart';
import '../../sessions/models/folder.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/screens/session_pages.dart';
import 'home_screen.dart';

class FolderDetailsPage extends StatefulWidget {
  final Folder folder;

  const FolderDetailsPage({super.key, required this.folder});

  @override
  State<FolderDetailsPage> createState() => _FolderDetailsPageState();
}

class _FolderDetailsPageState extends State<FolderDetailsPage> {
  final _sessionService = SessionService();
  String? _selectedPrimary;
  String? _selectedSecondary;

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

  void _showMoveToFolderDialog(Session session) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final folders = _sessionService.getFolders();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move to Folder', style: textTheme.titleLarge),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Default'),
                trailing: session.folder == 'Default' || session.folder.isEmpty
                    ? Icon(Icons.check, color: colors.primary)
                    : null,
                onTap: () {
                  _sessionService.updateSessionFolder(
                    session.sessionID,
                    'Default',
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Session moved to Default.')),
                  );
                },
              ),
              const Divider(),
              ...folders.map(
                (folder) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(folder.name),
                  trailing: session.folder == folder.name
                      ? Icon(Icons.check, color: colors.primary)
                      : null,
                  onTap: () {
                    _sessionService.updateSessionFolder(
                      session.sessionID,
                      folder.name,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Session moved to "${folder.name}".'),
                      ),
                    );
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Get active sessions belonging to this folder
    final activeSessions = _sessionService.getActiveSessions();
    final folderSessions = activeSessions
        .where((s) => s.folder == widget.folder.name)
        .toList();

    // Apply sorting & filtering based on primary and secondary chips
    var filteredSessions = List<Session>.from(folderSessions);

    if (_selectedPrimary == 'Ownership') {
      if (_selectedSecondary == 'Created') {
        filteredSessions = folderSessions.where((session) {
          return !_sessionService.isSessionShortcut(session.sessionID);
        }).toList();
      } else if (_selectedSecondary == 'Shortcuts') {
        filteredSessions = folderSessions.where((session) {
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
      appBar: AppBar(
        title: Text(
          widget.folder.name,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            Icons.folder_open_outlined,
                            size: 80,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Folder is Empty',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Move sessions into this folder to see them here.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
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
                          onMoveToFolder: () =>
                              _showMoveToFolderDialog(session),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
