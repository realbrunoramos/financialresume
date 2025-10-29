class ReservedAmount {
  final String id;
  final String sectionId;
  final String description;
  final double amount;
  final DateTime createdAt;

  ReservedAmount({
    required this.id,
    required this.sectionId,
    required this.description,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sectionId': sectionId,
      'description': description,
      'amount': amount,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ReservedAmount.fromMap(Map<String, dynamic> map) {
    return ReservedAmount(
      id: map['id'],
      sectionId: map['sectionId'],
      description: map['description'],
      amount: map['amount'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }
}