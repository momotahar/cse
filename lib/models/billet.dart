// lib/models/billet.dart
class Billet {
  final int? id;
  final String libelle;
  final double prixOriginal;
  final double prixCse;
  final double prixNegos;

  const Billet({
    this.id,
    required this.libelle,
    required this.prixOriginal,
    required this.prixCse,
    required this.prixNegos,
  });

  Billet copyWith({
    int? id,
    String? libelle,
    double? prixOriginal,
    double? prixCse,
    double? prixNegos,
  }) {
    return Billet(
      id: id ?? this.id,
      libelle: libelle ?? this.libelle,
      prixOriginal: prixOriginal ?? this.prixOriginal,
      prixCse: prixCse ?? this.prixCse,
      prixNegos: prixNegos ?? this.prixNegos,
    );
  }

  factory Billet.fromMap(Map<String, dynamic> m) {
    return Billet(
      id: m['id'] as int?,
      libelle: m['libelle'] as String,
      prixOriginal: (m['prix_original'] as num).toDouble(),
      prixCse: (m['prix_cse'] as num).toDouble(),
      prixNegos: (m['prix_negos'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'libelle': libelle,
      'prix_original': prixOriginal,
      'prix_cse': prixCse,
      'prix_negos': prixNegos,
    };
  }
}
