import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/social_identity_client.dart';

/// Same UID and authorized projection. Never loads the owner's private statistics.
class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.client,
    required this.uid,
  });
  final SocialIdentityClient client;
  final String uid;
  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<SocialProfile> _profile;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _profile = widget.client.profile(widget.uid);
  }

  Future<void> _action(SocialProfile profile, {bool block = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.client.call({
        'action': block
            ? 'block'
            : profile.relation == 'none'
            ? 'follow'
            : 'unfollow',
        'target': profile.uid,
      });
      if (!mounted) return;
      if (block) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _profile = widget.client.profile(widget.uid));
    } on SocialFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Perfil deportivo')),
    body: SafeArea(
      child: FutureBuilder<SocialProfile>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error is SocialFailure
                          ? (snapshot.error as SocialFailure).message
                          : 'Perfil no disponible.',
                    ),
                    TextButton(
                      onPressed: () => setState(
                        () => _profile = widget.client.profile(widget.uid),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data!, own = profile.relation == 'self';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Semantics(
                header: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(
                    profile.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  subtitle: Text('@${profile.handle}'),
                ),
              ),
              if (profile.visibility == 'private')
                const Text('Perfil privado · seguir requiere aprobación.'),
              if (profile.bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(profile.bio),
                ),
              if (profile.discipline.isNotEmpty) Text(profile.discipline),
              if (profile.link.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: SelectableText(profile.link),
                  trailing: IconButton(
                    tooltip: 'Copiar enlace personal',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: profile.link)),
                  ),
                ),
              if (profile.followers != null)
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SocialConnections(
                          client: widget.client,
                          uid: profile.uid,
                          type: 'followers',
                        ),
                      ),
                      child: Text('${profile.followers} seguidores'),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SocialConnections(
                          client: widget.client,
                          uid: profile.uid,
                          type: 'following',
                        ),
                      ),
                      child: Text('${profile.following} seguidos'),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!own)
                FilledButton(
                  onPressed: _busy ? null : () => _action(profile),
                  child: Text(_busy ? 'Actualizando…' : followLabel(profile)),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Seguir a esta persona no da acceso a sus entrenamientos, fotos, medidas, alimentación o sueño privados.',
                ),
              ),
              if (!own)
                TextButton.icon(
                  icon: const Icon(Icons.block_rounded),
                  label: const Text('Bloquear perfil'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('¿Bloquear a ${profile.name}?'),
                              content: const Text(
                                'Se eliminarán los seguimientos en ambas direcciones. Desbloquear no los restablece.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Bloquear'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && mounted) {
                            await _action(profile, block: true);
                          }
                        },
                ),
            ],
          );
        },
      ),
    ),
  );
}

String followLabel(SocialProfile profile) => switch (profile.relation) {
  'pending' => 'Cancelar solicitud',
  'accepted' => 'Siguiendo',
  'self' => 'Tu perfil',
  _ => profile.visibility == 'private' ? 'Solicitar seguimiento' : 'Seguir',
};

class SocialConnections extends StatefulWidget {
  const SocialConnections({
    super.key,
    required this.client,
    required this.uid,
    required this.type,
  });
  final SocialIdentityClient client;
  final String uid, type;
  @override
  State<SocialConnections> createState() => _SocialConnectionsState();
}

class _SocialConnectionsState extends State<SocialConnections> {
  List<SocialProfile> _items = [];
  String? _cursor, _error;
  bool _loading = false;
  final Set<String> _busy = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.client.connections(
        widget.uid,
        widget.type,
        cursor: append ? _cursor : null,
      );
      if (!mounted) return;
      final merged = {
        if (append)
          for (final p in _items) p.uid: p,
        for (final p in page.items) p.uid: p,
      };
      setState(() {
        _items = merged.values.toList();
        _cursor = page.nextCursor;
      });
    } on SocialFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(SocialProfile profile, bool accept) async {
    if (_loading || !_busy.add(profile.uid)) return;
    setState(() => _error = null);
    try {
      await widget.client.call({
        'action': 'respond',
        'target': profile.uid,
        'accept': accept,
      });
      if (mounted) {
        setState(() => _items.removeWhere((p) => p.uid == profile.uid));
      }
    } on SocialFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(profile.uid));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: 0.85,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(switch (widget.type) {
            'requests' => 'Solicitudes de seguimiento',
            'followers' => 'Seguidores',
            _ => 'Seguidos',
          }, style: Theme.of(context).textTheme.titleLarge),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(append: _items.isNotEmpty),
              child: const Text('Reintentar'),
            ),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No hay personas en esta lista.'),
            ),
          for (final profile in _items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('@${profile.handle}'),
                    if (widget.type == 'requests')
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton(
                            onPressed: _busy.contains(profile.uid)
                                ? null
                                : () => _respond(profile, true),
                            child: const Text('Aceptar'),
                          ),
                          TextButton(
                            onPressed: _busy.contains(profile.uid)
                                ? null
                                : () => _respond(profile, false),
                            child: const Text('Rechazar'),
                          ),
                        ],
                      )
                    else
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => PublicProfileScreen(
                              client: widget.client,
                              uid: profile.uid,
                            ),
                          ),
                        ),
                        child: const Text('Ver perfil'),
                      ),
                  ],
                ),
              ),
            ),
          if (_cursor != null && !_loading)
            TextButton(
              onPressed: () => _load(append: true),
              child: const Text('Cargar más'),
            ),
        ],
      ),
    ),
  );
}
