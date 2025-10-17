class Entretien {
  final int? id;
  final int vehiculeId;
  final String type; // vidange, pneus, CT, freins, etc.
  final String? note;

  // Planification (un des deux peut être null)
  final String? datePrevue; // 'dd/MM/yyyy'
  final int? kmPrevus;

  // Réalisation
  final String? dateFaite; // 'dd/MM/yyyy'
  final int? kmFaits;

  Entretien({
    this.id,
    required this.vehiculeId,
    required this.type,
    this.note,
    this.datePrevue,
    this.kmPrevus,
    this.dateFaite,
    this.kmFaits,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'vehicule_id': vehiculeId,
    'type': type,
    'note': note,
    'date_prevue': datePrevue,
    'km_prevus': kmPrevus,
    'date_faite': dateFaite,
    'km_faits': kmFaits,
  };

  factory Entretien.fromMap(Map<String, dynamic> m) => Entretien(
    id: m['id'],
    vehiculeId: m['vehicule_id'],
    type: m['type'],
    note: m['note'],
    datePrevue: m['date_prevue'],
    kmPrevus: m['km_prevus'],
    dateFaite: m['date_faite'],
    kmFaits: m['km_faits'],
  );

  Entretien copyWith({
    int? id,
    int? vehiculeId,
    String? type,
    String? note,
    String? datePrevue,
    int? kmPrevus,
    String? dateFaite,
    int? kmFaits,
  }) {
    return Entretien(
      id: id ?? this.id,
      vehiculeId: vehiculeId ?? this.vehiculeId,
      type: type ?? this.type,
      note: note ?? this.note,
      datePrevue: datePrevue ?? this.datePrevue,
      kmPrevus: kmPrevus ?? this.kmPrevus,
      dateFaite: dateFaite ?? this.dateFaite,
      kmFaits: kmFaits ?? this.kmFaits,
    );
  }
}
