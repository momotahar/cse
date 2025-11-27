class Kilometrage {
  final String id;
  final String vehiculeId;
  final String mois; // ex: "2025-11"
  final int km;

  Kilometrage({
    required this.id,
    required this.vehiculeId,
    required this.mois,
    required this.km,
  });

  factory Kilometrage.fromMap(String id, Map<String, dynamic> data) {
    return Kilometrage(
      id: id,
      vehiculeId: data['vehiculeId'],
      mois: data['mois'],
      km: data['km'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'vehiculeId': vehiculeId, 'mois': mois, 'km': km};
  }
}
