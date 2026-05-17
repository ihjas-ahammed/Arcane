import 'package:uuid/uuid.dart';

class FinanceAccount {
  String id;
  String name;
  String type; // cash, wallet, gpay, bank, credit, other
  double balance;
  String iconName;
  String colorHex;

  FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.iconName,
    required this.colorHex,
  });

  factory FinanceAccount.fromJson(Map<String, dynamic> json) {
    return FinanceAccount(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Account',
      type: json['type'] as String? ?? 'wallet',
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      iconName: json['iconName'] as String? ?? 'wallet',
      colorHex: json['colorHex'] as String? ?? 'F1C40F',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'balance': balance,
      'iconName': iconName,
      'colorHex': colorHex,
    };
  }
}

class FinanceCategory {
  String id;
  String name;
  String colorHex;
  String iconName;
  bool isIncomeCategory;

  FinanceCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.iconName,
    required this.isIncomeCategory,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    return FinanceCategory(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Unknown',
      colorHex: json['colorHex'] as String? ?? 'FFFFFFFF',
      iconName: json['iconName'] as String? ?? 'circle',
      isIncomeCategory: json['isIncomeCategory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colorHex': colorHex,
      'iconName': iconName,
      'isIncomeCategory': isIncomeCategory,
    };
  }
}

class FinanceTransaction {
  String id;
  double amount;
  bool isIncome;
  String categoryId;
  DateTime timestamp;
  String note;

  FinanceTransaction({
    required this.id,
    required this.amount,
    required this.isIncome,
    required this.categoryId,
    required this.timestamp,
    this.note = '',
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String? ?? const Uuid().v4(),
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      isIncome: json['isIncome'] as bool? ?? false,
      categoryId: json['categoryId'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      note: json['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'isIncome': isIncome,
      'categoryId': categoryId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }
}

class SavingsLog {
  String id;
  double amount;
  DateTime timestamp;

  SavingsLog({
    required this.id,
    required this.amount,
    required this.timestamp,
  });

  factory SavingsLog.fromJson(Map<String, dynamic> json) {
    return SavingsLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class SavingsGoal {
  String id;
  String name;
  String description;
  double targetAmount;
  double currentAmount;
  DateTime targetDate;
  DateTime createdAt;
  String iconName;
  List<SavingsLog> logs;

  SavingsGoal({
    required this.id,
    required this.name,
    this.description = '',
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    required this.createdAt,
    this.iconName = 'target',
    List<SavingsLog>? logs,
  }) : logs = logs ?? [];

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Unknown Goal',
      description: json['description'] as String? ?? '',
      targetAmount: (json['targetAmount'] as num? ?? 100.0).toDouble(),
      currentAmount: (json['currentAmount'] as num? ?? 0.0).toDouble(),
      targetDate: json['targetDate'] != null 
          ? DateTime.parse(json['targetDate']) 
          : DateTime.now().add(const Duration(days: 30)),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      iconName: json['iconName'] as String? ?? 'target',
      logs: (json['logs'] as List<dynamic>?)
              ?.map((e) => SavingsLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'iconName': iconName,
      'logs': logs.map((l) => l.toJson()).toList(),
    };
  }
}