import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';
import 'package:missions/src/theme/jwe_theme.dart';
import 'package:provider/provider.dart';

class FinanceDialogs {
  static void showChangeBalanceDialog(
      BuildContext context, FinanceAccount account) {
    final ctrl =
        TextEditingController(text: account.balance.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'CHANGE BALANCE',
            style: GoogleFonts.saira(
              color: JweTheme.accentAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name.toUpperCase(),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: JweTheme.textMuted,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(color: JweTheme.textWhite, fontSize: 22),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: JweTheme.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: JweTheme.onAccent,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text);
                if (val != null) {
                  provider.financeActions.changeAccountBalance(account.id, val);
                }
                Navigator.pop(ctx);
              },
              child: const Text('CONFIRM',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static void showConfirmResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentRed),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'RESET LEDGER',
            style: GoogleFonts.saira(
              color: JweTheme.accentRed,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
          content: Text(
            'This will permanently delete all transaction records. Account balances are not affected.',
            style: GoogleFonts.inter(color: JweTheme.textMid, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentRed,
                foregroundColor: Colors.white,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                provider.financeActions.resetTransactions();
                Navigator.pop(ctx);
              },
              child: const Text('RESET',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static void showSetBudgetDialog(BuildContext context, FinanceCategory cat) {
    final ctrl = TextEditingController(
        text: cat.budget > 0 ? cat.budget.toStringAsFixed(2) : '');
    showDialog(
      context: context,
      builder: (ctx) {
        final provider = Provider.of<AppProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: JweTheme.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: JweTheme.accentAmber),
            borderRadius: BorderRadius.zero,
          ),
          title: Text(
            'SET MONTHLY BUDGET: ${cat.name.toUpperCase()}',
            style: GoogleFonts.saira(
              color: JweTheme.accentAmber,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 13,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter monthly spending limit for this category.',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: JweTheme.textMuted,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: TextStyle(color: JweTheme.textWhite, fontSize: 22),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: JweTheme.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('CANCEL', style: TextStyle(color: JweTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: JweTheme.accentAmber,
                foregroundColor: JweTheme.onAccent,
                shape: const BeveledRectangleBorder(),
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text) ?? 0.0;
                provider.financeActions.updateCategoryBudget(cat.id, val);
                Navigator.pop(ctx);
              },
              child: const Text('SAVE BUDGET',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
