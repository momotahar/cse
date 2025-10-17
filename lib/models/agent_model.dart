import 'package:cse_kch/models/filiale_model.dart';

class AgentModel {
  int? id;
  final String name;
  final String surname;
  final String statut;
  final FilialeModel filiale;
  final DateTime dateAjout;
  final int ordre; // ⬅️ ordre pour le tri/affichage

  AgentModel({
    this.id,
    required this.name,
    required this.surname,
    required this.statut,
    required this.filiale,
    required this.dateAjout,
    this.ordre = 0, // défaut sûr si non renseigné
  });

  bool get isTitulaire => statut.toLowerCase() == 'titulaire';
  bool get isSuppleant => statut.toLowerCase() == 'suppléant';
  bool get peutDonnerAuPot => isTitulaire;

  factory AgentModel.fromMap(Map<String, dynamic> map, FilialeModel filiale) {
    return AgentModel(
      id: map['id'],
      name: map['name'],
      surname: map['surname'],
      statut: map['statut'],
      filiale: filiale,
      dateAjout: DateTime.parse(map['dateAjout']),
      ordre: (map['ordre'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'statut': statut,
      'filiale_id': filiale.id,
      'dateAjout': dateAjout.toIso8601String(),
      'ordre': ordre,
    };
  }

  AgentModel copyWith({
    int? id,
    String? name,
    String? surname,
    String? statut,
    FilialeModel? filiale,
    DateTime? dateAjout,
    int? ordre,
  }) {
    return AgentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      statut: statut ?? this.statut,
      filiale: filiale ?? this.filiale,
      dateAjout: dateAjout ?? this.dateAjout,
      ordre: ordre ?? this.ordre,
    );
  }
}
