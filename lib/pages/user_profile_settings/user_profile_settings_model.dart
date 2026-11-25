import '/components/action_card/action_card_widget.dart';
import '/components/button/button_widget.dart';
import '/components/profile_header/profile_header_widget.dart';
import '/components/settings_item/settings_item_widget.dart';
import '/components/storage_stat/storage_stat_widget.dart';
import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'user_profile_settings_widget.dart' show UserProfileSettingsWidget;
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class UserProfileSettingsModel
    extends FlutterFlowModel<UserProfileSettingsWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for ProfileHeader.
  late ProfileHeaderModel profileHeaderModel;
  // Model for StorageStat.
  late StorageStatModel storageStatModel1;
  // Model for StorageStat.
  late StorageStatModel storageStatModel2;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel3;
  // Model for SettingsItem (Laporan Masyarakat / Fase 4).
  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel4;
  // Model for Switch.
  late SwitchComponentModel switchModel;
  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel5;
  // Model for SettingsItem.
  late SettingsItemModel settingsItemModel6;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    profileHeaderModel = createModel(context, () => ProfileHeaderModel());
    storageStatModel1 = createModel(context, () => StorageStatModel());
    storageStatModel2 = createModel(context, () => StorageStatModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    settingsItemModel3 = createModel(context, () => SettingsItemModel());
    settingsItemModel4 = createModel(context, () => SettingsItemModel());
    switchModel = createModel(context, () => SwitchComponentModel());
    settingsItemModel5 = createModel(context, () => SettingsItemModel());
    settingsItemModel6 = createModel(context, () => SettingsItemModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    profileHeaderModel.dispose();
    storageStatModel1.dispose();
    storageStatModel2.dispose();
    buttonModel1.dispose();
    settingsItemModel3.dispose();
    settingsItemModel4.dispose();
    switchModel.dispose();
    settingsItemModel5.dispose();
    settingsItemModel6.dispose();
    buttonModel2.dispose();
  }
}
