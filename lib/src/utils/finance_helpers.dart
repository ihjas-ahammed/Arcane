import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class FinanceHelpers {
  static IconData getIconData(String name) {
    switch (name) {
      case 'briefcase': return MdiIcons.briefcase;
      case 'food': return MdiIcons.foodForkDrink;
      case 'car': return MdiIcons.car;
      case 'flash': return MdiIcons.flash;
      case 'gamepad': return MdiIcons.gamepadVariant;
      case 'target': return MdiIcons.target;
      default: return MdiIcons.circleMedium;
    }
  }
}