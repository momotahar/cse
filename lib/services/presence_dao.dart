import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cse_kch/models/presence_model.dart';

class PresenceDao {
  static const _collection = 'presences';
  final CollectionReference<Map<String, dynamic>> _col = FirebaseFirestore
      .instance
      .collection(_collection);

  /// Ajoute 1 présence (NOUVEAU doc à chaque appel)
  Future<String> add(PresenceModel p) async {
    final doc = await _col.add(p.toMap()); // <- IMPORTANT: add()
    return doc.id;
  }

  /// Ajoute plusieurs présences en une fois (batch)
  Future<void> addMany(List<PresenceModel> items) async {
    if (items.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final p in items) {
      final ref = _col.doc(); // nouveau doc id pour CHAQUE présence
      batch.set(ref, p.toMap());
    }
    await batch.commit();
  }

  /// Supprime une présence par id
  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Met à jour (sécurisé: n’écrase pas l’id)
  Future<void> update(PresenceModel p) async {
    if (p.id == null) throw ArgumentError('Presence.id manquant pour update');
    await _col.doc(p.id).update(p.toMap());
  }

  /// Charge toutes les présences (triables côté UI)
  Future<List<PresenceModel>> fetchAll() async {
    final snap = await _col.get();
    return snap.docs
        .map((d) => PresenceModel.fromMap(d.data(), id: d.id))
        .toList();
  }

  /// Filtre par intervalle de date (si besoin)
  Future<List<PresenceModel>> fetchByDateRange({
    required DateTime from,
    required DateTime to,
  }) async {
    // Comme tes dates/heures sont des strings (dd-MM-yyyy, HH:mm),
    // on récupère tout puis on filtre en mémoire pour rester simple.
    final all = await fetchAll();
    all.retainWhere((p) {
      try {
        final d = _parseUiDate(p.date);
        return !d.isBefore(from) && !d.isAfter(to);
      } catch (_) {
        return false;
      }
    });
    return all;
  }

  DateTime _parseUiDate(String ddMMyyyy) {
    final parts = ddMMyyyy.split('-'); // dd-MM-yyyy
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    return DateTime(y, m, d);
  }
}
