/// SyncService — offline-first sync engine (SQLite ↔ Firestore).
///
/// ┌──────────────┐  write  ┌──────────────┐  processPendingQueue  ┌───────────┐
/// │ Any screen   │────────▶│ DatabaseSvc  │──────────────────────▶│ Firestore │
/// └──────────────┘         │ + sync_queue │◀──────────────────────│           │
///                          └──────────────┘     fullSync (pull)    └───────────┘
///
/// Design principles:
/// • SQLite is ALWAYS the source of truth — reads never touch Firestore.
/// • Firestore is an async mirror; all push operations are fire-and-forget.
/// • [processPendingQueue] is idempotent and safe to call frequently.
/// • All Firestore errors are caught and logged; they never crash the app.
/// • The service is a no-op ([isReady] == false) when the user is signed out.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/reserved_amount.dart';
import '../models/section.dart';
import '../models/transaction.dart' as trns;
import 'database_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final DatabaseService _db = DatabaseService();

  FirebaseFirestore? _fs;
  String?            _uid;
  bool               _syncing = false;

  static const _colSections = 'sections';
  static const _colTx       = 'transactions';
  static const _colReserved = 'reserved_amounts';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Called immediately after a successful Firebase sign-in.
  void init(String userId) {
    _uid     = userId;
    _fs      = FirebaseFirestore.instance;
    // Enable offline persistence (Firestore caches reads when offline).
    _fs!.settings = const Settings(persistenceEnabled: true);
    debugPrint('[SyncService] Initialised for uid=$userId');
  }

  /// Called on sign-out. All subsequent operations are no-ops.
  void dispose() {
    _uid     = null;
    _fs      = null;
    _syncing = false;
    debugPrint('[SyncService] Disposed');
  }

  bool get isReady => _uid != null && _fs != null;

  // ── Firestore helpers ──────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _fs!.collection('users').doc(_uid!).collection(name);

  DocumentReference<Map<String, dynamic>> _configDoc() =>
      _fs!.collection('users').doc(_uid!).collection('config').doc('settings');

  // ══════════════════════════════════════════════════════════════════════════
  // QUEUE PROCESSING  (local sync_queue → Firestore)
  // ══════════════════════════════════════════════════════════════════════════

  /// Reads all pending items from the local [sync_queue] table and pushes
  /// each one to Firestore.  Safe to call frequently — returns immediately
  /// when [isReady] is false or a sync is already in progress.
  Future<void> processPendingQueue() async {
    if (!isReady || _syncing) return;

    final items = await _db.getPendingSyncItems();
    if (items.isEmpty) return;

    _syncing = true;
    try {
      for (final item in items) {
        await _processItem(item);
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _processItem(Map<String, dynamic> item) async {
    final queueId    = item['id']         as String;
    final collection = item['entityType'] as String;
    final entityId   = item['entityId']   as String;
    final operation  = item['operation']  as String;
    final attempts   = (item['attempts']  as int?) ?? 0;

    // Drop after 5 consecutive failures to avoid an infinite retry loop.
    if (attempts >= 5) {
      debugPrint('[SyncService] Dropping $entityId after 5 failures');
      await _db.removeSyncItem(queueId);
      return;
    }

    try {
      final ref = _col(collection).doc(entityId);

      if (operation == 'delete') {
        // Soft-delete: mark as deleted in Firestore (keeps audit trail).
        await ref.set({
          'deleted':   true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        final raw     = jsonDecode(item['payload'] as String) as Map<String, dynamic>;
        final payload = _sanitiseForFirestore(collection, raw);
        payload['deleted']   = false;
        payload['updatedAt'] = FieldValue.serverTimestamp();
        await ref.set(payload, SetOptions(merge: true));
      }

      await _db.removeSyncItem(queueId);
    } catch (e) {
      debugPrint('[SyncService] Push failed for $entityId (attempt ${attempts + 1}): $e');
      await _db.incrementSyncAttempts(queueId);
    }
  }

  /// Transforms a raw SQLite map into a Firestore-safe map.
  /// • Converts SQLite integer booleans (0/1) to Dart booleans.
  /// • Strips local-only fields (receipt file paths).
  /// • Converts ISO strings to Firestore Timestamps.
  Map<String, dynamic> _sanitiseForFirestore(
    String collection,
    Map<String, dynamic> raw,
  ) {
    final out = Map<String, dynamic>.from(raw);

    if (collection == _colTx) {
      // SQLite stores booleans as integers.
      out['isCredit'] = raw['isCredit'] == 1 || raw['isCredit'] == true;
      out['paid']     = raw['paid']     == 1 || raw['paid']     == true;
      // Receipt paths are device-local; don't sync them.
      out.remove('receiptPaths');
    }

    // Convert ISO-8601 date strings to Firestore Timestamps so they are
    // queryable.  Leave null fields as null.
    for (final key in ['date', 'dueDate', 'createdAt']) {
      final v = out[key];
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) out[key] = Timestamp.fromDate(dt);
      }
    }

    return out;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FULL SYNC  (sign-in → pull Firestore → merge into SQLite → push local)
  // ══════════════════════════════════════════════════════════════════════════

  /// Full bidirectional sync.  Typically called once after sign-in.
  /// • Pull: downloads Firestore records that don't exist locally.
  /// • Push: uploads local records that are pending or new to Firestore.
  Future<void> fullSync() async {
    if (!isReady) return;
    debugPrint('[SyncService] Full sync started');

    try {
      // Pull phase — runs in parallel for speed.
      await Future.wait([
        _pullSections(),
        _pullTransactions(),
        _pullReservedAmounts(),
      ]);

      // Push phase — upload everything local (merge semantics, no overwrites).
      await _pushAllLocal();

      debugPrint('[SyncService] Full sync complete');
    } catch (e) {
      debugPrint('[SyncService] Full sync error: $e');
    }
  }

  // ── Pull helpers ──────────────────────────────────────────────────────────

  Future<void> _pullSections() async {
    try {
      final snap = await _col(_colSections)
          .where('deleted', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['deleted'] == true) continue;
        // Only insert if the record doesn't exist locally.
        final local = await _db.getSectionById(doc.id);
        if (local != null) continue;

        await _db.addSection(Section(
          id:        (d['id'] as String?)    ?? doc.id,
          name:      (d['name'] as String?)  ?? '',
          createdAt: _parseTs(d['createdAt']),
        ));
      }
    } catch (e) {
      debugPrint('[SyncService] _pullSections error: $e');
    }
  }

  Future<void> _pullTransactions() async {
    try {
      final snap = await _col(_colTx)
          .where('deleted', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['deleted'] == true) continue;
        final local = await _db.getTransactionById(doc.id);
        if (local != null) continue;

        await _db.addTransaction(_txFromFirestore(d, doc.id));
      }
    } catch (e) {
      debugPrint('[SyncService] _pullTransactions error: $e');
    }
  }

  Future<void> _pullReservedAmounts() async {
    try {
      final snap = await _col(_colReserved)
          .where('deleted', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        final d = doc.data();
        if (d['deleted'] == true) continue;
        final local = await _db.getReservedAmountById(doc.id);
        if (local != null) continue;

        await _db.insertReservedAmount(ReservedAmount(
          id:          (d['id'] as String?)          ?? doc.id,
          sectionId:   (d['sectionId'] as String?)   ?? '',
          description: (d['description'] as String?) ?? '',
          amount:      (d['amount'] as num?)?.toDouble() ?? 0.0,
          createdAt:   _parseTs(d['createdAt']),
        ));
      }
    } catch (e) {
      debugPrint('[SyncService] _pullReservedAmounts error: $e');
    }
  }

  // ── Push helper ────────────────────────────────────────────────────────────

  /// Uploads all local records to Firestore using merge semantics (existing
  /// Firestore records are only updated if they conflict with local data).
  /// Uses Firestore [WriteBatch] groups of ≤ 499 ops to respect the limit.
  Future<void> _pushAllLocal() async {
    try {
      final sections = await _db.getAllSectionsRaw();
      final txs      = await _db.getAllTransactionsRaw();
      final ras      = await _db.getAllReservedAmountsRaw();

      WriteBatch batch = _fs!.batch();
      int ops = 0;

      Future<void> flush() async {
        if (ops == 0) return;
        await batch.commit();
        batch = _fs!.batch();
        ops   = 0;
      }

      void addOp(DocumentReference ref, Map<String, dynamic> data) {
        batch.set(ref, data, SetOptions(merge: true));
        if (++ops >= 499) unawaited(flush());
      }

      for (final s in sections) {
        addOp(_col(_colSections).doc(s['id'] as String), {
          ...s,
          'deleted':   false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      for (final tx in txs) {
        final payload = _sanitiseForFirestore(_colTx, tx);
        addOp(_col(_colTx).doc(tx['id'] as String), {
          ...payload,
          'deleted':   false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      for (final ra in ras) {
        addOp(_col(_colReserved).doc(ra['id'] as String), {
          ...ra,
          'deleted':   false,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': _parseTs(ra['createdAt']),
        });
      }

      await flush();

      // All local data is now in Firestore — clear the pending queue.
      await _db.clearSyncQueue();
    } catch (e) {
      debugPrint('[SyncService] _pushAllLocal error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SETTINGS SYNC
  // ══════════════════════════════════════════════════════════════════════════

  /// Pushes non-sensitive settings (theme, language) to Firestore.
  /// Keys excluded from sync: geminiApiKey, biometricEnabled.
  Future<void> pushSettings(Map<String, String> settings) async {
    if (!isReady) return;
    try {
      final safe = Map<String, String>.from(settings)
        ..remove('geminiApiKey')
        ..remove('biometricEnabled');

      if (safe.isEmpty) return;
      await _configDoc().set(safe, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[SyncService] pushSettings error: $e');
    }
  }

  /// Pulls non-sensitive settings from Firestore and merges into SQLite.
  Future<void> pullSettings() async {
    if (!isReady) return;
    try {
      final snap = await _configDoc().get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      for (final entry in data.entries) {
        if (entry.key == 'geminiApiKey') continue;
        if (entry.key == 'biometricEnabled') continue;
        await _db.saveSetting(entry.key, entry.value.toString());
      }
    } catch (e) {
      debugPrint('[SyncService] pullSettings error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INCREMENTAL SYNC  (periodic delta)
  // ══════════════════════════════════════════════════════════════════════════

  /// Processes the pending queue (catches anything missed since last run).
  /// Call from [AppDataProvider.invalidate] or on app resume.
  Future<void> incrementalSync() => processPendingQueue();

  // ══════════════════════════════════════════════════════════════════════════
  // WIPE USER DATA FROM FIRESTORE
  // ══════════════════════════════════════════════════════════════════════════

  /// Deletes all Firestore documents belonging to the current user.
  /// Called when the user deletes their account.
  Future<void> wipeRemoteData() async {
    if (!isReady) return;
    try {
      final userDoc = _fs!.collection('users').doc(_uid!);
      for (final col in [_colSections, _colTx, _colReserved, 'config']) {
        final snap = await userDoc.collection(col).get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
      await userDoc.delete();
    } catch (e) {
      debugPrint('[SyncService] wipeRemoteData error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESTORE FROM CLOUD  (new device / re-install)
  // ══════════════════════════════════════════════════════════════════════════

  /// Downloads all Firestore data and inserts it into a fresh local DB.
  /// Same as [fullSync] pull phase — included as a named entry point for UX.
  Future<void> restoreFromCloud() => fullSync();

  // ── Helpers ────────────────────────────────────────────────────────────────

  DateTime _parseTs(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int)       return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String)    return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  trns.Transaction _txFromFirestore(Map<String, dynamic> d, String docId) {
    return trns.Transaction(
      id:              (d['id'] as String?)          ?? docId,
      amount:          (d['amount'] as num?)?.toDouble() ?? 0.0,
      entity:          (d['entity'] as String?)      ?? '',
      description:     (d['description'] as String?) ?? '',
      isCredit:        (d['isCredit'] as bool?)      ?? false,
      date:            _parseTs(d['date']),
      receiptPaths:    [], // local paths are not synced
      sectionId:       (d['sectionId'] as String?)   ?? '',
      docType:          d['docType']         as String?,
      monthRef:         d['monthRef']        as String?,
      dueDate:         d['dueDate'] != null ? _parseTs(d['dueDate']) : null,
      paid:            (d['paid'] as bool?)          ?? false,
      numeroSerie:      d['numeroSerie']     as String?,
      metodoPagamento:  d['metodoPagamento'] as String?,
    );
  }
}

/// Discards the future result.  Use for truly fire-and-forget async calls
/// where the result is intentionally ignored.
void unawaited(Future<void> future) {
  future.ignore();
}
