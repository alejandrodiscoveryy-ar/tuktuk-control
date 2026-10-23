import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'marketplace_identity_geometry.dart';

/// Visor propio solo para el carné en Android. La foto no se envía ni guarda
/// de forma permanente aquí; vuelve al flujo de subida existente únicamente
/// cuando el conductor pulsa «Usar esta foto».
Future<Uint8List?> captureGuidedMarketplaceIdentityPhoto(
  BuildContext context,
  String side,
) {
  if (!Platform.isAndroid) return Future<Uint8List?>.value(null);
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      fullscreenDialog: true,
      builder: (_) => _IdentityCameraScreen(side: side),
    ),
  );
}

class _IdentityCameraScreen extends StatefulWidget {
  const _IdentityCameraScreen({required this.side});

  final String side;

  @override
  State<_IdentityCameraScreen> createState() => _IdentityCameraScreenState();
}

class _IdentityCameraScreenState extends State<_IdentityCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Uint8List? _captured;
  bool _busy = false;
  String? _error;
  int _generation = 0;
  Size? _lastViewport;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openCamera();
  }

  Future<void> _openCamera() async {
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (!mounted || generation != _generation) return;
      if (cameras.isEmpty) throw StateError('No hay cámara disponible');
      final back = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      final selected = back.isNotEmpty ? back.first : cameras.first;
      final controller = CameraController(
        selected,
        ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() => _error = null);
    } on CameraException catch (error) {
      if (!mounted || generation != _generation) return;
      final old = _controller;
      _controller = null;
      if (old != null) await old.dispose();
      if (!mounted) return;
      setState(() => _error = error.code == 'CameraAccessDenied'
          ? 'Permite el acceso a la cámara en los ajustes de Android.'
          : 'No se pudo abrir la cámara. Cancela y elige la galería.');
    } catch (_) {
      if (!mounted || generation != _generation) return;
      final old = _controller;
      _controller = null;
      if (old != null) await old.dispose();
      if (!mounted) return;
      setState(() =>
          _error = 'No se pudo abrir la cámara. Cancela y elige la galería.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ++_generation;
      final old = _controller;
      _controller = null;
      if (old != null) old.dispose();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _captured == null) {
      _openCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ++_generation;
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    final viewport = _lastViewport;
    if (_busy ||
        controller == null ||
        !controller.value.isInitialized ||
        viewport == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final photo = await controller.takePicture();
      late final Uint8List raw;
      try {
        raw = await photo.readAsBytes();
      } finally {
        // camera almacena temporalmente el JPEG: se borra tras leerlo.
        try {
          await File(photo.path).delete();
        } catch (_) {
          // En algunos dispositivos la ruta temporal ya se ha eliminado.
        }
      }
      final decoded = img.decodeImage(raw);
      if (decoded == null) throw const FormatException('Imagen ilegible');
      final oriented = img.bakeOrientation(decoded);
      final crop = cropMarketplaceIdentityToFrame(
        orientedPhoto: oriented,
        viewport: viewport,
        frame: marketplaceIdentityFrame(viewport),
      );
      final result = Uint8List.fromList(img.encodeJpg(crop, quality: 94));
      if (!mounted) return;
      setState(() {
        _captured = result;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo tomar la foto. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.side == 'back'
        ? 'Carné · Parte trasera'
        : 'Carné · Parte delantera';
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    return Scaffold(
      backgroundColor: const Color(0xFF070F19),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF070F19),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              const Text(
                'Coloca las cuatro esquinas del carné dentro del marco verde. '
                'Evita los reflejos y comprueba que los datos se lean.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      if (size.width <= 0 || size.height <= 0) {
                        return const SizedBox.shrink();
                      }
                      _lastViewport = size;
                      final previewSize =
                          ready ? controller.value.previewSize : null;
                      final previewAspect = ready && previewSize != null
                          ? previewSize.height / previewSize.width
                          : 0.5625;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.black),
                          if (_captured != null)
                            Image.memory(_captured!, fit: BoxFit.contain)
                          else if (ready)
                            ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: 1000 * previewAspect,
                                  height: 1000,
                                  child: CameraPreview(controller),
                                ),
                              ),
                            )
                          else
                            const Center(child: CircularProgressIndicator()),
                          if (_captured == null && ready)
                            CustomPaint(
                              painter: _IdentityFramePainter(
                                frame: marketplaceIdentityFrame(size),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFFF8A9A))),
              ],
              const SizedBox(height: 12),
              Text(
                _captured == null
                    ? 'Alinea el documento y pulsa Tomar foto.'
                    : 'Revisa que se vean las cuatro esquinas y todo sea legible.',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_captured != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() => _captured = null),
                        child: const Text('Repetir foto'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy
                          ? null
                          : _captured != null
                              ? () => Navigator.of(context).pop(_captured)
                              : ready
                                  ? _takePhoto
                                  : null,
                      child: Text(
                          _captured == null ? 'Tomar foto' : 'Usar esta foto'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityFramePainter extends CustomPainter {
  const _IdentityFramePainter({required this.frame});

  final Rect frame;

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(frame, const Radius.circular(10));
    final shadow = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(window);
    canvas.drawPath(shadow, Paint()..color = const Color(0x99000000));
    canvas.drawRRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF50EDBE),
    );
    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    const c = 24.0;
    for (final p in [
      (
        Offset(frame.left, frame.top + c),
        Offset(frame.left, frame.top),
        Offset(frame.left + c, frame.top)
      ),
      (
        Offset(frame.right - c, frame.top),
        Offset(frame.right, frame.top),
        Offset(frame.right, frame.top + c)
      ),
      (
        Offset(frame.left, frame.bottom - c),
        Offset(frame.left, frame.bottom),
        Offset(frame.left + c, frame.bottom)
      ),
      (
        Offset(frame.right - c, frame.bottom),
        Offset(frame.right, frame.bottom),
        Offset(frame.right, frame.bottom - c)
      ),
    ]) {
      final path = Path()
        ..moveTo(p.$1.dx, p.$1.dy)
        ..lineTo(p.$2.dx, p.$2.dy)
        ..lineTo(p.$3.dx, p.$3.dy);
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IdentityFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
