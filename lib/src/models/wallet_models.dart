import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:arcane/src/theme/app_theme.dart';

enum TransactionType { income, expense }

class WalletTransaction {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final String note;
  final DateTime date;
  final String feeling; // 'Good', 'Bad', 'Neutral', 'Necessary'
  final bool isFuture; // Planned/Recurring future transaction

  WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    this.note = '',
    required this.date,
    this.feeling = 'Neutral',
    this.isFuture = false,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String? ?? const Uuid().v4(),
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: json['category'] as String? ?? 'General',
      note: json['note'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      feeling: json['feeling'] as String? ?? 'Neutral',
      isFuture: json['isFuture'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'feeling': feeling,
      'isFuture': isFuture,
    };
  }

  Color get feelingColor {
    switch (feeling.toLowerCase()) {
      case 'good': return AppTheme.fhAccentGreen;
      case 'bad': case 'regret': return AppTheme.fhAccentRed;
      case 'necessary': return AppTheme.fhAccentGold;
      default: return AppTheme.fhTextSecondary;
    }
  }

  IconData get categoryIcon {
    switch (category.toLowerCase()) {
      case 'food': return MdiIcons.food;
      case 'transport': return MdiIcons.trainCar;
      case 'tech': return MdiIcons.laptop;
      case 'entertainment': return MdiIcons.gamepadVariant;
      case 'salary': return MdiIcons.cashMultiple;
      case 'bills': return MdiIcons.fileDocumentOutline;
      default: return MdiIcons.circleSmall;
    }
  }
}