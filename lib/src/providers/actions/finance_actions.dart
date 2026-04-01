import 'package:uuid/uuid.dart';
import 'package:arcane/src/models/finance_models.dart';
import 'package:arcane/src/providers/app_provider.dart';

class FinanceActions {
  final AppProvider _provider;

  FinanceActions(this._provider);

  double get currentBalance {
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

  // --- Transactions ---

  void addTransaction(double amount, bool isIncome, String categoryId, String note, DateTime date) {
    final newTx = FinanceTransaction(
      id: const Uuid().v4(),
      amount: amount,
      isIncome: isIncome,
      categoryId: categoryId,
      timestamp: date,
      note: note,
    );

    _provider.setProviderState(
      transactions: [..._provider.transactions, newTx]..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
    );
  }

  void deleteTransaction(String id) {
    _provider.setProviderState(
      transactions: _provider.transactions.where((t) => t.id != id).toList(),
    );
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