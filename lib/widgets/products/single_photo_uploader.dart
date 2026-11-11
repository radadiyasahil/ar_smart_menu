import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/web_paste_drop_listener.dart';

/// Single photo uploader & replacer for Standard (2D) dishes.
/// Supports gallery selection, drag & drop, and clipboard paste (Ctrl+V).
class SinglePhotoUploader extends StatefulWidget {
  const SinglePhotoUploader({
    super.key,
    this.remotePhotoUrl,
    this.localPhotoBytes,
    required this.onPhotoSelected,
    this.onPhotoRemoved,
    this.isUploading = false,
    this.title = 'Display Photo',
    this.subtitle = 'The single photo shown on your digital menu card and table orders.',
  });

  final String? remotePhotoUrl;
  final Uint8List? localPhotoBytes;
  final Future<void> Function(Uint8List bytes, String filename) onPhotoSelected;
  final VoidCallback? onPhotoRemoved;
  final bool isUploading;
  final String title;
  final String? subtitle;

  @override
  State<SinglePhotoUploader> createState() => _SinglePhotoUploaderState();
}

class _SinglePhotoUploaderState extends State<SinglePhotoUploader> {
  final _picker = ImagePicker();
  bool _isDraggingOver = false;

  @override
  void initState() {
    super.initState();
    WebPasteDropHelper.register(onImageReceived: (bytes, filename) {
      if (mounted && !widget.isUploading) {
        _assign(bytes, filename);
      }
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
    if (e is KeyDownEvent &&
        e.logicalKey == LogicalKeyboardKey.keyV &&
        (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed)) {
      _paste();
      return true;
    }
    return false;
  }

  bool get _hasPhoto =>
      (widget.remotePhotoUrl != null && widget.remotePhotoUrl!.isNotEmpty) ||
      (widget.localPhotoBytes != null && widget.localPhotoBytes!.isNotEmpty);

  Future<void> _assign(Uint8List bytes, String filename) async {
    if (widget.isUploading) return;
    try {
      await widget.onPhotoSelected(bytes, filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (widget.isUploading) return;
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final name = picked.name.isNotEmpty ? picked.name : 'display_photo.jpg';
        await _assign(bytes, name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing photo: $e')),
        );
      }
    }
  }

  Future<void> _paste() async {
    if (widget.isUploading) return;
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image on clipboard. Copy an image first, or choose a file.'),
              backgroundColor: AppColors.primaryOrange,
            ),
          );
        }
        return;
      }
      await _assign(bytes, 'pasted_photo_${DateTime.now().millisecondsSinceEpoch}.png');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paste failed: $e')),
        );
      }
    }
  }

  Future<void> _drop(List<DropItem> files) async {
    if (widget.isUploading || files.isEmpty) return;
    final file = files.first;
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : 'dropped_photo.jpg';
    await _assign(bytes, name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasPhoto = _hasPhoto;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDraggingOver = true),
      onDragExited: (_) => setState(() => _isDraggingOver = false),
      onDragDone: (d) {
        setState(() => _isDraggingOver = false);
        _drop(d.files);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: _isDraggingOver
              ? Border.all(color: AppColors.primaryOrange, width: 2.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with badge
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasPhoto ? AppColors.success : AppColors.primaryOrange).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (hasPhoto ? AppColors.success : AppColors.primaryOrange).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    hasPhoto ? 'Photo Uploaded' : '1 Photo Needed',
                    style: TextStyle(
                      color: hasPhoto ? AppColors.success : AppColors.primaryOrange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Quick Action Buttons (Paste / Choose File)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: AppColors.primaryOrange,
                      side: const BorderSide(color: AppColors.primaryOrange, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.content_paste_outlined, size: 16),
                    label: const Text('Paste (Ctrl+V)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: widget.isUploading ? null : _paste,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(
                      hasPhoto ? 'Replace Photo' : 'Choose Photo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: widget.isUploading ? null : _pickPhoto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Photo Drop / Preview Area
            GestureDetector(
              onTap: widget.isUploading ? null : _pickPhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E212E) : const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isDraggingOver
                        ? AppColors.primaryOrange
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: _isDraggingOver ? 2.0 : 1.2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (widget.localPhotoBytes != null)
                      Image.memory(
                        widget.localPhotoBytes!,
                        fit: BoxFit.cover,
                      )
                    else if (widget.remotePhotoUrl != null && widget.remotePhotoUrl!.isNotEmpty)
                      Image.network(
                        widget.remotePhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildPlaceholder(isDark),
                      )
                    else
                      _buildPlaceholder(isDark),

                    // Gradient overlay at bottom if image is present
                    if (hasPhoto)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.8),
                                Colors.black.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                  SizedBox(width: 6),
                                  Text(
                                    'Display Photo Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.refresh, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to replace',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Loading overlay
                    if (widget.isUploading)
                      Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.primaryOrange),
                              SizedBox(height: 12),
                              Text(
                                'Uploading photo...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 38,
            color: AppColors.primaryOrange,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Tap to select display photo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text(
          'or drag & drop / Paste (Ctrl+V) image here',
          style: TextStyle(fontSize: 12, color: AppColors.mediumGray),
        ),
        const SizedBox(height: 6),
        Text(
          'JPG, PNG under 10MB',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
