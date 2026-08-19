import 'dart:io';

import '/flutter_flow/flutter_flow_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Variable-length photo picker: existing server media (display-only) plus
/// newly-picked local files (to be base64-encoded and embedded in the save
/// payload right before submit, per CLAUDE.md §5.3's lazy-encoding rule).
///
/// Generalized from `new_general_report_widget.dart`'s fixed-3-slot
/// `_photoSlot`/`_pickPhoto` pattern. The two lists are kept deliberately
/// separate and distinctly typed so a caller can always tell "did the user
/// pick something new" without ambiguity — this is the direct fix for
/// revisi.md's photo bug note 4/5: a naive "is there anything in this
/// field" check treated existing-preview media as if it were a new upload
/// and fired uploads/sends the user never asked for.
///
/// This widget never mutates or re-sends [existingMediaUrls] — it only
/// adds/removes entries in [newLocalPaths] via [onLocalPathsChanged], which
/// the parent form owns as state.
class MultiImagePickerWidget extends StatelessWidget {
  const MultiImagePickerWidget({
    super.key,
    required this.existingMediaUrls,
    required this.newLocalPaths,
    required this.onLocalPathsChanged,
    this.label,
  });

  /// Remote URLs of media already attached to this report (e.g. from
  /// `currentReport.media[].original_url`) — rendered as non-removable
  /// preview thumbnails, never re-sent to the server.
  final List<String> existingMediaUrls;

  /// Local file paths of photos the user has picked in this session but not
  /// yet submitted. Only this list is ever mutated by the picker.
  final List<String> newLocalPaths;

  final ValueChanged<List<String>> onLocalPathsChanged;
  final String? label;

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.camera),
              title: Text('Ambil Foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(LucideIcons.images),
              title: Text('Pilih dari Galeri'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;

    // flutter_image_compress writes to a temp file separate from the picked
    // source, so nothing captured pre-compression lingers on disk.
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/report_photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 70,
      minWidth: 1280,
      minHeight: 1280,
    );

    onLocalPathsChanged([...newLocalPaths, compressed?.path ?? picked.path]);
  }

  void _removeLocal(int index) {
    final next = List<String>.from(newLocalPaths)..removeAt(index);
    onLocalPathsChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: EdgeInsets.only(bottom: 6.0),
            child: Text(
              label!,
              style: FlutterFlowTheme.of(context)
                  .labelMedium
                  .override(fontWeight: FontWeight.w600),
            ),
          ),
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: [
            for (final url in existingMediaUrls)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 100.0,
                  height: 100.0,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(context),
                ),
              ),
            for (var i = 0; i < newLocalPaths.length; i++)
              InkWell(
                onLongPress: () => _removeLocal(i),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: Image.file(
                        File(newLocalPaths[i]),
                        width: 100.0,
                        height: 100.0,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2.0,
                      right: 2.0,
                      child: InkWell(
                        onTap: () => _removeLocal(i),
                        child: Container(
                          padding: EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.x,
                              size: 14.0, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            InkWell(
              onTap: () => _pickPhoto(context),
              borderRadius: BorderRadius.circular(12.0),
              child: Container(
                width: 100.0,
                height: 100.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: FlutterFlowTheme.of(context).alternate),
                ),
                child: Icon(LucideIcons.imagePlus,
                    color: FlutterFlowTheme.of(context).secondaryText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: 100.0,
      height: 100.0,
      color: FlutterFlowTheme.of(context).secondaryBackground,
      child: Icon(LucideIcons.imageOff,
          color: FlutterFlowTheme.of(context).secondaryText),
    );
  }
}
