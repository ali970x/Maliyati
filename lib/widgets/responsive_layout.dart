import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppResponsive {
  const AppResponsive._();

  static const double webBreakpoint = 960;
  static const double webContentMaxWidth = 1360;
  static const double webDetailMaxWidth = 980;

  static bool get isWeb => kIsWeb;

  static bool isWideWeb(BuildContext context) {
    return kIsWeb && MediaQuery.sizeOf(context).width >= webBreakpoint;
  }

  static double contentMaxWidth(BuildContext context) {
    return kIsWeb ? webContentMaxWidth : 720;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    return isWideWeb(context)
        ? const EdgeInsets.fromLTRB(32, 26, 32, 40)
        : const EdgeInsets.fromLTRB(16, 12, 16, 24);
  }
}

class ResponsivePair extends StatelessWidget {
  const ResponsivePair({
    super.key,
    required this.first,
    required this.second,
    this.gap = 16,
    this.mobileGap = 12,
    this.firstFlex = 1,
    this.secondFlex = 1,
  });

  final Widget first;
  final Widget second;
  final double gap;
  final double mobileGap;
  final int firstFlex;
  final int secondFlex;

  @override
  Widget build(BuildContext context) {
    if (!AppResponsive.isWideWeb(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          SizedBox(height: mobileGap),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: firstFlex, child: first),
        SizedBox(width: gap),
        Expanded(flex: secondFlex, child: second),
      ],
    );
  }
}

class ResponsiveTriple extends StatelessWidget {
  const ResponsiveTriple({
    super.key,
    required this.first,
    required this.second,
    required this.third,
    this.gap = 16,
    this.mobileGap = 12,
  });

  final Widget first;
  final Widget second;
  final Widget third;
  final double gap;
  final double mobileGap;

  @override
  Widget build(BuildContext context) {
    if (!AppResponsive.isWideWeb(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          SizedBox(height: mobileGap),
          second,
          SizedBox(height: mobileGap),
          third,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: gap),
        Expanded(child: second),
        SizedBox(width: gap),
        Expanded(child: third),
      ],
    );
  }
}
