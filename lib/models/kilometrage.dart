class Kilometrage {
  final int? id;
  final int vehiculeId;
  final int mois; // 1 à 12
  final int annee;
  final int kilometrage;

  Kilometrage({
    this.id,
    required this.vehiculeId,
    required this.mois,
    required this.annee,
    required this.kilometrage,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicule_id': vehiculeId,
    'mois': mois,
    'annee': annee,
    'kilometrage': kilometrage,
  };

  factory Kilometrage.fromMap(Map<String, dynamic> map) => Kilometrage(
    id: map['id'],
    vehiculeId: map['vehicule_id'],
    mois: map['mois'],
    annee: map['annee'],
    kilometrage: map['kilometrage'],
  );

  Kilometrage copyWith({
    int? id,
    int? vehiculeId,
    int? mois,
    int? annee,
    int? kilometrage,
  }) {
    return Kilometrage(
      id: id ?? this.id,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      mois: mois ?? this.mois,
      annee: annee ?? this.annee,
      kilometrage: kilometrage ?? this.kilometrage,
    );
  }
}
