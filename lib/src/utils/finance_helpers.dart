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
      case 'cart': return MdiIcons.cart;
      case 'cash': return MdiIcons.cashMultiple;
      case 'gift': return MdiIcons.gift;
      case 'school': return MdiIcons.school;
      case 'heart': return MdiIcons.heart;
      case 'bank': return MdiIcons.bank;
      default: return MdiIcons.circleMedium;
    }
  }
}