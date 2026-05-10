import 'package:flutter/foundation.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

mixin FinanceMixin on ChangeNotifier {
  List<FinanceTransaction> _transactions = [];
  List<FinanceCategory> _categories = [];
  List<SavingsGoal> _savingsGoals = [];

  List<FinanceTransaction> get transactions => _transactions;
  List<FinanceCategory> get categories => _categories;
  List<SavingsGoal> get savingsGoals => _savingsGoals;

  // --- Requirements ---
  SyncMixin get sync => this as SyncMixin;

  void setTransactions(List<FinanceTransaction> list) {
    _transactions = List.from(list);
    sync.markDirty('finance');
  }

  void setCategories(List<FinanceCategory> list) {
    _categories = List.from(list);
    sync.markDirty('finance');
  }

  void setSavingsGoals(List<SavingsGoal> list) {
    _savingsGoals = List.from(list);
    sync.markDirty('finance');
  }

  void initializeDefaultFinanceCategories() {
    if (_categories.isEmpty) {
      _categories = [
        FinanceCategory(id: 'cat_salary', name: 'Salary', colorHex: '00F59B', iconName: 'briefcase', isIncomeCategory: true),
        FinanceCategory(id: 'cat_food', name: 'Food', colorHex: 'FF4655', iconName: 'food', isIncomeCategory: false),
        FinanceCategory(id: 'cat_transport', name: 'Transport', colorHex: 'F1C40F', iconName: 'car', isIncomeCategory: false),
        FinanceCategory(id: 'cat_bills', name: 'Utilities', colorHex: '5DADE2', iconName: 'flash', isIncomeCategory: false),
        FinanceCategory(id: 'cat_entertainment', name: 'Entertainment', colorHex: '8A2BE2', iconName: 'gamepad', isIncomeCategory: false),
      ];
    }
  }

  void loadFinanceState(Map<String, dynamic> data) {
    if (data['transactions'] != null) {
      _transactions = (data['transactions'] as List).map((e) => FinanceTransaction.fromJson(e)).toList();
    }
    if (data['categories'] != null) {
      _categories = (data['categories'] as List).map((e) => FinanceCategory.fromJson(e)).toList();
    }
    if (_categories.isEmpty) initializeDefaultFinanceCategories();

    if (data['savingsGoals'] != null) {
      _savingsGoals = (data['savingsGoals'] as List).map((e) => SavingsGoal.fromJson(e)).toList();
    }
  }

  Map<String, dynamic> getFinanceStateMap() {
    return {
      'transactions': _transactions.map((e) => e.toJson()).toList(),
      'categories': _categories.map((e) => e.toJson()).toList(),
      'savingsGoals': _savingsGoals.map((e) => e.toJson()).toList(),
    };
  }
}