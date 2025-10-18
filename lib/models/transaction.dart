class Transaction {
  final String id;
  final double amount;
  final String entity;
  final String description;
  final bool isCredit;
  final DateTime date;
  final List<String> receiptPaths;
  final String sectionId;
  final String? docType;
  final String? monthRef;
  final DateTime? dueDate;
  final bool paid;

  Transaction({
    required this.id,
    required this.amount,
    required this.entity,
    required this.description,
    required this.isCredit,
    required this.date,
    required this.receiptPaths,
    required this.sectionId,
    this.docType,
    this.monthRef,
    this.dueDate,
    this.paid = false,
  });

  Transaction copyWith({
    String? id,
    double? amount,
    String? entity,
    String? description,
    bool? isCredit,
    DateTime? date,
    List<String>? receiptPaths,
    String? sectionId,
    String? docType,
    String? monthRef,
    DateTime? dueDate,
    bool? paid,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      entity: entity ?? this.entity,
      description: description ?? this.description,
      isCredit: isCredit ?? this.isCredit,
      date: date ?? this.date,
      receiptPaths: receiptPaths ?? this.receiptPaths,
      sectionId: sectionId ?? this.sectionId,
      docType: docType ?? this.docType,
      monthRef: monthRef ?? this.monthRef,
      dueDate: dueDate ?? this.dueDate,
      paid: paid ?? this.paid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'entity': entity,
      'description': description,
      'isCredit': isCredit ? 1 : 0,
      'date': date.toIso8601String(),
      'receiptPaths': receiptPaths.join(','),
      'sectionId': sectionId,
      'docType': docType,
      'monthRef': monthRef,
      'dueDate': dueDate?.toIso8601String(),
      'paid': paid ? 1 : 0,
    };
  }

  static Transaction fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      entity: map['entity'] ?? '',
      description: map['description'] ?? '',
      isCredit: map['isCredit'] == 1,
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      receiptPaths: map['receiptPaths'] != null
          ? (map['receiptPaths'] as String).split(',').where((s) => s.isNotEmpty).toList()
          : [],
      sectionId: map['sectionId'] ?? '',
      docType: map['docType'],
      monthRef: map['monthRef'],
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate']) : null,
      paid: map['paid'] == 1,
    );
  }
}