import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/patient.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000');

/// Demo data used when the backend is unreachable.
final _demo = <Map<String, dynamic>>[
  {'id': 'p1', 'name': 'Ali Khan', 'age': 67, 'room': '101', 'bed': 'A', 'diagnosis': 'Pneumonia', 'physician': 'Dr. Sana', 'code_status': 'FULL', 'chief_complaint': 'Shortness of breath', 'fall_risk': true, 'isolation': 'Contact', 'allergies': ['Penicillin'], 'acuity': 2, 'critical_flags': ['SpO2 91%'], 'vitals': {'hr': 102, 'sbp': 118, 'dbp': 72, 'rr': 24, 'spo2': 91, 'temp_c': 38.4, 'pain': 3}},
  {'id': 'p3', 'name': 'John Smith', 'age': 81, 'room': '103', 'bed': 'A', 'diagnosis': 'CHF exacerbation', 'physician': 'Dr. Sana', 'code_status': 'DNR', 'chief_complaint': 'Leg swelling', 'fall_risk': true, 'allergies': ['Sulfa'], 'acuity': 1, 'critical_flags': ['K+ 6.2'], 'vitals': {'hr': 96, 'sbp': 98, 'dbp': 60, 'rr': 20, 'spo2': 93, 'temp_c': 36.8, 'pain': 1}},
  {'id': 'p2', 'name': 'Maria Gomez', 'age': 54, 'room': '102', 'bed': 'B', 'diagnosis': 'Post-op cholecystectomy', 'physician': 'Dr. Imran', 'code_status': 'FULL', 'chief_complaint': 'Incision pain', 'allergies': [], 'acuity': 4, 'critical_flags': ['Hb 8.1'], 'vitals': {'hr': 78, 'sbp': 124, 'dbp': 80, 'rr': 16, 'spo2': 98, 'temp_c': 36.9, 'pain': 4}},
];

class Api {
  String? token;
  bool demo = false;

  Future<void> login(String user, String pass) async {
    try {
      final r = await http.post(Uri.parse('$apiBase/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': user, 'password': pass}));
      if (r.statusCode != 200) throw Exception('Login failed');
      token = jsonDecode(r.body)['token'];
      demo = false;
    } on http.ClientException {
      demo = true; // backend unreachable
    }
  }

  Map<String, String> get _h => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  Future<List<Patient>> patients() async {
    if (demo) return _demo.map(Patient.fromJson).toList();
    final r = await http.get(Uri.parse('$apiBase/patients'), headers: _h);
    return (jsonDecode(r.body) as List).map((e) => Patient.fromJson(e)).toList();
  }

  Future<void> saveHandover(Map<String, dynamic> body) async {
    if (demo) return;
    final r = await http.post(Uri.parse('$apiBase/handovers'), headers: _h, body: jsonEncode(body));
    if (r.statusCode == 409) throw Exception('Handover changed on another device. Reload and merge.');
    if (r.statusCode >= 400) throw Exception('Save failed (${r.statusCode})');
  }

  Future<void> signOff(String id) async {
    if (demo) return;
    await http.post(Uri.parse('$apiBase/handovers/$id/signoff'), headers: _h);
  }

  /// Emits a tick whenever the server reports a change in the ward.
  Stream<dynamic> events() {
    if (demo || token == null) return const Stream.empty();
    final ws = WebSocketChannel.connect(Uri.parse('${apiBase.replaceFirst('http', 'ws')}/ws?token=$token'));
    return ws.stream.map(jsonDecode);
  }
}

final api = Api();
