import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WalletBalanceCard extends StatelessWidget {
  final double currentBalance;
  final double projectedBalance;

  const WalletBalanceCard({
    super.key,
    required this.currentBalance,
    required this.projectedBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)], // Dark Green for Money
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("CURRENT BALANCE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            "\$${currentBalance.toStringAsFixed(2)}",
            style: const TextStyle(
              fontFamily: AppTheme.fontDisplay,
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.0,
            ),
          ).animate().fadeIn().scale(),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white10),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PROJECTED (30 Days)", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    "\$${projectedBalance.toStringAsFixed(2)}",
                    style: const TextStyle(color: AppTheme.fhAccentTeal, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'RobotoMono'),
                  ),
                ],
              ),
              // Icon(MdiIcons.chartLineVariant, color: Colors.white24, size: 32),
            ],
          )
        ],
      ),
    );
  }
}