class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final double balanceAfter;
  final String type; // reward, savings_deposit, savings_withdrawal, payout, adjustment
  final String status; // pending, completed, failed, reversed
  final String description;
  final String? referenceType;
  final String? referenceId;
  final String? approvedBy;
  final String? bankTransactionId;
  final DateTime createdAt;

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.balanceAfter,
    required this.type,
    required this.status,
    required this.description,
    this.referenceType,
    this.referenceId,
    this.approvedBy,
    this.bankTransactionId,
    required this.createdAt,
  });

  /// Whether this is a credit (positive amount)
  bool get isCredit => amount > 0;

  /// Whether this is a debit (negative amount)
  bool get isDebit => amount < 0;

  /// Absolute amount for display
  double get displayAmount => amount.abs();

  /// Human-readable type label
  String get typeLabel {
    switch (type) {
      case 'reward':
        return 'Reward';
      case 'savings_deposit':
        return 'Savings';
      case 'savings_withdrawal':
        return 'Withdrawal';
      case 'payout':
        return 'Payout';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type;
    }
  }

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      type: json['type'] as String,
      status: json['status'] as String? ?? 'completed',
      description: json['description'] as String,
      referenceType: json['reference_type'] as String?,
      referenceId: json['reference_id'] as String?,
      approvedBy: json['approved_by'] as String?,
      bankTransactionId: json['bank_transaction_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'balance_after': balanceAfter,
      'type': type,
      'status': status,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'approved_by': approvedBy,
      'bank_transaction_id': bankTransactionId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
