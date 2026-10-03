import 'package:flutter/foundation.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

mixin FinanceMixin on ChangeNotifier {
  List<FinanceTransaction> _transactions = [];
  List<FinanceCategory> _categories = [];
  List<SavingsGoal> _savingsGoals = [];
  List<FinanceAccount> _accounts = [];

  List<FinanceTransaction> get transactions => _transactions;
  List<FinanceCategory> get categories => _categories;
  List<SavingsGoal> get savingsGoals => _savingsGoals;
  List<FinanceAccount> get accounts => _accounts;

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

  void setAccounts(List<FinanceAccount> list) {
    _accounts = List.from(list);
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
      final incoming = (data['transactions'] as List).map((e) => FinanceTransaction.fromJson(e)).toList();
      final txMap = <String, FinanceTransaction>{for (final tx in _transactions) tx.id: tx};
      for (final tx in incoming) {
        txMap.putIfAbsent(tx.id, () => tx);
      }
      _transactions = txMap.values.toList();
    }
    if (data['categories'] != null) {
      final incoming = (data['categories'] as List).map((e) => FinanceCategory.fromJson(e)).toList();
      final catMap = <String, FinanceCategory>{for (final c in _categories) c.id: c};
      for (final c in incoming) {
        catMap.putIfAbsent(c.id, () => c);
      }
      _categories = catMap.values.toList();
    }
    if (_categories.isEmpty) initializeDefaultFinanceCategories();

    if (data['savingsGoals'] != null) {
      final incoming = (data['savingsGoals'] as List).map((e) => SavingsGoal.fromJson(e)).toList();
      final sgMap = <String, SavingsGoal>{for (final sg in _savingsGoals) sg.id: sg};
      for (final sg in incoming) {
        sgMap.putIfAbsent(sg.id, () => sg);
      }
      _savingsGoals = sgMap.values.toList();
    }
    if (data['accounts'] != null) {
      final incoming = (data['accounts'] as List).map((e) => FinanceAccount.fromJson(e)).toList();
      final accMap = <String, FinanceAccount>{for (final a in _accounts) a.id: a};
      for (final a in incoming) {
        accMap.putIfAbsent(a.id, () => a);
      }
      _accounts = accMap.values.toList();
    }
  }

  /// Non-destructively merges financial transactions, categories, goals, and accounts.
  int mergeFinanceState(Map<String, dynamic> data) {
    int addedTransactions = 0;
    if (data['transactions'] != null) {
      final incoming = (data['transactions'] as List)
          .whereType<Map>()
          .map((e) => FinanceTransaction.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final txMap = <String, FinanceTransaction>{for (final tx in _transactions) tx.id: tx};
      for (final tx in incoming) {
        if (!txMap.containsKey(tx.id)) {
          txMap[tx.id] = tx;
          addedTransactions++;
        }
      }
      _transactions = txMap.values.toList();
      sync.markDirty('finance');
    }
    if (data['categories'] != null) {
      final incoming = (data['categories'] as List)
          .whereType<Map>()
          .map((e) => FinanceCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final catMap = <String, FinanceCategory>{for (final c in _categories) c.id: c};
      for (final c in incoming) {
        catMap.putIfAbsent(c.id, () => c);
      }
      _categories = catMap.values.toList();
      sync.markDirty('finance');
    }
    if (_categories.isEmpty) initializeDefaultFinanceCategories();

    if (data['savingsGoals'] != null) {
      final incoming = (data['savingsGoals'] as List)
          .whereType<Map>()
          .map((e) => SavingsGoal.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final sgMap = <String, SavingsGoal>{for (final sg in _savingsGoals) sg.id: sg};
      for (final sg in incoming) {
        sgMap.putIfAbsent(sg.id, () => sg);
      }
      _savingsGoals = sgMap.values.toList();
      sync.markDirty('finance');
    }
    if (data['accounts'] != null) {
      final incoming = (data['accounts'] as List)
          .whereType<Map>()
          .map((e) => FinanceAccount.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final accMap = <String, FinanceAccount>{for (final a in _accounts) a.id: a};
      for (final a in incoming) {
        accMap.putIfAbsent(a.id, () => a);
      }
      _accounts = accMap.values.toList();
      sync.markDirty('finance');
    }
    return addedTransactions;
  }

  Map<String, dynamic> getFinanceStateMap() {
    return {
      'transactions': _transactions.map((e) => e.toJson()).toList(),
      'categories': _categories.map((e) => e.toJson()).toList(),
      'savingsGoals': _savingsGoals.map((e) => e.toJson()).toList(),
      'accounts': _accounts.map((e) => e.toJson()).toList(),
    };
  }
}