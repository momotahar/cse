// lib/services/incident_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/incident.dart';

const String _kIncidentsCol = 'incidents';

/// Petits DTO pour le dashboard
@immutable
class IncidentArretSplit {
  final int? yes;
  final int? no;
  const IncidentArretSplit({required this.yes, required this.no});
}

@immutable
class IncidentBaseCount {
  final String base;
  final int count;
  const IncidentBaseCount({required this.base, required this.count});
}

class IncidentDAO {
  static final _col = FirebaseFirestore.instance.collection(_kIncidentsCol);

  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // Helpers (non-breaking)
  static Map<String, dynamic> _toFirestore(
    Incident inc, {
    required int id,
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(inc.toMap());
    m['id'] = id;
    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] ??= FieldValue.serverTimestamp();
      m['updated_at'] = FieldValue.serverTimestamp();
    }
    return m;
  }

  static Incident _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);
    return Incident.fromMap(m);
  }

  /// READ: tous les incidents
  static Future<List<Incident>> getAll() async {
    try {
      final snap = await _col.get();
      final list = snap.docs.map(_fromDoc).toList();
      // tri récents -> anciens si created_at dispo
      list.sort((a, b) {
        final ad = a.toMap()['created_at'] as Timestamp?;
        final bd = b.toMap()['created_at'] as Timestamp?;
        if (ad != null && bd != null) return bd.compareTo(ad);
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return list;
    } catch (e, st) {
      debugPrint('IncidentDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// CREATE (API inchangée) — ne renvoie rien
  static Future<void> insert(Incident inc) async {
    try {
      final id = inc.id ?? _genId();
      final data = _toFirestore(inc, id: id, isUpdate: false);
      await _col.doc(id.toString()).set(data);
    } catch (e, st) {
      debugPrint('IncidentDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Variante optionnelle si tu veux récupérer l'ID (nouvelle méthode, non-breaking)
  static Future<int> insertReturningId(Incident inc) async {
    final id = inc.id ?? _genId();
    await _col
        .doc(id.toString())
        .set(_toFirestore(inc, id: id, isUpdate: false));
    return id;
  }

  /// UPDATE (API inchangée)
  static Future<void> update(Incident inc) async {
    if (inc.id == null) throw ArgumentError('update() nécessite un id');
    try {
      final data = _toFirestore(inc, id: inc.id!, isUpdate: true);
      await _col.doc(inc.id.toString()).update(data);
    } catch (e, st) {
      debugPrint('IncidentDAO.update error: $e\n$st');
      rethrow;
    }
  }

  /// DELETE (API inchangée)
  static Future<void> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
    } catch (e, st) {
      debugPrint('IncidentDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  // --- Aides dashboard (inchangées côté appelant) ---
  static Future<IncidentArretSplit> splitArretService() async {
    try {
      final yesSnap = await _col
          .where('arret_service', isEqualTo: true)
          .count()
          .get();
      final noSnap = await _col
          .where('arret_service', isEqualTo: false)
          .count()
          .get();
      return IncidentArretSplit(yes: yesSnap.count, no: noSnap.count);
    } catch (e, st) {
      debugPrint('IncidentDAO.splitArretService error: $e\n$st');
      rethrow;
    }
  }

  static Future<List<IncidentBaseCount>> countByBase() async {
    try {
      final snap = await _col.get();
      final map = <String, int>{};
      for (final d in snap.docs) {
        final base = (d.data()['base'] as String?)?.trim() ?? 'N/A';
        map[base] = (map[base] ?? 0) + 1;
      }
      final out =
          map.entries
              .map((e) => IncidentBaseCount(base: e.key, count: e.value))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));
      return out;
    } catch (e, st) {
      debugPrint('IncidentDAO.countByBase error: $e\n$st');
      rethrow;
    }
  }
}
