// lib/services/billet_dao.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billet.dart';

const String _kBilletsCol = 'billets';

class BilletDAO {
  static final _col = FirebaseFirestore.instance.collection(_kBilletsCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // ---- Garde-fous métier (backend) -----------------------------------------
  static void _guardPrices(Billet b) {
    if (b.prixOriginal < 0 || b.prixNegos < 0 || b.prixCse < 0) {
      throw ArgumentError('Les prix doivent être ≥ 0');
    }
    if (b.prixNegos > b.prixOriginal) {
      throw ArgumentError('Le prix négocié doit être ≤ au prix original');
    }
    if (b.prixCse > b.prixNegos) {
      throw ArgumentError('Le prix CSE doit être ≤ au prix négocié');
    }
  }

  // ---- Mapping helpers -----------------------------------------------------
  static Billet _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);
    return Billet.fromMap(m);
  }

  static Map<String, dynamic> _toFirestore(Billet b, {required int id}) {
    final m = Map<String, dynamic>.from(b.toMap());
    m['id'] = id; // on force l'id (clé doc = id.toString())
    return m;
  }

  /// Récupère tout le catalogue (avec filtre optionnel sur le libellé)
  static Future<List<Billet>> getAll({String? q}) async {
    try {
      // On lit tout puis on filtre côté client (insensible à la casse).
      // (Firestore n’a pas de "contains case-insensitive" simple sans champs normalisés.)
      final snap = await _col.get();
      var list = snap.docs.map(_fromDoc).toList();

      final query = (q ?? '').trim().toLowerCase();
      if (query.isNotEmpty) {
        list = list
            .where((b) => b.libelle.toLowerCase().contains(query))
            .toList();
      }

      // tri par libellé pour un rendu stable
      list.sort(
        (a, b) => a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase()),
      );
      return list;
    } catch (e, st) {
      debugPrint('BilletDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// Récupère un billet par id
  static Future<Billet?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      return _fromDoc(doc);
    } catch (e, st) {
      debugPrint('BilletDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  /// Insert (id auto = timestamp) — retourne l’ID généré
  static Future<int> insert(Billet b) async {
    _guardPrices(b);
    try {
      final id = b.id ?? _genId();
      final data = _toFirestore(b, id: id);
      await _col.doc(id.toString()).set(data);
      return id; // ✅ on renvoie l’id pour que le provider puisse faire copyWith(id)
    } catch (e, st) {
      debugPrint('BilletDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update (nécessite id) — retourne 1 si OK
  static Future<int> update(Billet b) async {
    if (b.id == null) throw ArgumentError('update() nécessite un id');
    _guardPrices(b);
    try {
      // On écrit uniquement les champs du modèle (toMap), Firestore garde l’id en clé doc
      await _col.doc(b.id.toString()).update(b.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('BilletDAO.update error: $e\n$st');
      rethrow;
    }
  }

  /// Delete — retourne 1 si OK
  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('BilletDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  /// Flux temps réel (optionnel)
  static Stream<List<Billet>> watchAll() {
    try {
      return _col.snapshots().map((q) {
        final list = q.docs.map(_fromDoc).toList()
          ..sort(
            (a, b) =>
                a.libelle.toLowerCase().compareTo(b.libelle.toLowerCase()),
          );
        return list;
      });
    } catch (e, st) {
      debugPrint('BilletDAO.watchAll error: $e\n$st');
      rethrow;
    }
  }
}
