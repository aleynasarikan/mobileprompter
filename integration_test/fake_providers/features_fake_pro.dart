import 'package:flutter/material.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/disabled_feature_screen_state.dart';
import 'package:cueline/providers/app_features.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/ui/widgets/feature_version_popup_content.dart';

class FeaturesFakePro extends Features {
  @override
  AppFeatures build() {
    return AppFeatures(
      kAllFeatures,
      FeatureKind.paidVersion,
      "HomeScreen.PaidVersion",
    );
  }

  // No implementation for fake pro
  @override
  Future<bool> bootstrap() => Future.value(true);

  // No implementation for fake pro
  @override
  Future<bool> buyPro() => Future.value(true);

  // No implementation for fake pro
  @override
  Future<bool> restorePurchase() => Future.value(true);

  // No implementation for fake pro
  @override
  Widget getPurchaseScreen(DisabledFeatureScreenRouterExtra? extra) =>
      SizedBox.shrink();

  @override
  Widget Function(BuildContext) getFeaturePopup() =>
      (context) => ProFeatureVersionPopupContent();
}
