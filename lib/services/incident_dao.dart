import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/incident.dart';

const String _kIncidentsCol = 'incidents';

/// Petits DTO pour le dashboard
@immutable
class IncidentArretSplit {
  final int yes;
  final int no;
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

  /// Récupère tous les incidents
  static Future<List<Incident>> getAll() async {
    try {
      final snap = await _col.get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['id'] ??= int.tryParse(d.id);
        return Incident.fromMap(data);
      }).toList();
    } catch (e, st) {
      debugPrint('IncidentDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// Insert (id auto = timestamp)
  static Future<void> insert(Incident inc) async {
    try {
      final id = inc.id ?? _genId();
      final data = Map<String, dynamic>.from(inc.copyWith(id: id).toMap());
      await _col.doc(id.toString()).set(data);
    } catch (e, st) {
      debugPrint('IncidentDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update (nécessite id)
  static Future<void> update(Incident inc) async {
    if (inc.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(inc.id.toString()).update(inc.toMap());
    } catch (e, st) {
      debugPrint('IncidentDAO.update error: $e\n$st');
      rethrow;
    }
  }

  /// Delete
  static Future<void> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
    } catch (e, st) {
      debugPrint('IncidentDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }
}
