class Patient {
  final String id, name, room, bed, code, diagnosis, physician, complaint;
  final int age, acuity;
  final bool fallRisk;
  final String? isolation;
  final List<String> allergies, flags;
  final Map<String, dynamic> vitals;

  Patient.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        room = j['room'],
        bed = j['bed'],
        code = j['code_status'] ?? 'FULL',
        diagnosis = j['diagnosis'] ?? '',
        physician = j['physician'] ?? '',
        complaint = j['chief_complaint'] ?? '',
        age = j['age'],
        acuity = j['acuity'] ?? 3,
        fallRisk = j['fall_risk'] ?? false,
        isolation = j['isolation'],
        allergies = List<String>.from(j['allergies'] ?? []),
        flags = List<String>.from(j['critical_flags'] ?? []),
        vitals = Map<String, dynamic>.from(j['vitals'] ?? {});
}
