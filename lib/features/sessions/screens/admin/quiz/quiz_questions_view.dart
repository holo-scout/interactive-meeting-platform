import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../models/session.dart';
import '../../../models/quiz.dart';
import '../../../services/quiz_service.dart';

class ManageQuizQuestionsPage extends StatefulWidget {
  const ManageQuizQuestionsPage({
    super.key,
    required this.session,
    required this.quiz,
  });

  final Session session;
  final Quiz quiz;

  @override
  State<ManageQuizQuestionsPage> createState() =>
      _ManageQuizQuestionsPageState();
}

class _ManageQuizQuestionsPageState extends State<ManageQuizQuestionsPage> {
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _questions = [];
  bool _isShowingDialog = false;

  @override
  void initState() {
    super.initState();
    if (widget.quiz.questions.isNotEmpty) {
      for (var question in widget.quiz.questions) {
        int correctIdx = 0;
        List<int> correctIndices = [];

        if (question.type == 'multiple_choice' &&
            question.correctAnswers.isNotEmpty) {
          correctIdx = question.options.indexOf(question.correctAnswers.first);
          if (correctIdx == -1) correctIdx = 0;
        } else if (question.type == 'checkbox') {
          for (var correctAns in question.correctAnswers) {
            final idx = question.options.indexOf(correctAns);
            if (idx != -1) {
              correctIndices.add(idx);
            }
          }
        }

        _questions.add({
          'questionId': question.questionId,
          'type': question.type,
          'questionText': question.questionText,
          'options': List<String>.from(
            question.options.isNotEmpty ? question.options : ['', ''],
          ),
          'correctOptionIndex': correctIdx,
          'correctOptionIndices': correctIndices,
          'correctAnswerText':
              question.type == 'open_ended' &&
                  question.correctAnswers.isNotEmpty
              ? question.correctAnswers.first
              : '',
          'correctImageBase64': question.correctImageBase64,
        });
      }
    } else {
      _addQuestion('multiple_choice');
    }
  }

  void _addQuestion(String type) {
    setState(() {
      _questions.add({
        'questionId':
            'q_${DateTime.now().millisecondsSinceEpoch}_${_questions.length}',
        'type': type,
        'questionText': '',
        'options': type == 'open_ended' ? <String>[] : <String>['', ''],
        'correctOptionIndex': 0,
        'correctOptionIndices': <int>[0],
        'correctAnswerText': '',
        'correctImageBase64': null,
      });
    });
  }

  Future<void> _pickSuggestedAnswerImage(int qIndex) async {
    final colors = Theme.of(context).colorScheme;
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _questions[qIndex]['correctImageBase64'] = base64String;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _showAiGenerationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _AiGenerationBottomSheet(sessionID: widget.session.sessionID);
      },
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        if (!mounted) return;
        final mcq = result['mcqCount'] as int;
        final chk = result['checkboxCount'] as int;
        final open = result['openEndedCount'] as int;
        final topics = List<String>.from(result['selectedTopics']);

        if (topics.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please select at least one topic to generate quiz questions.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }

        final messenger = ScaffoldMessenger.of(context);
        final errorColor = Theme.of(context).colorScheme.error;

        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 16),
                Text('AI generating quiz questions...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        List<QuizQuestion>? questions;
        try {
          final fileUrl = result['fileUrl'] as String;

          final relevantToQna = result['relevantToQna'] as bool? ?? false;
          final requestPayload = {
            'fileUrl': fileUrl,
            'selectedTopics': topics,
            'mcqCount': mcq,
            'checkboxCount': chk,
            'openCount': open,
            'sessionId': widget.session.sessionID,
            'relevantToQna': relevantToQna,
          };

          int attempts = 0;
          const maxAttempts =
              4; // 1 initial attempt + 3 retries = 4 attempts total

          while (attempts < maxAttempts) {
            try {
              attempts++;
              debugPrint(
                'AI quiz Generation: Calling generateQuizQuestions (Attempt $attempts/$maxAttempts) with payload: $requestPayload',
              );

              final callable = FirebaseFunctions.instance.httpsCallable(
                'generateQuizQuestions',
              );
              final response = await callable.call(requestPayload);
              debugPrint(
                'AI quiz Generation: generateQuizQuestions response received. Data: ${response.data}',
              );

              if (response.data != null && response.data['questions'] != null) {
                final questionsData = response.data['questions'] as List;
                int qId = 1;
                questions = questionsData.map((q) {
                  return QuizQuestion(
                    questionId: 'q_${qId++}',
                    questionText: q['questionText'] as String? ?? '',
                    type: q['type'] as String? ?? 'multiple_choice',
                    options: List<String>.from(q['options'] ?? []),
                    correctAnswers: List<String>.from(
                      q['correctAnswers'] ?? [],
                    ),
                  );
                }).toList();
                debugPrint(
                  'AI quiz Generation: Parsed ${questions.length} questions successfully.',
                );
                break;
              } else {
                debugPrint(
                  'AI quiz Generation Warning: Response is missing questions list on attempt $attempts: ${response.data}',
                );
                if (attempts >= maxAttempts) {
                  throw Exception(
                    'Invalid response schema from quiz generation.',
                  );
                }
              }
            } catch (e) {
              debugPrint(
                "AI quiz Generation Error: Production AI question generation failed on attempt $attempts: $e",
              );
              if (attempts >= maxAttempts) {
                rethrow;
              }
            }
          }
        } catch (e) {
          debugPrint(
            "AI quiz Generation Error: Production AI question generation failed after all attempts: $e",
          );
        }

        if (questions == null) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'AI quiz generation failed. Please try again.',
              ),
              backgroundColor: errorColor,
            ),
          );
          return;
        }

        final List<Map<String, dynamic>> newQuestionMaps = [];
        for (var question in questions) {
          int correctIdx = 0;
          List<int> correctIndices = [];

          if (question.type == 'multiple_choice' &&
              question.correctAnswers.isNotEmpty) {
            correctIdx =
                question.options.indexOf(question.correctAnswers.first);
            if (correctIdx == -1) correctIdx = 0;
          } else if (question.type == 'checkbox') {
            for (var correctAns in question.correctAnswers) {
              final idx = question.options.indexOf(correctAns);
              if (idx != -1) {
                correctIndices.add(idx);
              }
            }
            if (correctIndices.isEmpty) {
              correctIndices = [0];
            }
          }

          newQuestionMaps.add({
            'questionId':
            'q_${DateTime
                .now()
                .millisecondsSinceEpoch}_${_questions.length +
                newQuestionMaps.length}',
            'type': question.type,
            'questionText': question.questionText,
            'options': List<String>.from(
              question.options.isNotEmpty
                  ? question.options
                  : (question.type == 'open_ended' ? [] : ['', '']),
            ),
            'correctOptionIndex': correctIdx,
            'correctOptionIndices': correctIndices,
            'correctAnswerText': question.type == 'open_ended' &&
                question.correctAnswers.isNotEmpty
                ? question.correctAnswers.first
                : '',
            'correctImageBase64': question.correctImageBase64,
          });
        }

        setState(() {
          if (_questions.length == 1 &&
              (_questions.first['questionText'] as String).isEmpty) {
            _questions.clear();
          }
          _questions.addAll(newQuestionMaps);
        });

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Added ${questions
                  .length} AI-generated questions to the current quiz!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showAddQuestionBottomSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        Widget buildOptionItem({
          required IconData icon,
          required Color iconBgColor,
          required Color iconColor,
          required String title,
          required String description,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: iconBgColor,
                    radius: 24,
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          bottom: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Choose Question Type',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      buildOptionItem(
                        icon: Icons.radio_button_checked,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        title: 'Multiple Choice',
                        description: 'Single correct option, auto-graded.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('multiple_choice');
                        },
                      ),
                      const Divider(height: 1, indent: 72, color: Colors.white),
                      buildOptionItem(
                        icon: Icons.check_box_outlined,
                        iconBgColor: Colors.purple.shade50,
                        iconColor: Colors.purple.shade700,
                        title: 'Checkbox',
                        description: 'Multiple correct options, auto-graded.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('checkbox');
                        },
                      ),
                      const Divider(height: 1, indent: 72, color: Colors.white),
                      buildOptionItem(
                        icon: Icons.text_fields_outlined,
                        iconBgColor: Colors.orange.shade50,
                        iconColor: Colors.orange.shade700,
                        title: 'Open-Ended',
                        description:
                            'Text response with optional screenshot upload.',
                        onTap: () {
                          Navigator.pop(context);
                          _addQuestion('open_ended');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
    });
  }

  void _addOption(int qIndex) {
    setState(() {
      final opts = _questions[qIndex]['options'] as List<String>;
      if (opts.length < 10) {
        opts.add('');
      }
    });
  }

  void _removeOption(int qIndex, int optIndex) {
    setState(() {
      final opts = _questions[qIndex]['options'] as List<String>;
      final correctIndices =
          _questions[qIndex]['correctOptionIndices'] as List<int>;
      final correctIdx = _questions[qIndex]['correctOptionIndex'] as int;

      if (opts.length > 2) {
        opts.removeAt(optIndex);
        if (correctIdx == optIndex) {
          _questions[qIndex]['correctOptionIndex'] = 0;
        } else if (correctIdx > optIndex) {
          _questions[qIndex]['correctOptionIndex'] = correctIdx - 1;
        }

        correctIndices.remove(optIndex);
        final updatedIndices = correctIndices.map((idx) {
          return idx > optIndex ? idx - 1 : idx;
        }).toList();
        _questions[qIndex]['correctOptionIndices'] = updatedIndices;
      }
    });
  }

  Widget _buildTypeBadge(String type, ColorScheme colors, TextTheme textTheme) {
    String label = '';
    Color bgColor = Colors.grey.shade100;
    Color textColor = Colors.black87;

    if (type == 'multiple_choice') {
      label = 'Multiple Choice';
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
    } else if (type == 'checkbox') {
      label = 'Checkbox';
      bgColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
    } else if (type == 'open_ended') {
      label = 'Open-Ended';
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Future<void> _showUnsavedChangesDialog() async {
    if (_isShowingDialog) return;
    _isShowingDialog = true;

    final colors = Theme
        .of(context)
        .colorScheme;
    final textTheme = Theme
        .of(context)
        .textTheme;

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Unsaved Changes',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'You have unsaved changes in your quiz questions. Would you like to save or discard them?',
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          actionsPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop('discard'),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    _isShowingDialog = false;

    if (!mounted) return;

    if (result == 'discard') {
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pop();
    } else if (result == 'save') {
      _saveQuestions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ScaffoldMessenger.of(context).clearSnackBars();
          return;
        }
        _showUnsavedChangesDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 200,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.maybePop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _showAiGenerationBottomSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddQuestionBottomSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(
                right: 20.0,
                top: 8.0,
                bottom: 8.0,
              ),
              child: FilledButton(
                onPressed: _saveQuestions,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Questions (${_questions.length})',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              ..._questions.asMap().entries.map((qEntry) {
                final qIndex = qEntry.key;
                final qMap = qEntry.value;
                final qType = qMap['type'] as String;
                final opts = qMap['options'] as List<String>;
                final correctIdx = qMap['correctOptionIndex'] as int;
                final correctIndices =
                    qMap['correctOptionIndices'] as List<int>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 24),
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
                            Row(
                              children: [
                                Text(
                                  'Question ${qIndex + 1}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTypeBadge(qType, colors, textTheme),
                              ],
                            ),
                            if (_questions.length > 1)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: colors.error,
                                ),
                                onPressed: () => _removeQuestion(qIndex),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: qMap['questionText'] as String,
                          decoration: InputDecoration(
                            labelText: 'Question Text',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter question text';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            qMap['questionText'] = val.trim();
                          },
                        ),
                        const SizedBox(height: 16),

                        if (qType == 'multiple_choice' ||
                            qType == 'checkbox') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Options',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Mark correct answers',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...opts.asMap().entries.map((optEntry) {
                            final optIndex = optEntry.key;
                            final optText = optEntry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  if (qType == 'multiple_choice')
                                    Radio<int>(
                                      value: optIndex,
                                      groupValue: correctIdx,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            qMap['correctOptionIndex'] = val;
                                          });
                                        }
                                      },
                                    )
                                  else
                                    Checkbox(
                                      value: correctIndices.contains(optIndex),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            correctIndices.add(optIndex);
                                          } else {
                                            correctIndices.remove(optIndex);
                                          }
                                        });
                                      },
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: optText,
                                      decoration: InputDecoration(
                                        labelText: 'Option ${optIndex + 1}',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onChanged: (val) {
                                        opts[optIndex] = val.trim();
                                      },
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter option text';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  if (opts.length > 2) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: colors.error,
                                      ),
                                      onPressed: () =>
                                          _removeOption(qIndex, optIndex),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          if (opts.length < 10) ...[
                            TextButton.icon(
                              onPressed: () => _addOption(qIndex),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Option'),
                            ),
                          ],
                        ],

                        if (qType == 'open_ended') ...[
                          Text(
                            'Suggested Answer',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue:
                                qMap['correctAnswerText'] as String? ?? '',
                            decoration: InputDecoration(
                              labelText: 'Reference Answer (Optional)',
                              hintText:
                                  'Type suggested correct answer guidelines for students...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 3,
                            onChanged: (val) {
                              qMap['correctAnswerText'] = val.trim();
                            },
                          ),
                          const SizedBox(height: 12),
                          if (qMap['correctImageBase64'] != null) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.image,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'suggested_answer.png',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            qMap['correctImageBase64'] = null;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 150,
                                ),
                                child: Image.memory(
                                  base64Decode(
                                    qMap['correctImageBase64'] as String,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _pickSuggestedAnswerImage(qIndex),
                              icon: const Icon(Icons.image_outlined),
                              label: const Text(
                                'Attach Reference Image / Screenshot',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _saveQuestions() async {
    if (!_formKey.currentState!.validate()) return;

    final colors = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final List<QuizQuestion> parsedQuestions = [];

    for (var qMap in _questions) {
      final qType = qMap['type'] as String;
      final qText = qMap['questionText'] as String;
      final qId = qMap['questionId'] as String;
      final opts = qMap['options'] as List<String>;
      final correctIdx = qMap['correctOptionIndex'] as int;
      final correctIndices = qMap['correctOptionIndices'] as List<int>;

      List<String> correctAnswers = [];
      if (qType == 'multiple_choice') {
        if (correctIdx >= opts.length) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Please select a valid correct option for Multiple Choice.',
              ),
              backgroundColor: colors.error,
            ),
          );
          return;
        }
        correctAnswers = [opts[correctIdx]];
      } else if (qType == 'checkbox') {
        if (correctIndices.isEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                'Please select at least one correct option for each Checkbox question.',
              ),
              backgroundColor: colors.error,
            ),
          );
          return;
        }
        correctAnswers = correctIndices.map((idx) => opts[idx]).toList();
      } else if (qType == 'open_ended') {
        final answerText = qMap['correctAnswerText'] as String? ?? '';
        correctAnswers = answerText.isNotEmpty ? [answerText] : [];
      }

      parsedQuestions.add(
        QuizQuestion(
          questionId: qId,
          type: qType,
          questionText: qText,
          options: (qType == 'open_ended') ? [] : opts,
          correctAnswers: correctAnswers,
          correctImageBase64: qMap['correctImageBase64'] as String?,
        ),
      );
    }

    final updatedQuiz = widget.quiz.copyWith(questions: parsedQuestions);

    try {
      await QuizService().createOrUpdateQuiz(
        widget.session.sessionID,
        updatedQuiz,
      );
      messenger.showSnackBar(
        const SnackBar(
          content: Text('quiz questions saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save questions: $e'),
          backgroundColor: colors.error,
        ),
      );
    }
  }
}

class _AiGenerationBottomSheet extends StatefulWidget {
  const _AiGenerationBottomSheet({required this.sessionID});

  final String sessionID;

  @override
  State<_AiGenerationBottomSheet> createState() =>
      _AiGenerationBottomSheetState();
}

class _AiGenerationBottomSheetState extends State<_AiGenerationBottomSheet> {
  int _mcqCount = 5;
  int _checkboxCount = 3;
  int _openEndedCount = 2;
  bool _relevantToQna = false;
  PlatformFile? _selectedPdf;
  List<String> _detectedTopics = [];
  final Set<String> _selectedTopics = {};
  bool _isAnalyzing = false;
  String? _uploadedFileUrl;

  Future<void> _pickPdfFile() async {
    final colors = Theme.of(context).colorScheme;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedPdf = file;
          _isAnalyzing = true;
        });

        try {
          String fileUrl = '';
          if (file.bytes != null) {
            debugPrint(
              'AI quiz Generation: Uploading PDF to Firebase Storage...',
            );
            final storageRef = FirebaseStorage.instance.ref().child(
              'session_pdfs/${widget.sessionID}/${DateTime.now().millisecondsSinceEpoch}_${file.name}',
            );
            await storageRef.putData(file.bytes!);
            _uploadedFileUrl = await storageRef.getDownloadURL();
            fileUrl = _uploadedFileUrl!;
            debugPrint(
              'AI quiz Generation: PDF uploaded successfully. fileUrl: $fileUrl',
            );
          }

          if (fileUrl.isNotEmpty) {
            int attempts = 0;
            const maxAttempts =
                4; // 1 initial attempt + 3 retries = 4 attempts total

            while (attempts < maxAttempts) {
              try {
                attempts++;
                debugPrint(
                  'AI quiz Generation: Calling extractTopicsFromPdf (Attempt $attempts/$maxAttempts) with fileUrl: $fileUrl',
                );
                final callable = FirebaseFunctions.instance.httpsCallable(
                  'extractTopicsFromPdf',
                );
                final response = await callable.call({'fileUrl': fileUrl});
                debugPrint(
                  'AI quiz Generation: extractTopicsFromPdf response received. Data: ${response.data}',
                );

                final topics = List<String>.from(response.data['topics']);
                if (topics.isNotEmpty) {
                  setState(() {
                    _detectedTopics = topics;
                    _selectedTopics.clear();
                    _selectedTopics.addAll(topics);
                    _isAnalyzing = false;
                  });
                  debugPrint('AI quiz Generation: Extracted topics: $topics');
                  return;
                } else {
                  debugPrint(
                    'AI quiz Generation Warning: No topics extracted from PDF on attempt $attempts.',
                  );
                  if (attempts >= maxAttempts) {
                    throw Exception(
                      'No topics returned by the extraction service.',
                    );
                  }
                }
              } catch (e) {
                debugPrint(
                  "AI quiz Generation Error: Production AI topic extraction failed on attempt $attempts: $e",
                );
                if (attempts >= maxAttempts) {
                  rethrow;
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
            "AI quiz Generation Error: Production AI topic extraction failed: $e",
          );
        }

        setState(() {
          _selectedPdf = null;
          _detectedTopics.clear();
          _selectedTopics.clear();
          _isAnalyzing = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'AI topic extraction failed. Please try again.',
              ),
              backgroundColor: colors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick PDF file: $e'),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  void _removePdfFile() {
    setState(() {
      _selectedPdf = null;
      _detectedTopics.clear();
      _selectedTopics.clear();
    });
  }

  void _handleSubmit() {
    if (_selectedPdf == null) return;
    Navigator.pop(context, {
      'mcqCount': _mcqCount,
      'checkboxCount': _checkboxCount,
      'openEndedCount': _openEndedCount,
      'relevantToQna': _relevantToQna,
      'fileName': _selectedPdf!.name,
      'fileUrl': _uploadedFileUrl,
      'selectedTopics': _selectedTopics.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget buildCounterItem({
      required IconData icon,
      required Color iconBgColor,
      required Color iconColor,
      required String title,
      required int count,
      required VoidCallback onDecrement,
      required VoidCallback onIncrement,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconBgColor,
              radius: 24,
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: count > 0 ? onDecrement : null,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$count',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: onIncrement,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade100,
                    foregroundColor: Colors.blue.shade800,
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Text(
                    'Number of questions',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      buildCounterItem(
                        icon: Icons.radio_button_checked,
                        iconBgColor: Colors.blue.shade50,
                        iconColor: Colors.blue.shade700,
                        title: 'Multiple Choice',
                        count: _mcqCount,
                        onDecrement: () => setState(() => _mcqCount--),
                        onIncrement: () => setState(() => _mcqCount++),
                      ),
                      const Divider(height: 1, indent: 64, color: Colors.white),
                      buildCounterItem(
                        icon: Icons.check_box_outlined,
                        iconBgColor: Colors.purple.shade50,
                        iconColor: Colors.purple.shade700,
                        title: 'Checkbox',
                        count: _checkboxCount,
                        onDecrement: () => setState(() => _checkboxCount--),
                        onIncrement: () => setState(() => _checkboxCount++),
                      ),
                      const Divider(height: 1, indent: 64, color: Colors.white),
                      buildCounterItem(
                        icon: Icons.text_fields_outlined,
                        iconBgColor: Colors.orange.shade50,
                        iconColor: Colors.orange.shade700,
                        title: 'Open-Ended',
                        count: _openEndedCount,
                        onDecrement: () => setState(() => _openEndedCount--),
                        onIncrement: () => setState(() => _openEndedCount++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Relevant to student Q&A',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Generate questions based on student queries from this session',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _relevantToQna,
                        onChanged: (val) {
                          setState(() {
                            _relevantToQna = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_selectedPdf == null) ...[
                  GestureDetector(
                    onTap: _pickPdfFile,
                    child: CustomPaint(
                      painter: DashedBorderPainter(
                        color: colors.outline.withValues(alpha: 0.5),
                        borderRadius: 20,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add,
                              size: 48,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                'Select a file to upload (Only PDF files are supported currently)',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (_isAnalyzing) ...[
                  Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Uploading & analyzing PDF topics...',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected Topics',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: List.generate(_detectedTopics.length, (
                            index,
                          ) {
                            final topic = _detectedTopics[index];
                            final isSelected = _selectedTopics.contains(topic);
                            return Column(
                              children: [
                                CheckboxListTile(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedTopics.add(topic);
                                      } else {
                                        _selectedTopics.remove(topic);
                                      }
                                    });
                                  },
                                  title: Text(
                                    topic,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  activeColor: colors.primary,
                                  checkboxShape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                ),
                                if (index < _detectedTopics.length - 1)
                                  Divider(
                                    height: 2,
                                    color: Colors.white,
                                  ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _selectedPdf!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _removePdfFile,
                                child: Icon(
                                  Icons.cancel,
                                  size: 18,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _selectedTopics.isNotEmpty
                            ? _handleSubmit
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Generate Questions',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5.0,
    this.dashLength = 5.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
