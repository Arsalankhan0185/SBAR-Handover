import 'dart:async';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/api.dart';
import '../widgets/patient_card.dart';
import 'handover_screen.dart';

/// Responsive shell: bottom nav on phones, navigation rail + detail pane on tablet/desktop.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  List<Patient> patients = [];
  Patient? selected;
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    _load();
    sub = api.events().listen((_) => _load()); // live sync: refresh on any ward event
  }

  Future<void> _load() async {
    final p = await api.patients();
    if (mounted) setState(() => patients = p);
  }

  @override
  void dispose() { sub?.cancel(); super.dispose(); }

  void _open(Patient p, bool wide) {
    if (wide) {
      setState(() => selected = p);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => HandoverScreen(p)));
    }
  }

  Widget _patients(bool wide) {
    final list = RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(8), children: [
        if (api.demo) const Card(color: Color(0xFFFFF3CD), child: Padding(padding: EdgeInsets.all(8), child: Text('Demo mode: backend not reachable'))),
        for (final p in patients) PatientCard(p, onTap: () => _open(p, wide)),
      ]),
    );
    if (!wide) return list;
    return Row(children: [
      SizedBox(width: 420, child: list),
      const VerticalDivider(width: 1),
      Expanded(child: selected == null ? const Center(child: Text('Select a patient')) : HandoverScreen(selected!, key: ValueKey(selected!.id), embedded: true)),
    ]);
  }

  Widget _ward() {
    final critical = patients.where((p) => p.flags.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ward monitor', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.extent(
            maxCrossAxisExtent: 220, childAspectRatio: 1.3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            children: [
              for (final p in patients)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.flags.isNotEmpty ? Colors.red.shade50 : Colors.green.shade50,
                    border: Border.all(color: p.flags.isNotEmpty ? Colors.red : Colors.green),
                    borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Bed ${p.room}-${p.bed}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(p.name),
                    Text('SpO2 ${p.vitals['spo2'] ?? '-'}  HR ${p.vitals['hr'] ?? '-'}'),
                    if (p.flags.isNotEmpty) Text(p.flags.join(', '), style: const TextStyle(color: Colors.red)),
                  ]),
                ),
            ],
          ),
        ),
        Text('${critical.length} patient(s) with critical values'),
      ]),
    );
  }

  Widget _alerts() => ListView(children: [
        for (final p in patients)
          for (final f in p.flags)
            ListTile(leading: const Icon(Icons.warning, color: Colors.red), title: Text(f), subtitle: Text('${p.name}  ${p.room}-${p.bed}')),
      ]);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final pages = [_patients(wide), _ward(), _alerts()];
    const dests = [
      (Icons.people, 'My Patients'),
      (Icons.grid_view, 'Ward'),
      (Icons.warning_amber, 'Alerts'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('SBAR Handover'), actions: [
        IconButton(icon: const Icon(Icons.sos, color: Colors.red), tooltip: 'Emergency SOS / Code Blue (stub)', onPressed: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Code Blue'), content: Text('Stub: wire to the hospital paging system.')))),
      ]),
      body: wide
          ? Row(children: [
              NavigationRail(
                selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
                labelType: NavigationRailLabelType.all,
                destinations: [for (final d in dests) NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: pages[tab]),
            ])
          : pages[tab],
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
              destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$1), label: d.$2)]),
    );
  }
}
