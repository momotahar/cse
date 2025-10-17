import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reunion.dart';

class ReunionDao {
  ReunionDao({FirebaseFirestore? firestore})
    : _fs = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _fs;

  CollectionReference<Map<String, dynamic>> get _col =>
      _fs.collection('reunions');

  /// CREATE → retourne l'id créé
  Future<String> add(Reunion r) async {
    final doc = _col.doc();
    final data = r.copyWith(id: doc.id, updatedAt: DateTime.now()).toMap();
    await doc.set(data);
    return doc.id;
  }

  /// UPDATE (id requis)
  Future<void> update(Reunion r) async {
    if (r.id == null) {
      throw ArgumentError('Reunion.update: id manquant');
    }
    await _col.doc(r.id).update(r.copyWith(updatedAt: DateTime.now()).toMap());
  }

  /// DELETE
  Future<void> delete(String id) => _col.doc(id).delete();

  /// READ by id
  Future<Reunion?> getById(String id) async {
    final snap = await _col.doc(id).get();
    if (!snap.exists) return null;
    return Reunion.fromMap(snap.data()!, id: snap.id);
  }

  /// READ range (from/to inclusifs si fournis, sinon tout)
  Future<List<Reunion>> fetchRange({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> q = _col.orderBy('date');
    if (from != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    final res = await q.get();
    return res.docs.map((d) => Reunion.fromMap(d.data(), id: d.id)).toList();
  }

  /// KPI: nombre de réunions sur une année

  Future<int> totalCount({required int year}) async {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year, 12, 31, 23, 59, 59, 999);

    final res = await _col
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .count()
        .get();

    return res.count ?? 0; // <- valeur par défaut si null
  }
}
