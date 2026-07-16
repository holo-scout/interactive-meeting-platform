import 'package:flutter/material.dart';
import '../../sessions/services/session_service.dart';
import '../../sessions/models/folder.dart';
import 'folder_details_page.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
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

  Iterable<Widget> _getSearchSuggestions(SearchController controller) {
    final query = controller.text.toLowerCase();
    final List<Widget> suggestions = [];
    final folders = _sessionService.getFolders();

    final matchingFolders = folders
        .where((f) => f.name.toLowerCase().contains(query))
        .toList();

    if (matchingFolders.isNotEmpty) {
      suggestions.addAll(matchingFolders.map((folder) =>
          ListTile(
            leading: const Icon(Icons.folder),
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

    if (suggestions.isEmpty) {
      suggestions.add(const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text('No matching folders found.'),
        ),
      ));
    }

    return suggestions;
  }

  void _showCreateFolderDialog() {
    final textTheme = Theme.of(context).textTheme;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Folder', style: textTheme.titleLarge),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Folder Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _sessionService.createFolder(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFolder(Folder folder) async {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Folder?', style: textTheme.titleLarge),
        content: Text(
          'This will delete the folder "${folder.name}". Sessions inside this folder will be reset to Default.',
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
      _sessionService.deleteFolder(folder.folderID, folder.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "${folder.name}" deleted.')),
        );
      }
    }
  }

  void _showRenameFolderDialog(Folder folder) {
    final textTheme = Theme.of(context).textTheme;
    final controller = TextEditingController(text: folder.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename Folder', style: textTheme.titleLarge),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'New Folder Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != folder.name) {
                _sessionService.renameFolder(
                  folder.folderID,
                  folder.name,
                  newName,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Folder renamed to "$newName".')),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final activeSessions = _sessionService.getActiveSessions();

    final folders = List<Folder>.from(_sessionService.getFolders());
    if (_selectedPrimary == 'Name') {
      if (_selectedSecondary == 'Z-A') {
        folders.sort((a, b) =>
            b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      } else {
        folders.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'My Folders',
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
                  SearchAnchor(
                    searchController: _searchController,
                    builder: (BuildContext context,
                        SearchController controller) {
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
                        hintText: 'Search folders...',
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
                    child: folders.isEmpty
                        ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.create_new_folder_outlined,
                            size: 80,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Folders Yet',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create folders to organize your sessions.',
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
                      itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final folder = folders[index];
                      final sessionCount = activeSessions
                          .where((s) => s.folder == folder.name)
                          .length;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                        color: colors.surfaceContainerLow,
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FolderDetailsPage(folder: folder),
                              ),
                            );
                          },
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            child: const Icon(Icons.folder),
                          ),
                          title: Text(
                            folder.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            '$sessionCount ${sessionCount == 1 ? "session" : "sessions"}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'rename') {
                                _showRenameFolderDialog(folder);
                              } else if (val == 'delete') {
                                _confirmDeleteFolder(folder);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            ],
                            icon: Icon(
                              Icons.more_vert,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateFolderDialog,
        tooltip: 'Create Folder',
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildSortFilterChips(ColorScheme colors) {
    final List<Widget> chips = [];

    if (_selectedPrimary == null) {
      chips.add(_buildPrimaryChip('Name', colors));
    } else {
      chips.add(_buildPrimaryChip(_selectedPrimary!, colors));
      chips.add(const SizedBox(width: 8));

      if (_selectedPrimary == 'Name') {
        chips.add(_buildSecondaryChip('Z-A', colors));
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
