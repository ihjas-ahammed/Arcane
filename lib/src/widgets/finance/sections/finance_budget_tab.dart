import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:missions/src/utils/finance_helpers.dart';
import 'package:missions/src/widgets/dialogs/add_category_dialog.dart';
import 'package:missions/src/widgets/finance/sections/finance_dialogs.dart';
import 'package:missions/src/widgets/ui/hud_components.dart';

class FinanceBudgetTab extends StatelessWidget {
  final AppProvider provider;
  final Color accent;
  final String currency;

  const FinanceBudgetTab({
    super.key,
    required this.provider,
    required this.accent,
    this.currency = '₹',
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final catMTDSpend = <String, double>{};
    for (var t in provider.transactions) {
      if (t.isIncome) continue;
      if (t.timestamp.isBefore(monthStart)) continue;
      catMTDSpend[t.categoryId] = (catMTDSpend[t.categoryId] ?? 0) + t.amount;
    }

    final expenseCategories =
        provider.categories.where((c) => !c.isIncomeCategory).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 900;
    final bottomPadding =
        isLargeScreen ? 0.0 : (0 + MediaQuery.of(context).padding.bottom);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: bottomPadding + 130.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                'MONTHLY BUDGET PLANNER',
                style: GoogleFonts.jetBrainsMono(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expenseCategories.isEmpty)
            Center(
              child: Text(
                'NO EXPENSE CATEGORIES DETECTED',
                style: GoogleFonts.jetBrainsMono(
                  color: JweTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            )
          else
            ...expenseCategories.map((cat) {
              final spent = catMTDSpend[cat.id] ?? 0.0;
              final budget = cat.budget;
              final color = Color(int.parse('0xFF${cat.colorHex}'));
              final isOver = budget > 0 && spent > budget;
              final remaining = budget - spent;
              final progress =
                  budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: HudPanel(
                  clip: HudClip.br,
                  accent: isOver ? JweTheme.accentRed : color,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(FinanceHelpers.getIconData(cat.iconName),
                              color: color, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            cat.name.toUpperCase(),
                            style: GoogleFonts.saira(
                              color: JweTheme.textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => AddCategoryDialog(
                                  isIncome: false,
                                  category: cat,
                                ),
                              );
                            },
                            child: Icon(MdiIcons.pencilOutline,
                                size: 12, color: JweTheme.textMuted),
                          ),
                          const Spacer(),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: color.withValues(alpha: 0.5)),
                              shape: const BeveledRectangleBorder(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () =>
                                FinanceDialogs.showSetBudgetDialog(
                                    context, cat),
                            child: Text(
                              budget > 0 ? 'EDIT LIMIT' : 'SET BUDGET',
                              style: GoogleFonts.jetBrainsMono(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SPENT MTD',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                '$currency${spent.toStringAsFixed(2)}',
                                style: GoogleFonts.saira(
                                  color: JweTheme.textWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                budget > 0 ? 'MONTHLY BUDGET' : 'BUDGET',
                                style: GoogleFonts.jetBrainsMono(
                                  color: JweTheme.textMuted,
                                  fontSize: 8,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                budget > 0
                                    ? '$currency${budget.toStringAsFixed(2)}'
                                    : 'NOT SET',
                                style: GoogleFonts.saira(
                                  color: budget > 0 ? color : JweTheme.textMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (budget > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: HudProgressBar(
                                value: progress * 100,
                                tone: isOver ? HudTone.red : HudTone.cyan,
                                segments: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).round()}%',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver
                                    ? JweTheme.accentRed
                                    : JweTheme.textWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isOver ? 'EXCEEDED BY:' : 'REMAINING:',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver
                                    ? JweTheme.accentRed
                                    : JweTheme.textMuted,
                                fontSize: 9,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '$currency${remaining.abs().toStringAsFixed(2)}',
                              style: GoogleFonts.jetBrainsMono(
                                color: isOver
                                    ? JweTheme.accentRed
                                    : JweTheme.accentTeal,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
