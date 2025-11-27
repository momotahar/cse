// lib/models/depot.dart
class Depot {
  final String id;
  final String nom;
  final String adresse;
  final String? ville;
  final String? cp;

  Depot({
    required this.id,
    required this.nom,
    required this.adresse,
    this.ville,
    this.cp,
  });

  Map<String, dynamic> toMap() => {
    'nom': nom,
    'adresse': adresse,
    'ville': ville,
    'cp': cp,
  };

  factory Depot.fromMap(String id, Map<String, dynamic> map) => Depot(
    id: id,
    nom: (map['nom'] ?? '').toString(),
    adresse: (map['adresse'] ?? '').toString(),
    ville: map['ville']?.toString(),
    cp: map['cp']?.toString(),
  );

  @override
  String toString() => nom;
}
