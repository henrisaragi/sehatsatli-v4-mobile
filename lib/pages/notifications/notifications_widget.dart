import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '/core/network/api_client.dart';
import '/core/network/push_service.dart';
import '/data/repositories/notification_repository.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Notifikasi milik user (`GET notifikasi`): laporan baru di entitas yang sama
/// dan, untuk role direktorat-ksg, laporan dengan penyakit ber-alert.
class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  static String routeName = 'Notifications';
  static String routePath = '/notifications';

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  final _repository = NotificationRepository();
  final _scrollController = ScrollController();

  final List<AppNotification> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.extentAfter < 300) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String? get _token => FFAppState().accessToken;

  Future<void> _refresh() async {
    final token = _token;
    if (token == null) return;
    try {
      final page = await _repository.fetchPage(token: token);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (page == null) {
          _error = 'Gagal memuat notifikasi.';
          return;
        }
        _error = null;
        _items
          ..clear()
          ..addAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
      });
      if (page != null) PushService.instance.unreadCount.value = page.unreadCount;
    } on ApiNetworkException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Tidak ada koneksi. Notifikasi hanya bisa dilihat saat online.';
      });
    }
  }

  Future<void> _loadMore() async {
    final token = _token;
    if (!_hasMore || _isLoadingMore || token == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _repository.fetchPage(token: token, page: _page + 1);
      if (!mounted) return;
      setState(() {
        if (page != null) {
          _items.addAll(page.items);
          _page += 1;
          _hasMore = page.hasMore;
        }
      });
    } on ApiNetworkException {
      // Scrolling again retries.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    final token = _token;
    if (token == null) return;
    try {
      if (!await _repository.markAllRead(token: token)) return;
    } on ApiNetworkException {
      return;
    }
    if (!mounted) return;
    setState(() {
      for (final item in _items) {
        item.isRead = true;
      }
    });
    PushService.instance.unreadCount.value = 0;
  }

  Future<void> _open(AppNotification item) async {
    final token = _token;
    if (!item.isRead && token != null) {
      setState(() => item.isRead = true);
      final count = PushService.instance.unreadCount;
      if (count.value > 0) count.value -= 1;
      _repository.markRead(item.id, token: token).catchError((_) => false);
    }
    PushService.instance.openLaporan(item.laporanId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final hasUnread = _items.any((item) => !item.isRead);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 22.0, 12.0, 20.0),
                child: Row(
                  children: [
                    FlutterFlowIconButton(
                      borderRadius: 8.0,
                      buttonSize: 40.0,
                      icon: Icon(LucideIcons.arrowLeft, color: theme.primaryText),
                      onPressed: () => context.safePop(),
                    ),
                    SizedBox(width: 4.0),
                    Expanded(
                      child: Text(
                        'Notifikasi',
                        style: theme.titleLarge.override(
                          font: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                          color: theme.primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasUnread)
                      TextButton(
                        onPressed: _markAllRead,
                        child: Text(
                          'Tandai semua dibaca',
                          style: theme.labelLarge.override(color: theme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : RefreshIndicator(onRefresh: _refresh, child: _list(theme)),
          ),
        ],
      ),
    );
  }

  Widget _list(FlutterFlowTheme theme) {
    if (_items.isEmpty) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.0),
          Icon(_error != null ? LucideIcons.wifiOff : LucideIcons.bellOff,
              size: 48.0, color: theme.secondaryText),
          SizedBox(height: 12.0),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              _error ?? 'Belum ada notifikasi.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium.override(color: theme.secondaryText),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1.0, color: theme.alternate),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _tile(theme, _items[index]);
      },
    );
  }

  Widget _tile(FlutterFlowTheme theme, AppNotification item) {
    final isAlert = item.jenis == AppNotification.jenisPenyakitAlert;
    final accent = isAlert ? theme.error : theme.primary;
    final createdAt = item.createdAt;

    return InkWell(
      onTap: () => _open(item),
      child: Container(
        color: item.isRead ? Colors.transparent : theme.accent3,
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40.0,
              height: 40.0,
              decoration: BoxDecoration(
                color: isAlert ? theme.accent4 : theme.accent1,
                shape: BoxShape.circle,
              ),
              child: Icon(isAlert ? LucideIcons.triangleAlert : LucideIcons.clipboardList,
                  color: accent, size: 20.0),
            ),
            SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.judul,
                    style: theme.bodyLarge.override(
                      color: theme.primaryText,
                      fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.0),
                  Text(item.pesan, style: theme.bodyMedium.override(color: theme.secondaryText)),
                  if (createdAt != null) ...[
                    SizedBox(height: 4.0),
                    Text(
                      dateTimeFormat('dd MMMM yyyy, HH:mm', createdAt.toLocal(), locale: 'id'),
                      style: theme.bodySmall.override(color: theme.secondaryText),
                    ),
                  ],
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                margin: EdgeInsets.only(left: 8.0, top: 6.0),
                width: 8.0,
                height: 8.0,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
