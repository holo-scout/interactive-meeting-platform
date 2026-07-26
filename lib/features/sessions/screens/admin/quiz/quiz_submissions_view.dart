import 'package:flutter/material.dart';
import '../../../models/session.dart';
import '../../../models/quiz.dart';
import '../../../services/quiz_service.dart';
import 'student_submission_view.dart';

class QuizSubmissionsView extends StatelessWidget {
  const QuizSubmissionsView({
    super.key,
    required this.session,
    required this.quiz,
  });

  final Session session;
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Submissions: ${quiz.title}')),
      body: StreamBuilder<List<QuizSubmission>>(
        stream: QuizService().streamSubmissions(session.sessionID, quiz.quizId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading submissions: ${snapshot.error}',
                style: TextStyle(color: colors.error),
              ),
            );
          }

          final submissions = snapshot.data ?? [];

          if (submissions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: colors.primary),
                    const SizedBox(height: 16),
                    Text('No Submissions Yet', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'No students have completed this quiz yet.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final sub = submissions[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: Colors.white,
                child: ListTile(
                  title: Text(
                    sub.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    sub.isGraded ? 'Status: Graded' : 'Status: Awaiting Review',
                    style: TextStyle(
                      color: sub.isGraded ? Colors.green : colors.secondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Score: ${sub.score} / ${quiz.questions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentSubmissionGradingView(
                          session: session,
                          quiz: quiz,
                          submission: sub,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
