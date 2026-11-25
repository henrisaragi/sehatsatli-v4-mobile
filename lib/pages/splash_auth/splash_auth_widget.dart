import '/components/app_loading_indicator.dart';
import '/components/button/button_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/core/network/api_client.dart';
import '/data/repositories/auth_repository.dart';
import '/data/repositories/master_repository.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'splash_auth_model.dart';
export 'splash_auth_model.dart';

class SplashAuthWidget extends StatefulWidget {
  const SplashAuthWidget({super.key});

  static String routeName = 'SplashAuth';
  static String routePath = '/splashAuth';

  @override
  State<SplashAuthWidget> createState() => _SplashAuthWidgetState();
}

class _SplashAuthWidgetState extends State<SplashAuthWidget> {
  late SplashAuthModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  // The eye icon on the password field was purely decorative — TextFieldWidget
  // renders `trailingIcon` as a static child with no tap handling at all, so
  // nothing happened when it was pressed. Toggled via this + the field's new
  // `onTrailingIconTap` callback.
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SplashAuthModel());
    _checkPersistedSession();
  }

  Future<void> _checkPersistedSession() async {
    final token = await AuthRepository().readPersistedToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      _model.isCheckingSession = false;
      safeSetState(() {});
      return;
    }
    FFAppState().accessToken = token;
    // Restores RBAC flags (is_doctor/heads_upt/etc., see FFAppState) that
    // otherwise only lived in memory and were lost on every app restart.
    FFAppState().currentUser = await AuthRepository().readPersistedUser();
    // Fire-and-forget: don't block navigation on a network round-trip —
    // dropdowns just fall back to whatever's already cached if this fails.
    MasterRepository().refreshAll(token: token);
    if (!mounted) return;
    context.goNamed(DashboardWidget.routeName);
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_model.isCheckingSession) {
      return Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                FlutterFlowTheme.of(context).primary,
                Color(0xFF0E6B46),
              ],
              stops: [0.0, 1.0],
              begin: AlignmentDirectional(0.0, -1.0),
              end: AlignmentDirectional(0, 1.0),
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLoadingIndicator(
                  size: 96.0,
                  ringColor: Colors.white,
                  assetPath: 'assets/images/branding/icon-mark-white.png',
                ),
                SizedBox(height: 24.0),
                Text(
                  'SEHATSATLI',
                  style: FlutterFlowTheme.of(context).headlineLarge.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineLarge
                              .fontStyle,
                        ),
                        color: Colors.white,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            FlutterFlowTheme.of(context).headlineLarge.fontStyle,
                      ),
                ),
                Text(
                  'SISTEM INFORMASI KESEHATAN SATWA LIAR',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).onPrimary20,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 0.0,
                height: 0.0,
              ),
              Expanded(
                child: Container(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context).primary,
                                Color(0xFF0E6B46)
                              ],
                              stops: [0.0, 1.0],
                              begin: AlignmentDirectional(0.0, -1.0),
                              end: AlignmentDirectional(0, 1.0),
                            ),
                            shape: BoxShape.rectangle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 100.0,
                                    height: 100.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .onPrimary20,
                                      borderRadius: BorderRadius.circular(28.0),
                                      shape: BoxShape.rectangle,
                                    ),
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Icon(
                                      LucideIcons.heartPulse,
                                      color: FlutterFlowTheme.of(context)
                                          .onSurface,
                                      size: 60.0,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SehatSatli',
                                        style: FlutterFlowTheme.of(context)
                                            .headlineLarge
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .headlineLarge
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .onBackground,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineLarge
                                                      .fontStyle,
                                              lineHeight: 1.2,
                                            ),
                                      ),
                                      Text(
                                        'Wildlife Health Surveillance System',
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .onBackground90,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                              lineHeight: 1.47,
                                            ),
                                      ),
                                    ].divide(SizedBox(height: 4.0)),
                                  ),
                                ].divide(SizedBox(height: 24.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32.0),
                              topRight: Radius.circular(32.0),
                            ),
                            shape: BoxShape.rectangle,
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Container(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Welcome Back',
                                        style: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleLarge
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleLarge
                                                      .fontStyle,
                                              lineHeight: 1.27,
                                            ),
                                      ),
                                      Text(
                                        'Sign in to your officer account',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                              lineHeight: 1.47,
                                            ),
                                      ),
                                    ].divide(SizedBox(height: 4.0)),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      wrapWithModel(
                                        model: _model.textFieldModel1,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: TextFieldWidget(
                                          label: 'Email Address',
                                          labelPresent: false,
                                          helper: '',
                                          helperPresent: false,
                                          leadingIcon: Icon(
                                            LucideIcons.mail,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                          leadingIconPresent: true,
                                          trailingIconPresent: false,
                                          hint: 'officer@menlhk.go.id',
                                          value: _model.email,
                                          variant: 'outlined',
                                          error: false,
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          wrapWithModel(
                                            model: _model.textFieldModel2,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Password',
                                              labelPresent: false,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                LucideIcons.lock,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIcon: Icon(
                                                _passwordVisible
                                                    ? LucideIcons.eye
                                                    : Icons
                                                        .visibility_off_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              trailingIconPresent: true,
                                              onTrailingIconTap: () =>
                                                  safeSetState(() =>
                                                      _passwordVisible =
                                                          !_passwordVisible),
                                              hint: '••••••••',
                                              value: _model.password,
                                              obscureText: !_passwordVisible,
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              InkWell(
                                                splashColor:
                                                    Colors.transparent,
                                                focusColor:
                                                    Colors.transparent,
                                                hoverColor:
                                                    Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () => context.pushNamed(
                                                    ForgotPasswordWidget
                                                        .routeName),
                                                child: wrapWithModel(
                                                  model: _model.buttonModel1,
                                                  updateCallback: () =>
                                                      safeSetState(() {}),
                                                  child: ButtonWidget(
                                                    iconPresent: false,
                                                    iconEndPresent: false,
                                                    content:
                                                        'Forgot Password?',
                                                    variant: 'ghost',
                                                    size: 'small',
                                                    fullWidth: false,
                                                    loading: false,
                                                    disabled: false,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ].divide(SizedBox(height: 4.0)),
                                      ),
                                    ].divide(SizedBox(height: 16.0)),
                                  ),
                                  if (_model.error != null &&
                                      _model.error != '')
                                    Text(
                                      _model.error!,
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                            lineHeight: 1.38,
                                          ),
                                    ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      // TextFieldWidget's onChange/value are
                                      // plumbed as (unused) Strings, not
                                      // callbacks, so _model.email/password
                                      // are never populated from keystrokes —
                                      // read straight from the controllers.
                                      final email = _model.textFieldModel1
                                              .inputTextController?.text ??
                                          '';
                                      final password = _model.textFieldModel2
                                              .inputTextController?.text ??
                                          '';
                                      if (email.isEmpty || password.isEmpty) {
                                        _model.error =
                                            'Email and password are required';
                                        safeSetState(() {});
                                        return;
                                      }
                                      _model.error = '';
                                      _model.isLoggingIn = true;
                                      safeSetState(() {});

                                      try {
                                        final result = await AuthRepository()
                                            .requestLoginOtp(email, password);
                                        if (result.success) {
                                          _model.isLoggingIn = false;
                                          safeSetState(() {});
                                          if (!mounted) return;
                                          context.pushNamed(
                                            OtpLoginWidget.routeName,
                                            extra: {
                                              'email': email,
                                              'loginToken': result.loginToken,
                                              'expiresIn': result.expiresIn,
                                            },
                                          );
                                          return;
                                        }
                                        _model.error = result.message ??
                                            'Login failed. Please check your credentials.';
                                      } on ApiRateLimitException {
                                        _model.error =
                                            'Terlalu banyak percobaan, coba lagi nanti.';
                                      } on ApiNetworkException {
                                        _model.error =
                                            'Cannot reach the server. Check your internet connection.';
                                      } finally {
                                        _model.isLoggingIn = false;
                                        safeSetState(() {});
                                      }
                                    },
                                    child: wrapWithModel(
                                      model: _model.buttonModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ButtonWidget(
                                        iconPresent: false,
                                        iconEndPresent: false,
                                        content: 'Login to System',
                                        variant: 'primary',
                                        size: 'large',
                                        fullWidth: true,
                                        loading: _model.isLoggingIn,
                                        disabled: false,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Don\'t have an account?',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                  lineHeight: 1.38,
                                                ),
                                          ),
                                          InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () => context.pushNamed(
                                                RegisterUptWidget.routeName),
                                            child: wrapWithModel(
                                              model: _model.buttonModel3,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ButtonWidget(
                                                iconPresent: false,
                                                iconEndPresent: false,
                                                content: 'Register Officer',
                                                variant: 'ghost',
                                                size: 'small',
                                                fullWidth: false,
                                                loading: false,
                                                disabled: false,
                                              ),
                                            ),
                                          ),
                                        ].divide(SizedBox(width: 4.0)),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .success10,
                                          borderRadius:
                                              BorderRadius.circular(9999.0),
                                          shape: BoxShape.rectangle,
                                        ),
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 8.0, 16.0, 8.0),
                                          child: Container(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  LucideIcons.wifiOff,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .onSurface,
                                                  size: 14.0,
                                                ),
                                                Text(
                                                  'Offline mode available',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .onSurface,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                        lineHeight: 1.27,
                                                      ),
                                                ),
                                              ].divide(SizedBox(width: 4.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () => context.pushNamed(
                                            CommunityReportWidget.routeName),
                                        child: Padding(
                                          padding: EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            'Bukan petugas? Kirim Laporan Cepat tanpa akun',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 24.0)),
                              ),
                            ),
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
      ),
    );
  }
}
