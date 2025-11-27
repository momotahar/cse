class ParametresEntretien {
  final int seuilVidange;
  final int seuilFrein;

  const ParametresEntretien({
    required this.seuilVidange,
    required this.seuilFrein,
  });

  factory ParametresEntretien.fromMap(Map<String, dynamic> data) {
    return ParametresEntretien(
      seuilVidange: data['seuilVidange'] ?? 10000,
      seuilFrein: data['seuilFrein'] ?? 8000,
    );
  }

  Map<String, dynamic> toMap() {
    return {'seuilVidange': seuilVidange, 'seuilFrein': seuilFrein};
  }
}
