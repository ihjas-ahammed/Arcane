import 'package:flutter/material.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/widgets/cards/life_value_card.dart';
import 'package:arcane/src/screens/value_detail_screen.dart';
import 'package:provider/provider.dart';

class ValuesScreen extends StatelessWidget {
  const ValuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final values = provider.lifeValues;

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: values.length,
        itemBuilder: (context, index) {
          final value = values[index];
          return LifeValueCard(
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
    );
  }
}