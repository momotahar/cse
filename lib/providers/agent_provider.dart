// lib/providers/agent_provider.dart
import 'package:flutter/foundation.dart';

import 'package:cse_kch/models/agent_model.dart';
import 'package:cse_kch/models/filiale_model.dart';

import 'package:cse_kch/services/agent_dao.dart';
import 'package:cse_kch/services/filiale_dao.dart';

class AgentProvider extends ChangeNotifier {
  bool isLoading = false;
  List<AgentModel> agents = [];

  /// Charge tous les agents (avec leurs filiales)
  Future<void> loadAgents() async {
    isLoading = true;
    notifyListeners();
    try {
      // 1) Récupère d'abord les filiales pour pouvoir hydrater les agents
      final filiales = await FilialeDAO.getAll();
      final Map<int, FilialeModel> byFiliale = {
        for (final f in filiales)
          if (f.id != null) f.id!: f,
      };

      // 2) Charge les agents en résolvant la filiale via la map
      agents = await AgentDAO.getAll(byFiliale: byFiliale); // ✅ FIX
    } catch (e, st) {
      debugPrint('AgentProvider.loadAgents error: $e\n$st');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAgent(AgentModel a) async {
    await AgentDAO.insert(a);
    await loadAgents();
  }

  Future<void> updateAgent(AgentModel a) async {
    await AgentDAO.update(a);
    await loadAgents();
  }

  Future<void> deleteAgent(int id) async {
    await AgentDAO.delete(id);
    await loadAgents();
  }

  AgentModel? getById(int id) {
    try {
      return agents.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filtre utilitaire (réutilisable côté UI)
  List<AgentModel> filter({
    String q = '',
    String? statut, // 'titulaire' / 'suppléant' / null
    int? filialeId,
  }) {
    final qq = q.trim().toLowerCase();
    return agents.where((a) {
      if (statut != null && a.statut.toLowerCase() != statut.toLowerCase()) {
        return false;
      }
      if (filialeId != null && a.filiale.id != filialeId) {
        return false;
      }
      if (qq.isEmpty) return true;
      return a.name.toLowerCase().contains(qq) ||
          a.surname.toLowerCase().contains(qq) ||
          a.filiale.abreviation.toLowerCase().contains(qq) ||
          a.filiale.designation.toLowerCase().contains(qq) ||
          a.statut.toLowerCase().contains(qq);
    }).toList();
  }
}
