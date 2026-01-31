import 'package:flutter/material.dart';
import 'package:arcane/src/models/value_models.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class ValueQuestionCard extends StatelessWidget {
  final ValueQuestion question;
  final String valueId;

  const ValueQuestionCard({
    super.key,
    required this.question,
    required this.valueId,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withOpacity(0.5),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.fhTextSecondary,
                fontSize: 12,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: question.answer,
            maxLines: null,
            style: const TextStyle(
                color: AppTheme.fhTextPrimary,
                fontFamily: 'RobotoMono',
                fontSize: 14),
            decoration: InputDecoration(
              hintText: "INPUT DATA...",
              hintStyle:
                  TextStyle(color: AppTheme.fhTextDisabled.withOpacity(0.5)),
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.black.withOpacity(0.2),
              contentPadding: const EdgeInsets.all(12),
              isDense: true,
            ),
            onChanged: (val) {
              provider.updateValueAnswer(valueId, question.id, val);
            },
          )
        ],
      ),
    );
  }
}