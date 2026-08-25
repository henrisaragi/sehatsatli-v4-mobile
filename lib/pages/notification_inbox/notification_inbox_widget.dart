import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/components/main_bottom_nav/main_bottom_nav_widget.dart';
import '/components/training_mode_banner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../../core/network/api_client.dart';
import '../../data/repositories/inbox_repository.dart';
import 'notification_inbox_model.dart';
export 'notification_inbox_model.dart';

class NotificationInboxWidget extends StatefulWidget {
  const NotificationInboxWidget({super.key});

  static String routeName = 'NotificationInbox';
  static String routePath = '/notificationInbox';

  @override
  State<NotificationInboxWidget> createState() =>
      _NotificationInboxWidgetState();
}

class _NotificationInboxWidgetState extends State<NotificationInboxWidget> {
  late NotificationInboxModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<InboxMessage> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificationInboxModel());
    _load();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    final token = FFAppState().accessToken;
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Sesi tidak ditemukan, silakan masuk kembali.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final messages = await InboxRepository().fetchAll(token: token);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Tidak bisa memuat notifikasi — periksa koneksi.';
      });
    }
  }

  Future<void> _openMessage(InboxMessage message) async {
    if (!message.read) {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        setState(() => _messages[index] = message.copyWith(read: true));
      }
      final token = FFAppState().accessToken;
      if (token != null) {
        unawaited(InboxRepository().markRead(message, token: token));
      }
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(message.subject),
        content: SingleChildScrollView(child: Text(message.message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _emptyOrError() {
    return ListView(
      children: [
        SizedBox(height: 96.0),
        Icon(
          LucideIcons.bell,
          color: FlutterFlowTheme.of(context).secondaryText,
          size: 56.0,
        ),
        SizedBox(height: 16.0),
        Text(
          _errorMessage == null ? 'Belum ada notifikasi' : 'Gagal memuat',
          textAlign: TextAlign.center,
          style: FlutterFlowTheme.of(context)
              .titleMedium
              .override(color: FlutterFlowTheme.of(context).primaryText),
        ),
        SizedBox(height: 8.0),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            _errorMessage ??
                'Pemberitahuan laporan baru dan pembaruan verifikasi akan muncul di sini.',
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context)
                .bodySmall
                .override(color: FlutterFlowTheme.of(context).secondaryText),
          ),
        ),
      ],
    );
  }

  Widget _messageTile(InboxMessage message) {
    return InkWell(
      onTap: () => _openMessage(message),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Container(
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(
                  color: message.read
                      ? Colors.transparent
                      : FlutterFlowTheme.of(context).warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyLarge.override(
                          font: GoogleFonts.inter(
                            fontWeight:
                                message.read ? FontWeight.normal : FontWeight.w700,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          fontWeight:
                              message.read ? FontWeight.normal : FontWeight.w700,
                        ),
                  ),
                  SizedBox(height: 2.0),
                  Text(
                    message.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          color: FlutterFlowTheme.of(context).secondaryText,
                        ),
                  ),
                  if (message.receivedDate.isNotEmpty) ...[
                    SizedBox(height: 4.0),
                    Text(
                      message.receivedDate,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            color: FlutterFlowTheme.of(context).secondaryText,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      body: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              border: Border(
                  bottom: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
                child: Text(
                  'Notifikasi',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ),
          TrainingModeBanner(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _messages.isEmpty
                        ? _emptyOrError()
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            itemCount: _messages.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1.0,
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                            itemBuilder: (context, index) =>
                                _messageTile(_messages[index]),
                          ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNavWidget(currentTab: MainTab.notifikasi),
    );
  }
}
