import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:intl/intl.dart';

class TaskInfoCard extends StatelessWidget {
  final String description;
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskInfoCard({
    super.key,
    required this.description,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.fhBgDark.withOpacity(0.5),
        border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRecurring) ...[
            Row(
              children: [
                Icon(Icons.cached, color: AppTheme.fhAccentTeal, size: 16),
                const SizedBox(width: 8),
                const Text("RECURRING PROTOCOL", style: TextStyle(color: AppTheme.fhAccentTeal, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          
          if (description.isNotEmpty) ...[
            const Text("BRIEFING", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: AppTheme.fhTextPrimary, height: 1.4, fontSize: 13)),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateItem("INITIATED", createdAt),
              _buildDateItem("LAST UPDATE", updatedAt),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDateItem(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(DateFormat('MMM dd, yyyy').format(date), style: const TextStyle(color: AppTheme.fhTextSecondary, fontSize: 11, fontFamily: 'RobotoMono')),
      ],
    );
  }
}