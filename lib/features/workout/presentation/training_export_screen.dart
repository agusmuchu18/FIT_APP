import '../../../app/theme/app_theme.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/training_export.dart';

typedef TrainingImageSharer = Future<ShareResult> Function(
  Uint8List bytes,
  Rect origin,
);

class TrainingExportScreen extends StatefulWidget {
  const TrainingExportScreen({super.key, required this.data, this.sharer});
  final TrainingExportData data;
  final TrainingImageSharer? sharer;
  @override
  State<TrainingExportScreen> createState() => _TrainingExportScreenState();
}

class _TrainingExportScreenState extends State<TrainingExportScreen> {
  final _capture = GlobalKey();
  late final Set<String> _selected = widget.data.defaults;
  var _busy = false;
  String? _error;
  Future<void> _share(BuildContext button) async {
    if (_busy || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !button.mounted) return;
      final boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      late Uint8List bytes;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) throw StateError('Imagen no disponible');
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } finally {
        image.dispose();
      }
      if (!mounted || !button.mounted) return;
      final box = button.findRenderObject()! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      final result = await (widget.sharer ?? _shareNative)(bytes, rect);
      if (mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen enviada a la opción que elegiste.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo crear o compartir la imagen. Tu información se conserva. Reintentá.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ShareResult> _shareNative(Uint8List bytes, Rect origin) =>
      SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['fitup-entrenamiento.png'],
          sharePositionOrigin: origin,
          title: 'Mi entrenamiento en FIT_APP',
        ),
      );
  @override
  Widget build(BuildContext context) => Theme(
    data: AppTheme.workoutFor(Theme.of(context)),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear tarjeta')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Elegí qué mostrar',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'La vista previa contiene únicamente los campos seleccionados. Las notas privadas quedan excluidas al abrir esta pantalla.',
        ),
        const Text(
          'La tarjeta resume cada sección en hasta 8 registros. Los textos extensos se abrevian visualmente.',
        ),
        for (final section in widget.data.sections.where(
          (s) => s.lines.isNotEmpty,
        ))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(section.title),
            subtitle: section.private
                ? const Text('Privado · solo se incluye si lo activás')
                : null,
            value: _selected.contains(section.id),
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    if (v == true) {
                      _selected.add(section.id);
                    } else {
                      _selected.remove(section.id);
                    }
                  }),
          ),
        const SizedBox(height: 16),
        Text(
          'Vista previa · PNG de 1080 px de ancho',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: RepaintBoundary(
                key: _capture,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.noScaling,
                    disableAnimations: true,
                  ),
                  child: _ExportCard(data: widget.data, selected: _selected),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        Builder(
          builder: (button) => FilledButton.icon(
            onPressed: _busy || _selected.isEmpty ? null : () => _share(button),
            icon: const Icon(Icons.ios_share_outlined),
            label: Text(
              _busy ? 'Preparando imagen…' : 'Crear imagen y compartir',
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.data, required this.selected});
  final TrainingExportData data;
  final Set<String> selected;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fitness_center,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text('FIT_APP', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            data.kind,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          for (final section in data.sections.where(
            (s) => selected.contains(s.id) && s.lines.isNotEmpty,
          )) ...[
            const SizedBox(height: 20),
            Text(section.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in section.lines.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(line, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            if (section.lines.length > 8)
              Text('Mostrando 8 de ${section.lines.length} registros.'),
          ],
          if (data.points.isNotEmpty && selected.contains('evolution')) ...[
            const SizedBox(height: 24),
            Text(data.metricLabel ?? 'Evolución'),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < data.points.length; i++)
                          FlSpot(i.toDouble(), data.points[i].value),
                      ],
                      color: Theme.of(context).colorScheme.primary,
                      isCurved: false,
                      dotData: FlDotData(show: data.points.length < 20),
                    ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ),
            Text(
              '${DateFormat.yMd('es').format(data.points.first.date)} – ${DateFormat.yMd('es').format(data.points.last.date)}',
            ),
            const Text('Resultados observados en orden cronológico.'),
          ],
        ],
      ),
    ),
  );
}
