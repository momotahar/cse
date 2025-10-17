import 'package:flutter/foundation.dart';
import '../models/commande.dart';
import '../services/commande_dao.dart';

class CommandeProvider with ChangeNotifier {
  List<Commande> _commandes = [];
  bool _isLoading = false;
  String? _error;

  List<Commande> get commandes => _commandes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCommandes({String? q, int? month, int? year}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      List<Commande> base;
      if (month != null && year != null) {
        base = await CommandeDAO.getByMonthYear(month, year);
      } else {
        base = await CommandeDAO.getAll();
      }
      if (q == null || q.trim().isEmpty) {
        _commandes = base;
      } else {
        final s = q.trim().toLowerCase();
        _commandes = base
            .where(
              (c) =>
                  c.agent.toLowerCase().contains(s) ||
                  c.email.toLowerCase().contains(s) ||
                  c.base.toLowerCase().contains(s) ||
                  c.billetLibelle.toLowerCase().contains(s),
            )
            .toList();
      }
    } catch (e, st) {
      _error = 'Erreur chargement: $e';
      debugPrint('CommandeProvider.loadCommandes error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addCommande(Commande c) async {
    try {
      await CommandeDAO.insert(c);
      await loadCommandes();
    } catch (e, st) {
      _error = 'Erreur ajout';
      debugPrint('CommandeProvider.addCommande error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> updateCommande(Commande c) async {
    try {
      await CommandeDAO.update(c);
      await loadCommandes();
    } catch (e, st) {
      _error = 'Erreur mise à jour';
      debugPrint('CommandeProvider.updateCommande error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> deleteCommande(int id) async {
    try {
      await CommandeDAO.delete(id);
      _commandes.removeWhere((x) => x.id == id);
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur suppression';
      debugPrint('CommandeProvider.deleteCommande error: $e\n$st');
      notifyListeners();
    }
  }

  /// Temps réel (optionnel)
  void listenCommandes() {
    try {
      CommandeDAO.watchAll().listen((list) {
        _commandes = list;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('CommandeProvider.listenCommandes error: $e\n$st');
    }
  }
}
