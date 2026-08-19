import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helpers/chat_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late bool _busy;
  late bool _offline;

  @override
  void initState() {
    super.initState();
    final ctrl = context.read<ChatController>();
    _nameCtrl = TextEditingController(text: ctrl.myName);
    _busy = ctrl.busyMode;
    _offline = ctrl.offlineMode;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ctrl = context.read<ChatController>();
    final newName = _nameCtrl.text.trim();
    if (newName.isNotEmpty && newName != ctrl.myName) {
      await ctrl.updateName(newName);
    }
    if (_busy != ctrl.busyMode) await ctrl.setBusy(_busy);
    if (_offline != ctrl.offlineMode) await ctrl.setOffline(_offline);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ChatController>();

    return Scaffold(
      backgroundColor: const Color(0xFF08080c),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d0d14),
        elevation: 0,
        title: const Text(
          'Setări',
          style: TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Salvează',
                style: TextStyle(
                    color: Color(0xFF4ade80), fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1c1c26)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile section
          _SectionLabel(label: 'PROFIL'),
          const SizedBox(height: 10),
          // Avatar display
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF1c1c26),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Center(
                child: Text(
                  ctrl.myName.isNotEmpty
                      ? ctrl.myName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF4ade80),
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FieldLabel(label: 'Numele tău'),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            cursorColor: const Color(0xFF4ade80),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF14141e),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1c1c26)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1c1c26)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF4ade80)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Email: ${ctrl.myEmail}',
            style: const TextStyle(color: Color(0xFF3a3a4a), fontSize: 11),
          ),
          Text(
            'IP: ${ctrl.myIp}:50505',
            style: const TextStyle(color: Color(0xFF3a3a4a), fontSize: 11),
          ),
          const SizedBox(height: 28),

          // Status section
          _SectionLabel(label: 'STATUS'),
          const SizedBox(height: 10),
          _ToggleTile(
            label: 'Modul Ocupat',
            subtitle: 'Apare ca "OCCUPAT" celorlalți',
            value: _busy,
            activeColor: const Color(0xFFef4444),
            onChanged: (v) => setState(() => _busy = v),
          ),
          const SizedBox(height: 10),
          _ToggleTile(
            label: 'Modul Offline',
            subtitle: 'Oprește discovery-ul UDP, nu ești vizibil',
            value: _offline,
            activeColor: const Color(0xFF60606e),
            onChanged: (v) => setState(() => _offline = v),
          ),
          const SizedBox(height: 28),

          // About section
          _SectionLabel(label: 'DESPRE'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0d0d14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1c1c26)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LinkPi Android',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  'Chat LAN peer-to-peer • UDP discovery port 50506 • TCP port 50505\nCompatibil cu LinkPi Windows.',
                  style: TextStyle(color: Color(0xFF60606e), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF4ade80),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: Color(0xFF60606e), fontSize: 12),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0d0d14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1c1c26)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF60606e), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: activeColor,
            inactiveThumbColor: const Color(0xFF60606e),
            inactiveTrackColor: const Color(0xFF1c1c26),
          ),
        ],
      ),
    );
  }
}
