/// AppDataProvider — single source of truth for section list + total balance.
///
/// Any screen that mutates sections or transactions must call [invalidate]
/// after the DB write.  HomeScreen listens via `Consumer<AppDataProvider>` and
/// rebuilds automatically — no Navigator.pop callbacks, no manual _reload().
library;

import 'package:flutter/foundation.dart';
import '../models/section.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class AppDataProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Section> _sections     = [];
  double        _totalBalance = 0.0;
  bool          _loading      = false;
  bool          _initialized  = false;

  List<Section> get sections     => _sections;
  double        get totalBalance => _totalBalance;
  bool          get loading      => _loading;
  bool          get initialized  => _initialized;

  /// Called once from [main.dart] via `..init()`.
  Future<void> init() => refresh();

  /// Re-fetches section list + total balance from SQLite, then notifies
  /// listeners so that any `Consumer<AppDataProvider>` rebuilds.
  ///
  /// Concurrent calls are debounced: if a refresh is already in flight the
  /// call returns immediately without queuing a second one.
  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    // Keep stale data visible while the new data is loading — only hide on
    // the very first load (before _initialized is true).
    notifyListeners();
    try {
      // Run both queries in parallel for speed.
      final sectionsFut = _db.getAllSections();
      final balanceFut  = _db.getTotalBalance();
      _sections         = await sectionsFut;
      _totalBalance     = await balanceFut;
      _initialized      = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Alias for [refresh].  Call this after **any** data mutation: add, edit,
  /// or delete transaction, section, or reserved amount.
  ///
  /// Also triggers an incremental cloud sync (processes the local sync queue)
  /// when the user is signed in.  The sync runs fire-and-forget so it never
  /// blocks the UI update.
  Future<void> invalidate() async {
    await refresh();
    // Fire-and-forget: no-op when Firebase is not configured or user is offline.
    SyncService.instance.incrementalSync().ignore();
  }
}
