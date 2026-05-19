import 'package:flutter/material.dart';

enum VlotterLogoColor { green, white }

class VlotterLogo extends StatelessWidget {
  const VlotterLogo({
    super.key,
    this.height = 42,
    this.fit = BoxFit.contain,
    this.color = VlotterLogoColor.green,
    this.semanticLabel = 'Vlotter',
  });

  final double height;
  final BoxFit fit;
  final VlotterLogoColor color;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      color == VlotterLogoColor.white
          ? 'assets/images/vlotter_logo_white.png'
          : 'assets/images/vlotter_logo.png',
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
    );
  }
}
