// lib/models/vehicule.dart
class Vehicule {
  final int? id;
  final String immatriculation;
  final String? dateEntree;
  final String? marque;
  final String? modele;
  final String? baseGeo; // ex: base nord, ouest, sud…
  final String? collaborateur;
  final String? statut;
  final String? prochainCtTech;

  Vehicule({
    this.id,
    required this.immatriculation,
    this.dateEntree,
    this.marque,
    this.modele,
    this.baseGeo,
    this.collaborateur,
    this.statut,
    this.prochainCtTech,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'immatriculation': immatriculation,
    'date_entree': dateEntree,
    'marque': marque,
    'modele': modele,
    'base_geographique': baseGeo,
    'collaborateur': collaborateur,
    'statut': statut,
    'prochain_ct': prochainCtTech,
  };

  factory Vehicule.fromMap(Map<String, dynamic> map) => Vehicule(
    id: map['id'],
    immatriculation: map['immatriculation'] ?? '',
    dateEntree: map['date_entree'],
    marque: map['marque'],
    modele: map['modele'],
    baseGeo: map['base_geographique'],
    collaborateur: map['collaborateur'],
    statut: map['statut'],
    prochainCtTech: map['prochain_ct'],
  );
}
