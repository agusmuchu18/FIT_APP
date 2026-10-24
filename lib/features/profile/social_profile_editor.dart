import 'package:flutter/material.dart';

import 'data/social_identity_client.dart';
import 'profile_controller.dart';
import 'public_profile_screen.dart';

/// Edits the public projection of the existing Firebase UID, never a second account.
class SocialProfileEditor extends StatefulWidget {
  const SocialProfileEditor({super.key, this.client, this.profileController});
  final SocialIdentityClient? client;
  final ProfileController? profileController;
  @override
  State<SocialProfileEditor> createState() => _SocialProfileEditorState();
}

class _SocialProfileEditorState extends State<SocialProfileEditor> {
  late final _client = widget.client ?? SocialIdentityClient.firebase();
  late final _private = widget.profileController ?? ProfileController.instance;
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _handle = TextEditingController();
  final _bio = TextEditingController(),
      _link = TextEditingController(),
      _discipline = TextEditingController();
  bool _ready = false, _busy = false, _public = false, _searchable = false;
  SocialProfile? _saved;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    try {
      await _private.ready;
      var name = _private.displayName.value;
      SocialProfile? profile;
      try {
        profile = await _client.profile(_client.currentUid() ?? '');
      } on SocialFailure catch (e) {
        if (e.code != 'not-found') rethrow;
      }
      if (!mounted) return;
      _saved = profile;
      if (profile != null) name = profile.name;
      _name.text = name == 'USUARIO' ? '' : name;
      _handle.text = profile?.handle ?? '';
      _bio.text = profile?.bio ?? '';
      _link.text = profile?.link ?? '';
      _discipline.text = profile?.discipline ?? '';
      setState(() {
        _public = profile?.visibility == 'public';
        _searchable = profile?.discoverable ?? false;
        _ready = true;
      });
    } on SocialFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save() async {
    if (_busy || !_ready || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final expands =
          (_public && _saved?.visibility != 'public') ||
          (_searchable && !(_saved?.discoverable ?? false));
      if (expands) {
        final consent = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Compartir tu identidad deportiva'),
            content: Text(
              'Se compartirán tu nombre y @usuario${_public ? ', biografía, disciplina y enlace' : ''} según la visibilidad elegida. Tus entrenamientos, fotos, medidas, alimentación y sueño seguirán privados.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Guardar visibilidad'),
              ),
            ],
          ),
        );
        if (consent != true || !mounted) return;
      }
      final result = await _client.saveProfile({
        'displayName': _name.text.trim(),
        'handle': _handle.text.trim(),
        'bio': _bio.text.trim(),
        'link': _link.text.trim(),
        'discipline': _discipline.text.trim(),
        'visibility': _public ? 'public' : 'private',
        'discoverable': _searchable,
      });
      _saved = result;
      try {
        await _private.save(name: result.name);
      } catch (_) {
        if (mounted) {
          setState(
            () => _error = 'La identidad social se guardó. No se pudo actualizar el nombre local; tus datos locales se conservan.',
          );
        }
        return;
      }
      if (mounted) Navigator.pop(context, true);
    } on SocialFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio, _link, _discipline]) {
      c.dispose();
    }
    if (widget.client == null) _client.close();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label,
    int max, {
    bool required = false,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_busy,
      maxLength: max,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
      ),
      validator: (v) => required && (v?.trim().isEmpty ?? true)
          ? 'Completá este campo.'
          : null,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Identidad y privacidad social')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Es tu mismo perfil. Configurar esta identidad no comparte datos de salud ni te incorpora a grupos.',
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (!_ready)
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                const SizedBox(height: 16),
              ],
              if (!_ready && _error == null)
                const Center(child: CircularProgressIndicator()),
              if (_ready) ...[
                _field(_name, 'Nombre visible', 80, required: true),
                _field(
                  _handle,
                  'Nombre de usuario',
                  24,
                  required: true,
                  hint: '3–24 letras a–z, números o _. No cambia tu identidad ni tus registros.',
                ),
                _field(_bio, 'Biografía', 160),
                _field(_discipline, 'Disciplina deportiva', 60),
                _field(_link, 'Enlace personal HTTPS', 300),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Perfil público'),
                  subtitle: const Text(
                    'Si está desactivado, las nuevas personas necesitan tu aprobación para seguirte.',
                  ),
                  value: _public,
                  onChanged: _busy ? null : (v) => setState(() => _public = v),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aparecer en búsquedas'),
                  subtitle: const Text(
                    'Permite encontrarte por nombre o @usuario. Las sugerencias incluyen solo perfiles públicos.',
                  ),
                  value: _searchable,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _searchable = v),
                ),
                const SizedBox(height: 16),
                if (_saved != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person_add_alt_rounded),
                    label: const Text('Solicitudes de seguimiento'),
                    onPressed: _busy
                        ? null
                        : () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => SocialConnections(
                              client: _client,
                              uid: _saved!.uid,
                              type: 'requests',
                            ),
                          ),
                  ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Guardando…' : 'Guardar identidad'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
