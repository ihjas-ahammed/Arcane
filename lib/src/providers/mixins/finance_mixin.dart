import 'package:flutter/foundation.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/mixins/sync_mixin.dart';

mixin FinanceMixin on ChangeNotifier {
  List<FinanceTransaction> _transactions = [];
  List<FinanceCategory> _categories = [];
  List<SavingsGoal> _savingsGoals = [];
  List<FinanceAccount> _accounts = [];

  void resetFinanceState() {
    _transactions = [];
    _categories = [];
    _savingsGoals = [];
    _accounts = [];
  }

  List<FinanceTransaction> get transactions => _transactions;
  List<FinanceCategory> get categories => _categories;
  List<SavingsGoal> get savingsGoals => _savingsGoals;
  List<FinanceAccount> get accounts => _accounts;

  // --- Requirements ---
  SyncMixin get sync => this as SyncMixin;

  void setTransactions(List<FinanceTransaction> list) {
    sync.recordDeletions('transactions', _transactions.map((e) => e.id), list.map((e) => e.id));
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
      _transactions = sync.parseItems('transactions', data['transactions'], FinanceTransaction.fromJson);
    }
    if (data['categories'] != null) {
      _categories = sync.parseItems('categories', data['categories'], FinanceCategory.fromJson);
    }
    if (data['categories'] == null && _categories.isEmpty) initializeDefaultFinanceCategories();

    if (data['savingsGoals'] != null) {
      _savingsGoals = sync.parseItems('savingsGoals', data['savingsGoals'], SavingsGoal.fromJson);
    }
    if (data['accounts'] != null) {
      _accounts = sync.parseItems('accounts', data['accounts'], FinanceAccount.fromJson);
    }
  }

  /// Non-destructively merges financial transactions, categories, goals, and accounts.
  int mergeFinanceState(Map<String, dynamic> data) {
    sync.mergeRemoteTombstones(data);
    _transactions.removeWhere((e) => sync.isDeletedRecord('transactions', e.id));
    int addedTransactions = 0;
    if (data['transactions'] != null) {
      final incoming = sync.parseItems('transactions', data['transactions'], FinanceTransaction.fromJson);
      final txMap = <String, FinanceTransaction>{for (final tx in _transactions) tx.id: tx};
      for (final tx in incoming) {
        if (sync.isDeletedRecord('transactions', tx.id)) continue;
        if (txMap.containsKey(tx.id)) sync.preserveMergeConflict('transactions', tx.id, txMap[tx.id]!.toJson(), tx.toJson());
        if (!txMap.containsKey(tx.id)) {
          txMap[tx.id] = tx;
          addedTransactions++;
        }
      }
      _transactions = txMap.values.toList();
      sync.markDirty('finance');
    }
    if (data['categories'] != null) {
      final incoming = sync.parseItems('categories', data['categories'], FinanceCategory.fromJson);
      final catMap = <String, FinanceCategory>{for (final c in _categories) c.id: c};
      for (final c in incoming) {
        if (catMap.containsKey(c.id)) sync.preserveMergeConflict('categories', c.id, catMap[c.id]!.toJson(), c.toJson());
        catMap.putIfAbsent(c.id, () => c);
      }
      _categories = catMap.values.toList();
      sync.markDirty('finance');
    }
    if (_categories.isEmpty) initializeDefaultFinanceCategories();

    if (data['savingsGoals'] != null) {
      final incoming = sync.parseItems('savingsGoals', data['savingsGoals'], SavingsGoal.fromJson);
      final sgMap = <String, SavingsGoal>{for (final sg in _savingsGoals) sg.id: sg};
      for (final sg in incoming) {
        if (sgMap.containsKey(sg.id)) sync.preserveMergeConflict('savingsGoals', sg.id, sgMap[sg.id]!.toJson(), sg.toJson());
        sgMap.putIfAbsent(sg.id, () => sg);
      }
      _savingsGoals = sgMap.values.toList();
      sync.markDirty('finance');
    }
    if (data['accounts'] != null) {
      final incoming = sync.parseItems('accounts', data['accounts'], FinanceAccount.fromJson);
      final accMap = <String, FinanceAccount>{for (final a in _accounts) a.id: a};
      for (final a in incoming) {
        if (accMap.containsKey(a.id)) sync.preserveMergeConflict('accounts', a.id, accMap[a.id]!.toJson(), a.toJson());
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
