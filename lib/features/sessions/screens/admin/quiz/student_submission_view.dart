import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../models/session.dart';
import '../../../models/quiz.dart';
import '../../../services/quiz_service.dart';

class StudentSubmissionGradingView extends StatefulWidget {
  const StudentSubmissionGradingView({
    super.key,
    required this.session,
    required this.quiz,
    required this.submission,
  });

  final Session session;
  final Quiz quiz;
  final QuizSubmission submission;

  @override
  State<StudentSubmissionGradingView> createState() =>
      _StudentSubmissionGradingViewState();
}

class _StudentSubmissionGradingViewState
    extends State<StudentSubmissionGradingView> {
  final _formKey = GlobalKey<FormState>();
  late int _selectedScore;
  late TextEditingController _feedbackController;

  @override
  void initState() {
    super.initState();
    _selectedScore = widget.submission.score;
    if (_selectedScore > widget.quiz.questions.length) {
      _selectedScore = widget.quiz.questions.length;
    }
    _feedbackController = TextEditingController(
      text: widget.submission.feedback,
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('Grade: ${widget.submission.username}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Answers Review',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...widget.quiz.questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final question = entry.value;
              final answer = widget.submission.answers[question.questionId];

              if (answer == null) {
                return const SizedBox();
              }

              bool isCorrect = false;
              if (question.type == 'multiple_choice') {
                isCorrect =
                    question.correctAnswers.isNotEmpty &&
                    answer.selectedOptions.isNotEmpty &&
                    question.correctAnswers.first ==
                        answer.selectedOptions.first;
              } else if (question.type == 'checkbox') {
                final correctSet = question.correctAnswers.toSet();
                final selectedSet = answer.selectedOptions.toSet();
                isCorrect =
                    correctSet.isNotEmpty &&
                    correctSet.length == selectedSet.length &&
                    correctSet.difference(selectedSet).isEmpty;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Question ${idx + 1}: ${question.questionText}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (question.type != 'open_ended')
                            Icon(
                              isCorrect
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
                              color: isCorrect ? Colors.green : Colors.red,
                            ),
                        ],
                      ),
                      const Divider(height: 24),

                      if (question.type == 'multiple_choice' ||
                          question.type == 'checkbox') ...[
                        Text(
                          'Student selected:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ...answer.selectedOptions.map(
                          (opt) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '- $opt',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Correct answer:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        ...question.correctAnswers.map(
                          (opt) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '- $opt',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ] else if (question.type == 'open_ended') ...[
                        Text(
                          'Student response:',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          answer.textResponse ?? '',
                          style: textTheme.bodyLarge,
                        ),
                        if (answer.base64Image != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              width: double.infinity,
                              child: Image.memory(
                                base64Decode(answer.base64Image!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        if (question.correctImageBase64 != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              width: double.infinity,
                              child: Image.memory(
                                base64Decode(question.correctImageBase64!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Text(
              'Assign Grade & Feedback',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
              ),
              color: colors.primaryContainer.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Score:',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<int>(
                          value: _selectedScore,
                          items: List.generate(
                            widget.quiz.questions.length + 1,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(
                                '$index / ${widget.quiz.questions.length} points',
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedScore = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _feedbackController,
                      decoration: const InputDecoration(
                        labelText: 'Lecturer Feedback',
                        hintText: 'Add notes or corrections for the student...',
                        border: OutlineInputBorder(),
                      ),
                      maxLength: 300,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  try {
                    await QuizService().gradeSubmission(
                      widget.session.sessionID,
                      widget.quiz.quizId,
                      widget.submission.userId,
                      _selectedScore,
                      _feedbackController.text.trim(),
                    );
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Grade saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    navigator.pop();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to save grade: $e'),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Submit Grade & Feedback',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
