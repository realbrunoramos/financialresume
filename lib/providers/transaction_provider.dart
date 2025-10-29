import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

class TransactionProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  List<Transaction> _transactions = [];
  bool _isLoading = false;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;

  Future<void> loadTransactions(String sectionId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _dbService.getAllTransactions(sectionId);
    } catch (e) {
      print('Erro ao carregar transações: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(Transaction transaction) async {
    try {
      await _dbService.addTransaction(transaction);
      await loadTransactions(transaction.sectionId);
    } catch (e) {
      print('Erro ao adicionar transação: $e');
      rethrow;
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      await _dbService.updateTransaction(transaction);
      await loadTransactions(transaction.sectionId);
    } catch (e) {
      print('Erro ao atualizar transação: $e');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id, String sectionId) async {
    try {
      await _dbService.deleteTransaction(id);
      await loadTransactions(sectionId);
    } catch (e) {
      print('Erro ao eliminar transação: $e');
      rethrow;
    }
  }

  void clearTransactions() {
    _transactions = [];
    notifyListeners();
  }
}