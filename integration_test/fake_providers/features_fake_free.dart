import 'package:flutter/material.dart';
import 'package:cueline/core/constants.dart';
import 'package:cueline/core/disabled_feature_screen_state.dart';
import 'package:cueline/providers/app_features.dart';
import 'package:cueline/providers/feature_provider.dart';
import 'package:cueline/ui/widgets/feature_version_popup_content.dart';

class FeaturesFakeFree extends Features {
  @override
  AppFeatures build() {
    return AppFeatures(
      kFreeFeatures,
      FeatureKind.freeVersion,
      "HomeScreen.FreeVersion",
    );
  }

  // No implementation for fake free
  @override
  Future<bool> bootstrap() => Future.value(true);

  // No implementation for fake free
  @override
  Future<bool> buyPro() => Future.value(true);

  // No implementation for fake free
  @override
  Future<bool> restorePurchase() => Future.value(true);

  // No implementation for fake free
  @override
  Widget getPurchaseScreen(DisabledFeatureScreenRouterExtra? extra) =>
      SizedBox.shrink();

  @override
  Widget Function(BuildContext) getFeaturePopup() =>
      (context) => FreeFeatureVersionPopupContent();
}
