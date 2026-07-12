import 'package:flutter/material.dart';

import '../models/session.dart';

class AdministratorSessionPage extends StatelessWidget {
  const AdministratorSessionPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return _SessionPageTemplate(
      session: session,
      roleLabel: 'Administrator',
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
      roleLabel: 'Participant',
      tabDescriptions: const [
        'Ask questions and browse the session discussion.',
        'View and answer polls shared by the administrator.',
        'Take quizzes made available in this session.',
      ],
    );
  }
}

class _SessionPageTemplate extends StatelessWidget {
  const _SessionPageTemplate({
    required this.session,
    required this.roleLabel,
    required this.tabDescriptions,
  });

  final Session session;
  final String roleLabel;
  final List<String> tabDescriptions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(session.title),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.forum_outlined), text: 'Q&A'),
              Tab(icon: Icon(Icons.poll_outlined), text: 'Polls'),
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Quizzes'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleLabel,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (session.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      session.subtitle,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TabPlaceholder(
                    icon: Icons.forum_outlined,
                    title: 'Q&A',
                    description: tabDescriptions[0],
                  ),
                  _TabPlaceholder(
                    icon: Icons.poll_outlined,
                    title: 'Polls',
                    description: tabDescriptions[1],
                  ),
                  _TabPlaceholder(
                    icon: Icons.quiz_outlined,
                    title: 'Quizzes',
                    description: tabDescriptions[2],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
