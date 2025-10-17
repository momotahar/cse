import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/depense.dart';

/// Petit POJO pour le dashboard (fournisseur -> total)
class DepenseSupplierSum {
  final String fournisseur;
  final double total;
  DepenseSupplierSum(this.fournisseur, this.total);
}

class DepenseDao {
  final FirebaseFirestore _fs;
  DepenseDao({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('depenses');

  /// Ajoute et renvoie l’id Firestore
  Future<String> add(Depense d) async {
    final data = d.toMap()..remove('id');
    final doc = await _col.add(data);
    return doc.id;
  }

  Future<void> update(Depense d) async {
    if (d.id == null) throw ArgumentError('id nul pour update');
    final data = d.toMap()..remove('id');
    await _col.doc(d.id).update(data);
  }

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  /// Récupère toutes les dépenses (à éviter si beaucoup de données)
  Future<List<Depense>> fetchAll() async {
    final snap = await _col.orderBy('date_iso').get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Récupère par intervalle [from,to] (inclus). Si null => pas de borne.
  Future<List<Depense>> fetchRange({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> q = _col;
    // On interroge sur la chaîne ISO pour profiter de l’ordre lexical == chrono
    if (from != null) {
      q = q.where('date_iso', isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      // Inclusif : on ajoute un z à la fin si besoin (mais ISO suffit)
      q = q.where('date_iso', isLessThanOrEqualTo: to.toIso8601String());
    }
    q = q.orderBy('date_iso');
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Somme annuelle (via requête range)
  Future<double> totalAmount({required int year}) async {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59, 999);
    final items = await fetchRange(from: from, to: to);
    return items.fold<double>(0.0, (s, d) => s + d.montantTtc);
  }

  /// Nombre de factures sur l’année
  Future<int> invoiceCount({required int year}) async {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59, 999);
    final items = await fetchRange(from: from, to: to);
    return items.length;
  }

  /// Répartition par fournisseur pour un (year, month)
  Future<List<DepenseSupplierSum>> sumBySupplier({
    required int year,
    required int month,
  }) async {
    final from = DateTime(year, month, 1);
    final to = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    final items = await fetchRange(from: from, to: to);

    final map = <String, double>{};
    for (final d in items) {
      final key = d.fournisseur.trim();
      map.update(key, (v) => v + d.montantTtc, ifAbsent: () => d.montantTtc);
    }
    final list =
        map.entries.map((e) => DepenseSupplierSum(e.key, e.value)).toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Depense _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data();
    // Injecte le docId comme 'id' pour la factory fromMap
    final withId = <String, Object?>{...m, 'id': doc.id};
    return Depense.fromMap(withId);
  }
}
