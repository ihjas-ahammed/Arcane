import 'package:uuid/uuid.dart';
import 'package:missions/src/models/finance_models.dart';
import 'package:missions/src/providers/app_provider.dart';

class FinanceActions {
  final AppProvider _provider;

  FinanceActions(this._provider);

  double get currentBalance {
    if (_provider.accounts.isNotEmpty) {
      return _provider.accounts.fold(0.0, (sum, a) => sum + a.balance);
    }
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in _provider.transactions) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
      }
    }
    return totalIncome - totalExpense;
  }

  // --- Accounts ---

  void addAccount(String name, String type, double balance, String iconName, String colorHex) {
    final newAccount = FinanceAccount(
      id: const Uuid().v4(),
      name: name,
      type: type,
      balance: balance,
      iconName: iconName,
      colorHex: colorHex,
    );
    _provider.setProviderState(
      accounts: [..._provider.accounts, newAccount],
    );
  }

  void updateAccount(String id, {String? name, String? type, String? iconName, String? colorHex}) {
    final newAccounts = _provider.accounts.map((a) {
      if (a.id == id) {
        a.name = name ?? a.name;
        a.type = type ?? a.type;
        a.iconName = iconName ?? a.iconName;
        a.colorHex = colorHex ?? a.colorHex;
      }
      return a;
    }).toList();
    _provider.setProviderState(accounts: newAccounts);
  }

  void changeAccountBalance(String id, double newBalance) {
    final newAccounts = _provider.accounts.map((a) {
      if (a.id == id) a.balance = newBalance;
      return a;
    }).toList();
    _provider.setProviderState(accounts: newAccounts);
  }

  void deleteAccount(String id) {
    _provider.setProviderState(
      accounts: _provider.accounts.where((a) => a.id != id).toList(),
    );
  }

  // --- Transactions ---

  void resetTransactions() {
    _provider.setProviderState(transactions: []);
  }

  void addTransaction(double amount, bool isIncome, String categoryId, String note, DateTime date, {String? accountId}) {
    final newTx = FinanceTransaction(
      id: const Uuid().v4(),
      amount: amount,
      isIncome: isIncome,
      categoryId: categoryId,
      timestamp: date,
      note: note,
      accountId: accountId,
    );

    final newTransactions = [..._provider.transactions, newTx]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (accountId != null) {
      final newAccounts = _provider.accounts.map((a) {
        if (a.id == accountId) {
          a.balance += isIncome ? amount : -amount;
        }
        return a;
      }).toList();
      _provider.setProviderState(transactions: newTransactions, accounts: newAccounts);
    } else {
      _provider.setProviderState(transactions: newTransactions);
    }
  }

  void deleteTransaction(String id) {
    final matches = _provider.transactions.where((t) => t.id == id).toList();
    if (matches.isEmpty) return;
    final tx = matches.first;
    final newTransactions = _provider.transactions.where((t) => t.id != id).toList();

    if (tx.accountId != null) {
      final newAccounts = _provider.accounts.map((a) {
        if (a.id == tx.accountId) {
          a.balance += tx.isIncome ? -tx.amount : tx.amount;
        }
        return a;
      }).toList();
      _provider.setProviderState(transactions: newTransactions, accounts: newAccounts);
    } else {
      _provider.setProviderState(transactions: newTransactions);
    }
  }

  // --- Categories ---

  void addCategory(String name, String colorHex, String iconName, bool isIncome) {
    final newCat = FinanceCategory(
      id: const Uuid().v4(),
      name: name,
      colorHex: colorHex,
      iconName: iconName,
      isIncomeCategory: isIncome,
    );

    _provider.setProviderState(
      categories: [..._provider.categories, newCat],
    );
  }

  void deleteCategory(String id) {
    _provider.setProviderState(
      categories: _provider.categories.where((c) => c.id != id).toList(),
    );
  }

  // --- Savings Goals ---

  void addSavingsGoal(String name, String description, double targetAmount, DateTime targetDate, String iconName) {
    final newGoal = SavingsGoal(
      id: const Uuid().v4(),
      name: name,
      description: description,
      targetAmount: targetAmount,
      targetDate: targetDate,
      createdAt: DateTime.now(),
      iconName: iconName,
    );

    _provider.setProviderState(
      savingsGoals: [..._provider.savingsGoals, newGoal],
    );
  }

  void updateSavingsGoal(String id, String name, String description, double targetAmount, DateTime targetDate, String iconName) {
    final newGoals = _provider.savingsGoals.map((g) {
      if (g.id == id) {
        g.name = name;
        g.description = description;
        g.targetAmount = targetAmount;
        g.targetDate = targetDate;
        g.iconName = iconName;
      }
      return g;
    }).toList();

    _provider.setProviderState(savingsGoals: newGoals);
  }

  void deleteSavingsGoal(String id) {
    final goal = _provider.savingsGoals.firstWhere((g) => g.id == id);
    if (goal.currentAmount > 0) {
       addTransaction(
         goal.currentAmount, 
         true, 
         'system_savings_return', 
         'Returned from deleted goal: ${goal.name}', 
         DateTime.now()
       );
    }

    _provider.setProviderState(
      savingsGoals: _provider.savingsGoals.where((g) => g.id != id).toList(),
    );
  }

  void resetSavingsGoalStartDate(String id) {
    final newGoals = _provider.savingsGoals.map((g) {
      if (g.id == id) {
        g.createdAt = DateTime.now();
      }
      return g;
    }).toList();

    _provider.setProviderState(savingsGoals: newGoals);
  }

  void addSavingsLog(String goalId, double amount) {
    if (currentBalance < amount) {
      throw Exception("Insufficient balance to allocate to savings.");
    }

    final newLog = SavingsLog(id: const Uuid().v4(), amount: amount, timestamp: DateTime.now());
    final newGoals = _provider.savingsGoals.map((g) {
      if (g.id == goalId) {
        g.currentAmount += amount;
        g.logs.add(newLog);
        g.logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      return g;
    }).toList();

    addTransaction(
      amount, 
      false, 
      'system_savings_allocation', 
      'Allocated to Goal', 
      DateTime.now()
    );

    _provider.setProviderState(savingsGoals: newGoals);
  }

  void deleteSavingsLog(String goalId, String logId) {
    final newGoals = _provider.savingsGoals.map((g) {
      if (g.id == goalId) {
        final logIndex = g.logs.indexWhere((l) => l.id == logId);
        if (logIndex != -1) {
          final amt = g.logs[logIndex].amount;
          g.currentAmount -= amt;
          g.logs.removeAt(logIndex);

          addTransaction(
            amt, 
            true, 
            'system_savings_return', 
            'Refunded from Goal Log Deletion', 
            DateTime.now()
          );
        }
      }
      return g;
    }).toList();

    _provider.setProviderState(savingsGoals: newGoals);
  }
}