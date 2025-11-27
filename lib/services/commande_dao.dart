// lib/services/commande_dao.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/commande.dart';

const String _kCommandesCol = 'commandes';

class CommandeDAO {
  static final _col = FirebaseFirestore.instance.collection(_kCommandesCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // Helpers
  static Commande _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);
    return Commande.fromMap(m);
  }

  static Map<String, dynamic> _toFirestore(
    Commande c, {
    required int id,
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(c.toMap());
    m['id'] = id;

    // Normalisations défensives (si champ 'date' existe)
    if (m['date'] == null) {
      // optionnel : laisse tel quel si ton modèle gère déjà la date
      m['date'] = FieldValue.serverTimestamp();
    }

    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] ??= FieldValue.serverTimestamp();
    }
    return m;
  }

  // READ
  static Future<List<Commande>> getAll() async {
    try {
      final snap = await _col.get();
      final list = snap.docs.map(_fromDoc).toList();
      // tri défensif (récent -> ancien) si created_at/date présents
      list.sort((a, b) {
        final am = a.toMap();
        final bm = b.toMap();
        final ad = (am['date'] ?? am['created_at']) as Timestamp?;
        final bd = (bm['date'] ?? bm['created_at']) as Timestamp?;
        if (ad != null && bd != null) return bd.compareTo(ad);
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return list;
    } catch (e, st) {
      debugPrint('CommandeDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// Client-side filter (simple, pas d’index requis)
  static Future<List<Commande>> getByMonthYear(int month, int year) async {
    try {
      final all = await getAll();
      return all
          .where((c) => c.date.month == month && c.date.year == year)
          .toList();
    } catch (e, st) {
      debugPrint('CommandeDAO.getByMonthYear($month/$year) error: $e\n$st');
      rethrow;
    }
  }

  static Future<Commande?> getById(int id) async {
    try {
      final d = await _col.doc(id.toString()).get();
      if (!d.exists) return null;
      return _fromDoc(d);
    } catch (e, st) {
      debugPrint('CommandeDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  // WRITE
  static Future<int> insert(Commande c) async {
    try {
      final id = c.id ?? _genId();
      final data = _toFirestore(c, id: id, isUpdate: false);
      await _col.doc(id.toString()).set(data);
      return id; // ✅ renvoie l’ID (cohérent avec tes autres DAO)
    } catch (e, st) {
      debugPrint('CommandeDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> update(Commande c) async {
    if (c.id == null) throw ArgumentError('update() nécessite un id');
    try {
      final data = _toFirestore(c, id: c.id!, isUpdate: true);
      await _col.doc(c.id.toString()).update(data);
      return 1;
    } catch (e, st) {
      debugPrint('CommandeDAO.update error: $e\n$st');
      rethrow;
    }
  }

  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('CommandeDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  // STREAM
  static Stream<List<Commande>> watchAll() {
    try {
      return _col.snapshots().map((q) {
        final list = q.docs.map(_fromDoc).toList()
          ..sort((a, b) {
            final am = a.toMap();
            final bm = b.toMap();
            final ad = (am['date'] ?? am['created_at']) as Timestamp?;
            final bd = (bm['date'] ?? bm['created_at']) as Timestamp?;
            if (ad != null && bd != null) return bd.compareTo(ad);
            return (b.id ?? 0).compareTo(a.id ?? 0);
          });
        return list;
      });
    } catch (e, st) {
      debugPrint('CommandeDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
