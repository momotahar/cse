// lib/services/agent_dao.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agent_model.dart';
import '../models/filiale_model.dart';
import 'filiale_dao.dart';

const String _kAgentsCol = 'agents';

class AgentDAO {
  static final _col = FirebaseFirestore.instance.collection(_kAgentsCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

  // ---------- Helpers ----------
  static AgentModel _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
    Map<int, FilialeModel> byFiliale,
  ) {
    final data = d.data() ?? <String, dynamic>{};
    final m = Map<String, dynamic>.from(data);
    m['id'] ??= int.tryParse(d.id);

    final int? filialeId = m['filiale_id'];
    final filiale = (filialeId != null) ? byFiliale[filialeId] : null;

    return AgentModel.fromMap(
      m,
      filiale ??
          FilialeModel(
            id: 0,
            abreviation: '—',
            designation: 'Filiale inconnue',
            adresse: '',
            base: '',
          ),
    );
  }

  static Map<String, dynamic> _toFirestore(
    AgentModel a, {
    required int id,
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(a.toMap());
    m['id'] = id;

    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] ??= FieldValue.serverTimestamp();
      m['updated_at'] = FieldValue.serverTimestamp();
    }
    return m;
  }

  // ---------- READ ----------
  /// Récupère tous les agents, en joignant leurs filiales.
  /// - Si [byFiliale] est fourni, on l’utilise pour éviter des requêtes en plus.
  static Future<List<AgentModel>> getAll({
    Map<int, FilialeModel>? byFiliale,
  }) async {
    try {
      Map<int, FilialeModel> mapFiliales = byFiliale ?? {};
      if (mapFiliales.isEmpty) {
        final filiales = await FilialeDAO.getAll();
        mapFiliales = {
          for (final f in filiales)
            if (f.id != null) f.id!: f,
        };
      }

      final snap = await _col.get();
      return snap.docs.map((d) => _fromDoc(d, mapFiliales)).toList();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.getAll error: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  /// Récupère un agent par id (joint la filiale)
  static Future<AgentModel?> getById(int id) async {
    try {
      final d = await _col.doc(id.toString()).get();
      if (!d.exists) return null;

      final docData = d.data()!;
      final int? filialeId = docData['filiale_id'];
      FilialeModel? filiale;
      if (filialeId != null) {
        filiale = await FilialeDAO.getById(filialeId);
      }
      filiale ??= FilialeModel(
        id: 0,
        abreviation: '—',
        designation: 'Filiale inconnue',
        adresse: '',
        base: '',
      );

      final m = Map<String, dynamic>.from(docData);
      m['id'] ??= int.tryParse(d.id);
      return AgentModel.fromMap(m, filiale);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.getById($id) error: $e');
        debugPrint(st.toString());
      }
      return null;
    }
  }

  // ---------- WRITE ----------
  /// Insert (id auto = timestamp) — retourne l’ID
  static Future<int> insert(AgentModel a) async {
    try {
      final id = a.id ?? _genId();
      final data = _toFirestore(a, id: id, isUpdate: false);
      await _col.doc(id.toString()).set(data);
      return id;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.insert error: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  /// Update (nécessite id) — retourne 1 si OK
  static Future<int> update(AgentModel a) async {
    if (a.id == null) {
      throw ArgumentError('update() nécessite un id');
    }
    try {
      final data = _toFirestore(a, id: a.id!, isUpdate: true);
      await _col.doc(a.id.toString()).update(data);
      return 1;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.update error: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  /// Delete — retourne 1 si OK
  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.delete($id) error: $e');
        debugPrint(st.toString());
      }
      rethrow;
    }
  }

  // ---------- STREAM ----------
  /// Flux temps réel – join “best effort” basé sur un snapshot initial des filiales.
  static Stream<List<AgentModel>> watchAll() async* {
    try {
      // Précharge les filiales pour mapper
      final filiales = await FilialeDAO.getAll();
      final byFiliale = {
        for (final f in filiales)
          if (f.id != null) f.id!: f,
      };

      yield* _col.snapshots().map(
        (q) => q.docs.map((d) => _fromDoc(d, byFiliale)).toList(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('AgentDAO.watchAll error: $e');
        debugPrint(st.toString());
      }
      // Valeur de secours pour éviter de faire crasher les listeners.
      yield const <AgentModel>[];
    }
  }
}
