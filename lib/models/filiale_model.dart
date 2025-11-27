class FilialeModel {
  int? id;
  final String abreviation;
  final String designation;
  final String adresse;
  final String base;

  FilialeModel({
    this.id,
    required this.abreviation,
    required this.designation,
    required this.adresse,
    required this.base,
  });

  factory FilialeModel.fromMap(Map<String, dynamic> map) {
    return FilialeModel(
      id: map['id'],
      abreviation: map['abreviation'],
      designation: map['designation'],
      adresse: map['adresse'] ?? '',
      base: map['base'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'abreviation': abreviation,
      'designation': designation,
      'adresse': adresse,
      'base': base,
    };
  }

  FilialeModel copyWith({
    int? id,
    String? abreviation,
    String? designation,
    String? adresse,
    String? base,
  }) {
    return FilialeModel(
      id: id ?? this.id,
      abreviation: abreviation ?? this.abreviation,
      designation: designation ?? this.designation,
      adresse: adresse ?? this.adresse,
      base: base ?? this.base,
    );
  }
}
