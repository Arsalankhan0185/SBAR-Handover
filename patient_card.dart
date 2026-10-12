import 'package:flutter/material.dart';
import '../models/patient.dart';

class Badge extends StatelessWidget {
  final String text;
  final Color color;
  const Badge(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

Color acuityColor(int a) => [Colors.red.shade700, Colors.orange.shade800, Colors.amber.shade700, Colors.green.shade600, Colors.teal][(a - 1).clamp(0, 4)];

class PatientCard extends StatelessWidget {
  final Patient p;
  final VoidCallback onTap;
  const PatientCard(this.p, {super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: acuityColor(p.acuity), width: 6))),
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${p.name}, ${p.age}', style: Theme.of(context).textTheme.titleMedium)),
              Text('${p.room}-${p.bed}', style: Theme.of(context).textTheme.titleMedium),
            ]),
            Text(p.diagnosis),
            Wrap(children: [
              Badge(p.code, p.code == 'DNR' ? Colors.red.shade800 : Colors.blueGrey),
              if (p.fallRisk) Badge('FALL RISK', Colors.orange.shade800),
              if (p.isolation != null) Badge('${p.isolation!.toUpperCase()} ISOL.', Colors.purple),
              for (final a in p.allergies) Badge('ALLERGY: $a', Colors.pink.shade700),
              for (final f in p.flags) Badge('! $f', Colors.red),
            ]),
          ]),
        ),
      ),
    );
  }
}
