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
  late Map<String, QuizAnswer> _answers;
  final Map<String, TextEditingController> _openEndedFeedbackControllers = {};
  late TextEditingController _overallFeedbackController;
  late bool _isGraded;

  @override
  void initState() {
    super.initState();
    _isGraded = widget.submission.isGraded;
    _answers = Map<String, QuizAnswer>.from(widget.submission.answers);
    _overallFeedbackController = TextEditingController(
      text: widget.submission.feedback,
    );

    for (var question in widget.quiz.questions) {
      if (question.type == 'open_ended') {
        final existingAns = _answers[question.questionId];
        _openEndedFeedbackControllers[question.questionId] =
            TextEditingController(text: existingAns?.teacherFeedback ?? '');
      }
    }
  }

  @override
  void dispose() {
    _overallFeedbackController.dispose();
    for (var controller in _openEndedFeedbackControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _calculatedScore {
    int total = 0;
    for (var question in widget.quiz.questions) {
      final answer = _answers[question.questionId];
      if (answer == null) continue;

      if (question.type == 'multiple_choice') {
        final isCorrect = question.correctAnswers.isNotEmpty &&
            answer.selectedOptions.isNotEmpty &&
            question.correctAnswers.first == answer.selectedOptions.first;
        if (isCorrect) total++;
      } else if (question.type == 'checkbox') {
        final correctSet = question.correctAnswers.toSet();
        final selectedSet = answer.selectedOptions.toSet();
        final isCorrect = correctSet.isNotEmpty &&
            correctSet.length == selectedSet.length &&
            correctSet
                .difference(selectedSet)
                .isEmpty;
        if (isCorrect) total++;
      } else if (question.type == 'open_ended') {
        if (answer.isCorrect == true) {
          total++;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.submission.username}\'s grade')),
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
              final answer = _answers[question.questionId];

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

              final openEndedIsCorrect = answer.isCorrect;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.5),
                  ),
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
                              '${idx + 1}. ${question.questionText}',
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
                            )
                          else
                            if (openEndedIsCorrect != null)
                              Icon(
                                openEndedIsCorrect
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: openEndedIsCorrect
                                    ? Colors.green
                                    : Colors.red,
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
                        if (answer.selectedOptions.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'No answer selected',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        else
                          ...answer.selectedOptions.map(
                                (opt) =>
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      if (question.type == 'multiple_choice')
                                        Radio<bool>(
                                          value: true,
                                          groupValue: true,
                                          onChanged: null,
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        )
                                      else
                                        Checkbox(
                                          value: true,
                                          onChanged: null,
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          opt,
                                          style: const TextStyle(
                                              color: Colors.black),
                                        ),
                                      ),
                                    ],
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
                            child: Row(
                              children: [
                                if (question.type == 'multiple_choice')
                                  Radio<bool>(
                                    value: true,
                                    groupValue: true,
                                    onChanged: null,
                                    fillColor:
                                    WidgetStateProperty.all(Colors.green),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  )
                                else
                                  Checkbox(
                                    value: true,
                                    onChanged: null,
                                    fillColor:
                                    WidgetStateProperty.all(Colors.green),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                  ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
                          answer.textResponse != null &&
                              answer.textResponse!.isNotEmpty
                              ? answer.textResponse!
                              : '(No response text provided)',
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
                        if (!_isGraded) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _answers[question.questionId] =
                                        answer.copyWith(isCorrect: true);
                                  });
                                },
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Mark Correct'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: openEndedIsCorrect == true
                                      ? colors.primary
                                      : colors.primaryContainer,
                                  foregroundColor: openEndedIsCorrect == true
                                      ? colors.onPrimary
                                      : colors.onPrimaryContainer,
                                  elevation: 0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _answers[question.questionId] =
                                        answer.copyWith(isCorrect: false);
                                  });
                                },
                                icon: const Icon(Icons.close, size: 18),
                                label: const Text('Mark Wrong'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: openEndedIsCorrect == false
                                      ? colors.errorContainer
                                      : colors.surfaceContainerHighest,
                                  foregroundColor: openEndedIsCorrect == false
                                      ? colors.onErrorContainer
                                      : colors.onSurfaceVariant,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller:
                          _openEndedFeedbackControllers[question.questionId],
                          readOnly: _isGraded,
                          decoration: InputDecoration(
                            labelText: 'Question Feedback (Optional)',
                            hintText: 'Add feedback for this answer...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (val) {
                            _answers[question.questionId] =
                                answer.copyWith(teacherFeedback: val.trim());
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

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
                        Text(
                          '$_calculatedScore / ${widget.quiz.questions
                              .length} points',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _overallFeedbackController,
                      readOnly: _isGraded,
                      decoration: const InputDecoration(
                        labelText: 'Overall Lecturer Feedback',
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
            if (!_isGraded) ...[
              FilledButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final messenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    // Sync per-question feedback controllers
                    _openEndedFeedbackControllers.forEach((qId, controller) {
                      final ans = _answers[qId] ??
                          QuizAnswer(selectedOptions: []);
                      _answers[qId] =
                          ans.copyWith(teacherFeedback: controller.text.trim());
                    });

                    try {
                      await QuizService().gradeSubmission(
                        widget.session.sessionID,
                        widget.quiz.quizId,
                        widget.submission.userId,
                        _calculatedScore,
                        _overallFeedbackController.text.trim(),
                        _answers,
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
            ] else
              ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green),
                    ),
                    child: const Text(
                      'Graded & Feedback Submitted',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
