import '/components/button/button_widget.dart';
import '/components/profile_header/profile_header_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'user_profile_settings_widget.dart' show UserProfileSettingsWidget;
import 'package:flutter/material.dart';

class UserProfileSettingsModel
    extends FlutterFlowModel<UserProfileSettingsWidget> {
  late ProfileHeaderModel profileHeaderModel;
  late ButtonModel logoutButtonModel;

  @override
  void initState(BuildContext context) {
    profileHeaderModel = createModel(context, () => ProfileHeaderModel());
    logoutButtonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    profileHeaderModel.dispose();
    logoutButtonModel.dispose();
  }
}
