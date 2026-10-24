import 'social_profile_editor.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../common/theme/app_colors.dart';
import 'profile_controller.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, this.controller});
  final ProfileController? controller;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late final _profile = widget.controller ?? ProfileController.instance;
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _saving = false, _ready = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _profile.ready;
    if (!mounted) return;
    setState(() {
      _ready = _profile.failure.value == null;
      _nameController.text = _profile.displayName.value;
      _error = _profile.failure.value;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    if (_saving || !_ready) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.length > ProfileController.maxAvatarBytes) {
          throw ArgumentError('Imagen demasiado grande');
        }
        await _profile.save(avatar: bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar la foto. Elegí una imagen de menos de 300 KB y reintentá.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveChanges() async {
    if (_saving || !_ready) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _profile.save(name: _nameController.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil guardado en esta cuenta')),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo guardar. Revisá el nombre y reintentá. No se sobrescriben datos ilegibles.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Ajustes de perfil',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_ready && _error == null) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!_ready && _error != null)
            TextButton(
              onPressed: () async {
                await _profile.retryRestore();
                await _load();
              },
              child: const Text('Reintentar lectura del perfil'),
            ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Tu nombre y avatar se guardan de forma privada en esta cuenta. No crean un perfil público.',
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Foto de perfil',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ValueListenableBuilder(
                      valueListenable: _profile.avatarBytes,
                      builder: (context, bytes, _) {
                        return CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.accentSecondary
                              .withOpacity(0.2),
                          backgroundImage: bytes == null
                              ? null
                              : MemoryImage(bytes),
                          child: bytes == null
                              ? const Icon(
                                  Icons.person,
                                  color: AppColors.accentSecondary,
                                  size: 28,
                                )
                              : null,
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || !_ready ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_camera_back_rounded),
                        label: const Text('Agregar foto'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nombre visible',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  maxLength: 80,
                  enabled: _ready && !_saving,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'USUARIO',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.accentSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Identidad y privacidad social'),
            onPressed: _saving || !_ready
                ? null
                : () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SocialProfileEditor(profileController: _profile),
                      ),
                    );
                    if (updated == true && mounted) {
                      _nameController.text = _profile.displayName.value;
                    }
                  },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving || !_ready ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentSecondary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Guardar cambios',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
