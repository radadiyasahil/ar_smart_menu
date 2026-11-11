import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/web_paste_drop_listener.dart';
import '../../models/product_model.dart';

class FourPhotoUploader extends StatefulWidget {
  const FourPhotoUploader({
    super.key,
    this.remotePhotoUrls = const {},
    this.localPhotoBytes = const {},
    required this.onPhotoSelected,
    this.onPhotoRemoved,
    this.isUploading = false,
    this.uploadingAngle,
    this.showReplaceHint = false,
    this.title = 'AR Photos (4 Required)',
    this.subtitle,
  });

  final Map<PhotoAngleType, String?> remotePhotoUrls;
  final Map<PhotoAngleType, Uint8List?> localPhotoBytes;
  final Future<void> Function(PhotoAngleType angle, Uint8List bytes, String filename) onPhotoSelected;
  final void Function(PhotoAngleType angle)? onPhotoRemoved;
  final bool isUploading;
  final PhotoAngleType? uploadingAngle;
  final bool showReplaceHint;
  final String title;
  final String? subtitle;

  @override
  State<FourPhotoUploader> createState() => _FourPhotoUploaderState();
}

class _FourPhotoUploaderState extends State<FourPhotoUploader> {
  final _picker = ImagePicker();
  late PhotoAngleType _selectedAngle;
  bool _isDraggingOver = false;
  PhotoAngleType? _draggingOverSlot;

  @override
  void initState() {
    super.initState();
    _selectedAngle = _firstEmptyAngle ?? PhotoAngleType.front;
    WebPasteDropHelper.register(onImageReceived: (b, f) {
      if (mounted && !widget.isUploading) _assign(b, f, _selectedAngle);
    });
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    WebPasteDropHelper.unregister();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      _paste();
      return true;
    }
    return false;
  }

  bool _has(PhotoAngleType a) =>
      (widget.remotePhotoUrls[a]?.isNotEmpty ?? false) || (widget.localPhotoBytes[a]?.isNotEmpty ?? false);

  PhotoAngleType? get _firstEmptyAngle {
    for (final a in PhotoAngleType.requiredForSubmit) {
      if (!_has(a)) return a;
    }
    return null;
  }

  int get _count => PhotoAngleType.requiredForSubmit.where(_has).length;

  Future<void> _assign(Uint8List bytes, String filename, PhotoAngleType angle) async {
    if (widget.isUploading) return;
    try {
      await widget.onPhotoSelected(angle, bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ Photo added for ${angle.label}!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
      setState(() => _selectedAngle = PhotoAngleType.requiredForSubmit.firstWhere((a) => a != angle && !_has(a), orElse: () => angle));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _pick(PhotoAngleType a) async {
    if (widget.isUploading) return;
    try {
      final p = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2048, maxHeight: 2048, imageQuality: 85);
      if (p != null && mounted) await _assign(await p.readAsBytes(), p.name.isNotEmpty ? p.name : '${a.name}.jpg', a);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error choosing file: $e')));
    }
  }

  Future<void> _paste([PhotoAngleType? target]) async {
    if (widget.isUploading) return;
    final a = target ?? _selectedAngle;
    try {
      final b = await Pasteboard.image;
      if (b == null || b.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No image on clipboard. Copy an image first, or press Ctrl+V.'), backgroundColor: AppColors.primaryOrange));
        return;
      }
      await _assign(b, 'pasted_${a.name}_${DateTime.now().millisecondsSinceEpoch}.png', a);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paste failed: $e')));
    }
  }

  Future<void> _drop(List<DropItem> files, [PhotoAngleType? slot]) async {
    if (widget.isUploading || files.isEmpty) return;
    final target = slot ?? _selectedAngle;
    final f = files.first;
    await _assign(await f.readAsBytes(), f.name.isNotEmpty ? f.name : '${target.name}.jpg', target);
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final total = PhotoAngleType.requiredForSubmit.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (d) { setState(() => _isDraggingOver = false); _drop(d.files); },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: _isDraggingOver ? Border.all(color: AppColors.primaryOrange, width: 2.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (count == total ? AppColors.success : AppColors.primaryOrange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$count/$total Uploaded', style: TextStyle(color: count == total ? AppColors.success : AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (count / total).clamp(0, 1),
              backgroundColor: AppColors.lightGray,
              color: count == total ? AppColors.success : AppColors.primaryOrange,
              minHeight: 5,
              borderRadius: BorderRadius.circular(99),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.primaryOrange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primaryOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('• 1 Click: Select box to Paste (Ctrl+V) or Drop\n• 2 Clicks (Double-Click): Open File Picker', style: TextStyle(fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(4)),
                    child: Text('Selected: ${_selectedAngle.label}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.content_paste, size: 14),
                    label: const Text('Paste (Ctrl+V)'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: widget.isUploading ? null : () => _paste(_selectedAngle),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Choose File'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.primaryOrange, side: const BorderSide(color: AppColors.primaryOrange), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: widget.isUploading ? null : () => _pick(_selectedAngle),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.15,
              children: PhotoAngleType.requiredForSubmit.map((a) => _buildSlot(a, isDark)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(PhotoAngleType a, bool isDark) {
    final remoteUrl = widget.remotePhotoUrls[a];
    final localBytes = widget.localPhotoBytes[a];
    final hasPhoto = (remoteUrl?.isNotEmpty ?? false) || (localBytes?.isNotEmpty ?? false);
    final isSelected = _selectedAngle == a;
    final isDragged = _draggingOverSlot == a;

    return DropTarget(
      onDragEntered: (_) => setState(() { _draggingOverSlot = a; _selectedAngle = a; }),
      onDragExited: (_) => setState(() => _draggingOverSlot = null),
      onDragDone: (d) { setState(() => _draggingOverSlot = null); _drop(d.files, a); },
      child: Material(
        color: isDragged
            ? AppColors.primaryOrange.withValues(alpha: 0.22)
            : isSelected
                ? AppColors.primaryOrange.withValues(alpha: 0.10)
                : hasPhoto
                    ? (isDark ? AppColors.darkSurfaceElevated : AppColors.lightGray.withValues(alpha: 0.4))
                    : (isDark ? AppColors.darkSurface : AppColors.lightSurface),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() => _selectedAngle = a),
          onDoubleTap: () { setState(() => _selectedAngle = a); _pick(a); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected || isDragged ? AppColors.primaryOrange : (hasPhoto ? AppColors.success.withValues(alpha: 0.7) : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                width: isSelected || isDragged ? 2.5 : 1.2,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: isSelected ? [BoxShadow(color: AppColors.primaryOrange.withValues(alpha: 0.22), blurRadius: 6, spreadRadius: 1)] : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (localBytes != null && localBytes.isNotEmpty)
                  Image.memory(localBytes, fit: BoxFit.cover)
                else if (remoteUrl != null && remoteUrl.isNotEmpty)
                  Image.network(remoteUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined))
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 30, color: isSelected ? AppColors.primaryOrange : AppColors.mediumGray),
                        const SizedBox(height: 3),
                        Text(a.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? AppColors.primaryOrange : null)),
                        Text(isSelected ? 'Ready to Paste/Drop' : 'Click to select', style: TextStyle(fontSize: 10, color: isSelected ? AppColors.primaryOrange : AppColors.mediumGray, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                      ],
                    ),
                  ),
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: Container(
                    color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.9) : Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${a.label}${isSelected ? " (Selected)" : ""}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  top: 5, left: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: isSelected ? AppColors.primaryOrange : Colors.black38, borderRadius: BorderRadius.circular(4)),
                    child: Text(isSelected ? 'SELECTED' : '1-Click', style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (hasPhoto)
                  Positioned(
                    top: 5, right: 5,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onPhotoRemoved != null)
                          GestureDetector(
                            onTap: () => widget.onPhotoRemoved!(a),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (isDragged)
                  Container(
                    color: AppColors.primaryOrange.withValues(alpha: 0.35),
                    child: const Center(child: Icon(Icons.file_download, color: Colors.white, size: 32)),
                  ),
                if (widget.isUploading && widget.uploadingAngle == a)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
