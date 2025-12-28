import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/screens/value_detail_screen.dart';
import 'package:arcane/src/widgets/valorant/valorant_value_card.dart'; // New Widget
import 'package:provider/provider.dart';

class ValuesScreen extends StatelessWidget {
  const ValuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final values = provider.lifeValues;

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header resembling Agent Select
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SELECT PROTOCOL",
                  style: TextStyle(
                    fontFamily: AppTheme.fontDisplay,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.fhTextPrimary,
                    height: 0.9,
                    letterSpacing: 2.0
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "DEFINE YOUR CORE DRIVERS // ALIGN YOUR ACTIONS",
                  style: TextStyle(
                    color: AppTheme.fhTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75, // Taller cards for agent look
              ),
              itemCount: values.length,
              itemBuilder: (context, index) {
                final value = values[index];
                return ValorantValueCard(
                  value: value,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ValueDetailScreen(valueId: value.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
