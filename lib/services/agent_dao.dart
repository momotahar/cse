import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/agent_model.dart';
import '../models/filiale_model.dart';
import 'filiale_dao.dart';

const String _kAgentsCol = 'agents';

class AgentDAO {
  static final _col = FirebaseFirestore.instance.collection(_kAgentsCol);
  static int _genId() => DateTime.now().millisecondsSinceEpoch;

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
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        final int? id = int.tryParse(d.id) ?? data['id'];
        data['id'] = id;

        final int? filialeId = data['filiale_id'];
        final filiale = (filialeId != null) ? mapFiliales[filialeId] : null;

        if (filiale == null) {
          if (kDebugMode) {
            debugPrint(
              'AgentDAO.getAll: filiale introuvable pour filiale_id=$filialeId (agent id=$id)',
            );
          }
          // On construit tout de même un AgentModel minimal si filiale absente
          return AgentModel(
            id: id,
            name: data['name'] ?? '',
            surname: data['surname'] ?? '',
            statut: data['statut'] ?? '',
            filiale: FilialeModel(
              id: 0,
              abreviation: '—',
              designation: 'Filiale inconnue',
              adresse: '',
              base: '',
            ),
            dateAjout:
                DateTime.tryParse(data['dateAjout'] ?? '') ?? DateTime.now(),
          );
        }

        return AgentModel.fromMap(data, filiale);
      }).toList();
    } catch (e, st) {
      debugPrint('AgentDAO.getAll error: $e\n$st');
      rethrow;
    }
  }

  /// Récupère un agent par id (joint la filiale)
  static Future<AgentModel?> getById(int id) async {
    try {
      final doc = await _col.doc(id.toString()).get();
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] ??= int.tryParse(doc.id);

      final int? filialeId = data['filiale_id'];
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

      return AgentModel.fromMap(data, filiale);
    } catch (e, st) {
      debugPrint('AgentDAO.getById($id) error: $e\n$st');
      return null;
    }
  }

  /// Insert (id auto = timestamp)
  static Future<int> insert(AgentModel a) async {
    try {
      final id = a.id ?? _genId();
      final data = Map<String, dynamic>.from(a.toMap())..['id'] = id;
      await _col.doc(id.toString()).set(data);
      return 1;
    } catch (e, st) {
      debugPrint('AgentDAO.insert error: $e\n$st');
      rethrow;
    }
  }

  /// Update (nécessite id)
  static Future<int> update(AgentModel a) async {
    if (a.id == null) throw ArgumentError('update() nécessite un id');
    try {
      await _col.doc(a.id.toString()).update(a.toMap());
      return 1;
    } catch (e, st) {
      debugPrint('AgentDAO.update error: $e\n$st');
      rethrow;
    }
  }

  /// Delete
  static Future<int> delete(int id) async {
    try {
      await _col.doc(id.toString()).delete();
      return 1;
    } catch (e, st) {
      debugPrint('AgentDAO.delete($id) error: $e\n$st');
      rethrow;
    }
  }

  /// Flux temps réel (optionnel) – join “best effort” basé sur un snapshot initial des filiales.
  static Stream<List<AgentModel>> watchAll() async* {
    // Précharge les filiales pour mapper
    final filiales = await FilialeDAO.getAll();
    final byFiliale = {
      for (final f in filiales)
        if (f.id != null) f.id!: f,
    };

    yield* _col.snapshots().map((q) {
      return q.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        final int? id = int.tryParse(d.id) ?? data['id'];
        data['id'] = id;
        final int? filialeId = data['filiale_id'];
        final filiale = (filialeId != null) ? byFiliale[filialeId] : null;

        return AgentModel.fromMap(
          data,
          filiale ??
              FilialeModel(
                id: 0,
                abreviation: '—',
                designation: 'Filiale inconnue',
                adresse: '',
                base: '',
              ),
        );
      }).toList();
    });
  }
}
