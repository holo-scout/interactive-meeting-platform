import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';

import '../models/session.dart';

class AdministratorSessionPage extends StatelessWidget {
  const AdministratorSessionPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return _SessionPageTemplate(
      session: session,
      isAdministrator: true,
      tabDescriptions: const [
        'Review and manage questions from participants.',
        'Create and manage live polls for this session.',
        'Create quizzes and review participant results.',
      ],
    );
  }
}

class ParticipantSessionPage extends StatelessWidget {
  const ParticipantSessionPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return _SessionPageTemplate(
      session: session,
      isAdministrator: false,
      tabDescriptions: const [
        'Ask questions and browse the session discussion.',
        'View and answer polls shared by the administrator.',
        'Take quizzes made available in this session.',
      ],
    );
  }
}

class _SessionPageTemplate extends StatefulWidget {
  const _SessionPageTemplate({
    required this.session,
    required this.isAdministrator,
    required this.tabDescriptions,
  });

  final Session session;
  final bool isAdministrator;
  final List<String> tabDescriptions;

  @override
  State<_SessionPageTemplate> createState() => _SessionPageTemplateState();
}

class _SessionPageTemplateState extends State<_SessionPageTemplate> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showAdd =
        (widget.isAdministrator && (_index == 1 || _index == 2)) ||
        (!widget.isAdministrator && _index == 0);
    final showSubmit = !widget.isAdministrator && _index == 2;
    final actionIcon = showAdd
        ? Icons.add
        : showSubmit
        ? Icons.send_rounded
        : null;
    final actionTooltip = showAdd ? 'Add' : 'Submit quiz';
    final tabPages = [
      _TabPlaceholder(
        icon: Icons.forum_outlined,
        title: 'Q&A',
        description: widget.tabDescriptions[0],
      ),
      _TabPlaceholder(
        icon: Icons.poll_outlined,
        title: 'Polls',
        description: widget.tabDescriptions[1],
      ),
      _TabPlaceholder(
        icon: Icons.quiz_outlined,
        title: 'Quizzes',
        description: widget.tabDescriptions[2],
      ),
    ];

    return BottomBar(
      layout: BottomBarLayout(
        width: actionIcon == null ? 220 : 280,
        borderRadius: BorderRadius.circular(50),
      ),
      theme: BottomBarThemeData(
        barDecoration: BoxDecoration(
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(50),
        ),
      ),
      motion: const BottomBarMotion.cupertino(
        preset: BottomBarCupertinoMotion.bouncy,
        extraBounce: 0.02,
        transition: BottomBarTransition.slide,
      ),
      scrollBehavior: const BottomBarScrollBehavior(hideOnScroll: true),
      showIcon: false,
      body: Scaffold(
        appBar: AppBar(title: Text(widget.session.title))),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: IndexedStack(index: _index, children: tabPages),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavigationIcon(
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum,
              index: 0,
              tooltip: 'Q&A',
            ),
            _buildNavigationIcon(
              icon: Icons.poll_outlined,
              selectedIcon: Icons.poll,
              index: 1,
              tooltip: 'Polls',
            ),
            _buildNavigationIcon(
              icon: Icons.quiz_outlined,
              selectedIcon: Icons.quiz,
              index: 2,
              tooltip: 'Quizzes',
            ),
            if (actionIcon != null) ...[
              SizedBox(
                height: 28,
                child: VerticalDivider(color: colors.outlineVariant),
              ),
              _buildActionIcon(
                icon: actionIcon,
                tooltip: actionTooltip,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$actionTooltip action is coming soon.')),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationIcon({
    required IconData icon,
    required IconData selectedIcon,
    required int index,
    required String tooltip,
  }) {
    final colors = Theme
        .of(context)
        .colorScheme;
    final isSelected = _index == index;

    return IconButton(
      tooltip: tooltip,
      onPressed: () => setState(() => _index = index),
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colors.secondaryContainer : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected ? colors.onSecondaryContainer : colors
              .onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final colors = Theme
        .of(context)
        .colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colors.primary),
            const SizedBox(height: 16),
            Text(title, style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This section will be added next.',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
