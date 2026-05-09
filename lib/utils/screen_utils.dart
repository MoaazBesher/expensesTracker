import 'package:flutter/material.dart';

class S {
  static double? _w;
  static double? _h;
  static double? _t;

  static void init(BuildContext context) {
    final mq = MediaQuery.of(context);
    _w = mq.size.width;
    _h = mq.size.height;
    _t = mq.textScaler.scale(1);
  }

  static double get w => _w ?? 400;
  static double get h => _h ?? 800;
  static double get t => _t ?? 1.0;

  static double wp(double percent) => w * percent / 100;
  static double hp(double percent) => h * percent / 100;

  static double sp(double size) => size;

  static double get cardRadius => 16;
  static double get cardPadding => 16;
  static double get sectionPadding => 24;
  static double get fontSmall => 12;
  static double get fontBody => 14;
  static double get fontLarge => 18;
  static double get fontTitle => 22;
}
