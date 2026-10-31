import 'package:flutter/material.dart';

import '../../../profile/application/profile_discovery_controller.dart';
import '../../../profile/data/social_identity_client.dart';
import '../../../profile/public_profile_screen.dart';
import '../../../profile/social_profile_editor.dart';

class DiscoverProfilesPanel extends StatefulWidget {
  const DiscoverProfilesPanel({super.key, this.client});
  final SocialIdentityClient? client;
  @override
  State<DiscoverProfilesPanel> createState() => _DiscoverProfilesPanelState();
}

class _DiscoverProfilesPanelState extends State<DiscoverProfilesPanel> {
  late final _client = widget.client ?? SocialIdentityClient.firebase();
  late final _controller = ProfileDiscoveryController(_client);
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller.search('', immediate: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Descubrí deportistas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Seguí perfiles sin compartir tus datos privados.'),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: _controller.search,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => _controller.search(value, immediate: true),
          decoration: InputDecoration(
            labelText: 'Buscar perfiles',
            hintText: 'Nombre o @usuario',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      _controller.search('', immediate: true);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.manage_accounts_outlined),
          label: const Text('Mi identidad y privacidad'),
          onPressed: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => SocialProfileEditor(client: _client),
              ),
            );
            if (mounted) _controller.search(_search.text, immediate: true);
          },
        ),
        if (_controller.loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_controller.failure case final failure?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  failure.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                if (failure.code != 'not-enabled')
                  TextButton(
                    onPressed: () =>
                        _controller.search(_search.text, immediate: true),
                    child: const Text('Reintentar'),
                  ),
              ],
            ),
          ),
        if (!_controller.loading &&
            _controller.failure == null &&
            _controller.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _search.text.trim().isEmpty
                  ? 'Todavía no hay perfiles públicos para sugerir.'
                  : 'No encontramos perfiles con esa búsqueda.',
            ),
          ),
        for (final profile in _controller.items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(profile.name),
                    subtitle: Text('@${profile.handle}'),
                    onTap: () async {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(
                            client: _client,
                            uid: profile.uid,
                          ),
                        ),
                      );
                      if (mounted) {
                        _controller.search(_search.text, immediate: true);
                      }
                    },
                  ),
                  if (profile.bio.isNotEmpty) Text(profile.bio),
                  if (profile.discipline.isNotEmpty) Text(profile.discipline),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _controller.pending.contains(profile.uid)
                        ? null
                        : () => _controller.toggleFollow(profile),
                    child: Text(
                      _controller.pending.contains(profile.uid)
                          ? 'Actualizando…'
                          : followLabel(profile),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_controller.loadingMore) const LinearProgressIndicator(),
        if (_controller.nextCursor != null && !_controller.loadingMore)
          TextButton(
            onPressed: _controller.more,
            child: const Text('Cargar más perfiles'),
          ),
      ],
    ),
  );
}
