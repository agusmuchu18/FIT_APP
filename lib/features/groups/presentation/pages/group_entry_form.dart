import 'package:flutter/material.dart';

/// Controllers live as long as the dialog, including its exit transition.
class GroupEntryForm extends StatefulWidget {
  const GroupEntryForm({super.key, required this.member, required this.onSave});
  final bool member;
  final Future<void> Function(String name, String description) onSave;
  @override
  State<GroupEntryForm> createState() => _GroupEntryFormState();
}

class _GroupEntryFormState extends State<GroupEntryForm> {
  final _name = TextEditingController();
  final _description = TextEditingController(text: 'Atleta');
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá un nombre.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text.trim(), _description.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar. Los datos se conservan; reintentá.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.member ? 'Agregar atleta' : 'Nuevo grupo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.member)
            const Text(
              'Agregás un contacto local. No recibirá una invitación ni tendrá acceso a tus datos.',
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            enabled: !_saving,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: widget.member ? 'Nombre completo' : 'Nombre del grupo',
            ),
          ),
          if (widget.member)
            TextField(
              controller: _description,
              enabled: !_saving,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Disciplina o descripción',
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Guardando…'
                : widget.member
                ? 'Agregar'
                : 'Crear',
          ),
        ),
      ],
    ),
  );
}
