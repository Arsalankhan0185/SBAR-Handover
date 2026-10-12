import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/patient.dart';
import '../services/api.dart';
import '../widgets/patient_card.dart';

const systems = ['Neuro', 'Cardiac', 'Resp', 'GI/GU', 'Skin'];

class HandoverScreen extends StatefulWidget {
  final Patient p;
  final bool embedded;
  const HandoverScreen(this.p, {super.key, this.embedded = false});
  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  final id = const Uuid().v4();
  int step = 0;
  bool signed = false;
  final complaint = TextEditingController();
  final pmh = TextEditingController();
  final surgical = TextEditingController();
  final lines = TextEditingController();
  final pending = TextEditingController();
  final discharge = TextEditingController();
  final watch = TextEditingController();
  final meds = TextEditingController();
  final Map<String, bool> reviewed = {for (final s in systems) s: false};
  final Map<String, TextEditingController> sysNotes = {for (final s in systems) s: TextEditingController()};

  @override
  void initState() {
    super.initState();
    complaint.text = widget.p.complaint;
  }

  Map<String, dynamic> _payload() => {
        'id': id,
        'patient_id': widget.p.id,
        'situation': {'complaint': complaint.text, 'code_status': widget.p.code, 'diagnosis': widget.p.diagnosis},
        'background': {'pmh': pmh.text, 'surgical': surgical.text, 'allergies': widget.p.allergies, 'isolation': widget.p.isolation},
        'assessment': {'systems': {for (final s in systems) s: {'reviewed': reviewed[s], 'note': sysNotes[s]!.text}}, 'vitals': widget.p.vitals, 'lines_drips_drains': lines.text},
        'recommendation': {'pending': pending.text, 'discharge': discharge.text, 'watch_outs': watch.text, 'med_times': meds.text},
      };

  bool get _canSign => reviewed.values.every((v) => v);

  Future<void> _submit() async {
    try {
      await api.saveHandover(_payload());
      await api.signOff(id);
      if (!mounted) return;
      setState(() => signed = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Handover saved and signed off')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _field(String label, TextEditingController c, {int lines = 2}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, maxLines: lines, minLines: 1, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.mic_none))), // mic = dictation placeholder
      );

  List<Step> _steps() {
    final p = widget.p;
    return [
      Step(
        title: const Text('S - Situation'), isActive: step >= 0,
        content: Column(children: [
          ListTile(contentPadding: EdgeInsets.zero, title: Text('${p.name}, ${p.age}  |  Room ${p.room}-${p.bed}'), subtitle: Text('${p.diagnosis}  |  ${p.physician}')),
          Align(alignment: Alignment.centerLeft, child: Wrap(children: [Badge(p.code, p.code == 'DNR' ? Colors.red.shade800 : Colors.blueGrey), if (p.fallRisk) Badge('FALL RISK', Colors.orange.shade800)])),
          const SizedBox(height: 8),
          _field('Chief complaint', complaint),
        ]),
      ),
      Step(
        title: const Text('B - Background'), isActive: step >= 1,
        content: Column(children: [
          if (p.allergies.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Allergies: ${p.allergies.join(', ')}', style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 8),
          _field('Past medical history', pmh), _field('Surgical history', surgical),
        ]),
      ),
      Step(
        title: const Text('A - Assessment'), isActive: step >= 2,
        content: Column(children: [
          Align(alignment: Alignment.centerLeft, child: Text('Vitals: HR ${p.vitals['hr']}  BP ${p.vitals['sbp']}/${p.vitals['dbp']}  RR ${p.vitals['rr']}  SpO2 ${p.vitals['spo2']}  T ${p.vitals['temp_c']}  Pain ${p.vitals['pain']}/10')),
          if (p.flags.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text('Critical: ${p.flags.join(', ')}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          for (final s in systems)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero, dense: true, value: reviewed[s], title: Text('$s reviewed'),
              subtitle: TextField(controller: sysNotes[s], decoration: const InputDecoration(hintText: 'Findings', isDense: true)),
              onChanged: (v) => setState(() => reviewed[s] = v ?? false),
            ),
          const SizedBox(height: 8),
          _field('IV lines / drips / drains', lines),
        ]),
      ),
      Step(
        title: const Text('R - Recommendation'), isActive: step >= 3,
        content: Column(children: [
          _field('Pending orders / labs / tests', pending), _field('Discharge / transfer plan', discharge),
          _field('Watch-outs for incoming shift', watch), _field('Scheduled medication times', meds),
          if (!_canSign) const Text('Review all body systems before sign-off.', style: TextStyle(color: Colors.orange)),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: _canSign && !signed ? _submit : null, icon: const Icon(Icons.verified), label: Text(signed ? 'Signed off' : 'Complete handover and sign off')),
        ]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = Stepper(
      currentStep: step,
      onStepTapped: (i) => setState(() => step = i),
      onStepContinue: () => setState(() => step = step < 3 ? step + 1 : step),
      onStepCancel: () => setState(() => step = step > 0 ? step - 1 : 0),
      controlsBuilder: (c, d) => Row(children: [
        if (step < 3) FilledButton(onPressed: d.onStepContinue, child: const Text('Next')),
        const SizedBox(width: 8),
        if (step > 0) TextButton(onPressed: d.onStepCancel, child: const Text('Back')),
      ]),
      steps: _steps(),
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: Text('Handover: ${widget.p.name}')), body: body);
  }
}
