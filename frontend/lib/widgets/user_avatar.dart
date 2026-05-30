import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'design/design_system.dart';

class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.initial,
    this.profileImage,
    this.imageBytes,
    this.size = 56,
    this.borderRadius = kRadiusLg,
    this.circle = false,
    this.fontSize,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
  });

  final String initial;
  final String? profileImage;
  final Uint8List? imageBytes;
  final double size;
  final double borderRadius;
  final bool circle;
  final double? fontSize;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  Uint8List? get _resolvedBytes {
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return imageBytes;
    }

    final raw = profileImage?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final payload = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _resolvedBytes;
    final radius = BorderRadius.circular(circle ? size / 2 : borderRadius);

    Widget fallback() {
      return Center(
        child: Text(
          initial.isNotEmpty ? initial[0].toUpperCase() : '?',
          style: TextStyle(
            color: kBrandGreenDeep,
            fontWeight: FontWeight.w800,
            fontSize: fontSize ?? size * 0.4,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kBrandGreenSoft,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : radius,
        border: Border.all(
          color: borderColor ?? kBrandGreenSoft,
          width: borderWidth,
        ),
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: bytes == null
          ? fallback()
          : Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => fallback(),
            ),
    );
  }
}
