import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DynamicThemeState {
  static bool isDark = true;
}

class TestDynamicColor extends Color {
  final Color darkColor;
  final Color lightColor;

  const TestDynamicColor(this.darkColor, this.lightColor) : super(0);

  @override
  int get value => DynamicThemeState.isDark ? darkColor.value : lightColor.value;
}

void main() {
  test('Dynamic Color test', () {
    const dynamicColor = TestDynamicColor(Colors.black, Colors.white);
    
    expect(dynamicColor.value, Colors.black.value);
    
    DynamicThemeState.isDark = false;
    expect(dynamicColor.value, Colors.white.value);
  });
}
