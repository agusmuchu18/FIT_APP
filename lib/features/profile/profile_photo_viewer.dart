import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';

import '../common/theme/app_colors.dart';

/// Visor fullscreen estilo Instagram con blur, acciones y edición in-situ.
class ProfilePhotoViewer extends StatefulWidget {
  const ProfilePhotoViewer({
    super.key,
    required this.displayName,
    required this.avatarBytes,
    required this.onAvatarChanged,
  });

  final String displayName;
  final Uint8List? avatarBytes;
  final ValueChanged<Uint8List?> onAvatarChanged;

  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> {
  final _imagePicker = ImagePicker();
  Uint8List? _currentBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _currentBytes = widget.avatarBytes;
  }

  void _close() {
    Navigator.of(context).pop();
  }

  Future<void> _handleAction(String label) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label (próximamente)')),
    );
  }

  Future<void> _selectImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded),
                title: const Text('Tomar foto'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Elegir de galería'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    await _pickAndCrop(source);
  }

  Future<void> _pickAndCrop(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final cropped = await showGeneralDialog<Uint8List?>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Recortar',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return _AvatarCropperDialog(bytes: bytes);
      },
    );

    if (cropped == null) return;
    await _persistAvatar(cropped);
  }

  Future<void> _persistAvatar(Uint8List bytes) async {
    setState(() => _saving = true);
    // Simulación de guardado para futura integración con Firebase Storage.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    widget.onAvatarChanged(bytes);
    setState(() {
      _currentBytes = bytes;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Foto de perfil actualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = _currentBytes;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 350) {
                    _close();
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.card,
                          ),
                          child: image == null
                              ? const Icon(
                                  Icons.person,
                                  size: 84,
                                  color: AppColors.textMuted,
                                )
                              : ClipOval(
                                  child: Image.memory(
                                    image,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: FloatingActionButton(
                            heroTag: null,
                            onPressed: _saving ? null : _selectImageSource,
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.textPrimary,
                            elevation: 4,
                            mini: true,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                        AppColors.accentSecondary,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.edit_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.send_rounded,
                          label: 'Compartir\nperfil',
                          onTap: () => _handleAction('Compartir perfil'),
                        ),
                        const SizedBox(width: 18),
                        _ActionButton(
                          icon: Icons.link_rounded,
                          label: 'Copiar\nenlace',
                          onTap: () => _handleAction('Copiar enlace'),
                        ),
                        const SizedBox(width: 18),
                        _ActionButton(
                          icon: Icons.qr_code_rounded,
                          label: 'Código QR',
                          onTap: () => _handleAction('Código QR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Icon(icon, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCropperDialog extends StatefulWidget {
  const _AvatarCropperDialog({required this.bytes});

  final Uint8List bytes;

  @override
  State<_AvatarCropperDialog> createState() => _AvatarCropperDialogState();
}

class _AvatarCropperDialogState extends State<_AvatarCropperDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _exporting = false;

  Future<void> _exportCrop() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      setState(() => _exporting = false);
      return;
    }
    final image = await boundary.toImage(pixelRatio: 2.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.of(context).pop(data?.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  Text(
                    'Recortar avatar',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _exporting ? null : _exportCrop,
                    child: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: ClipOval(
                    child: Container(
                      width: 280,
                      height: 280,
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(80),
                        child: Image.memory(
                          widget.bytes,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                'Arrastra y haz zoom para centrar tu avatar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
