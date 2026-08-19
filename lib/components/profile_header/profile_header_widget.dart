import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'profile_header_model.dart';
export 'profile_header_model.dart';

class ProfileHeaderWidget extends StatefulWidget {
  const ProfileHeaderWidget({
    super.key,
    String? name,
    String? role,
    String? nip,
    this.institution,
    this.photoUrl,
    this.localPhotoPath,
    this.uploadingPhoto = false,
    this.onTapAvatar,
  })  : this.name = name ?? 'Alex Rivera',
        this.role = role ?? 'Field Veterinarian',
        this.nip = nip ?? '19920815 202102 1 003';

  final String name;
  final String role;
  final String nip;

  /// Optional institution/UPT line shown below the NIP pill — per
  /// tasks.md's "nama/instansi (read-only)" profile spec.
  final String? institution;

  /// Server-hosted avatar photo. Ignored while [localPhotoPath] is set.
  final String? photoUrl;

  /// Freshly-picked local photo, shown immediately as an optimistic preview
  /// before the upload response (whose shape isn't confirmed) comes back.
  final String? localPhotoPath;

  final bool uploadingPhoto;

  /// If set, the avatar becomes tappable (e.g. to trigger a photo upload)
  /// and shows a small camera badge.
  final VoidCallback? onTapAvatar;

  @override
  State<ProfileHeaderWidget> createState() => _ProfileHeaderWidgetState();
}

class _ProfileHeaderWidgetState extends State<ProfileHeaderWidget> {
  late ProfileHeaderModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileHeaderModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        shape: BoxShape.rectangle,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(32.0),
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatar(context),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        valueOrDefault<String>(
                          widget!.name,
                          'Alex Rivera',
                        ),
                        style: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineSmall
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).primaryText,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.bold,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .headlineSmall
                                  .fontStyle,
                              lineHeight: 1.3,
                            ),
                      ),
                      Text(
                        valueOrDefault<String>(
                          widget!.role,
                          'Field Veterinarian',
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.47,
                            ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 0.0),
                        child: Container(
                          child: Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              borderRadius: BorderRadius.circular(9999.0),
                              shape: BoxShape.rectangle,
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 4.0, 16.0, 4.0),
                              child: Container(
                                child: Text(
                                  valueOrDefault<String>(
                                    'NIP: ${widget!.nip}',
                                    'NIP: 19920815 202102 1 003',
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                        lineHeight: 1.27,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if ((widget!.institution ?? '').isNotEmpty)
                        Text(
                          widget!.institution!,
                          textAlign: TextAlign.center,
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.inter(),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                    ].divide(SizedBox(height: 4.0)),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          ),
          Container(
            height: 1.0,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).alternate,
              shape: BoxShape.rectangle,
            ),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final parts = widget!.name.trim().split(RegExp(r'\s+'));
    final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]);
    final initials = letters.join().toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }

  Widget _buildAvatar(BuildContext context) {
    Widget content;
    if (widget!.localPhotoPath != null) {
      content = ClipOval(
        child: Image.file(
          File(widget!.localPhotoPath!),
          width: 80.0,
          height: 80.0,
          fit: BoxFit.cover,
        ),
      );
    } else if (widget!.photoUrl != null) {
      content = ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget!.photoUrl!,
          width: 80.0,
          height: 80.0,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => _initialsAvatar(context),
        ),
      );
    } else {
      content = _initialsAvatar(context);
    }

    return GestureDetector(
      onTap: widget!.onTapAvatar,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: 80.0, height: 80.0, child: content),
          if (widget!.uploadingPhoto)
            Container(
              width: 80.0,
              height: 80.0,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              alignment: AlignmentDirectional(0.0, 0.0),
              child: SizedBox(
                width: 24.0,
                height: 24.0,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          if (widget!.onTapAvatar != null && !widget!.uploadingPhoto)
            PositionedDirectional(
              bottom: -2.0,
              end: -2.0,
              child: Container(
                width: 28.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    width: 2.0,
                  ),
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: Icon(
                  LucideIcons.camera,
                  color: FlutterFlowTheme.of(context).info,
                  size: 14.0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(BuildContext context) {
    return Container(
      width: 80.0,
      height: 80.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primary10,
        shape: BoxShape.circle,
      ),
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Text(
        _initials,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: FlutterFlowTheme.of(context).labelMedium.override(
              font: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
              ),
              color: FlutterFlowTheme.of(context).primary,
              fontSize: 32.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w600,
              fontStyle: FlutterFlowTheme.of(context).labelMedium.fontStyle,
              lineHeight: 1.38,
            ),
        overflow: TextOverflow.clip,
      ),
    );
  }
}
