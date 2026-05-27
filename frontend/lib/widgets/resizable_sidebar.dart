import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ResizableSidebar extends StatefulWidget {
  const ResizableSidebar({
    super.key,
    required this.title,
    required this.storageKey,
    required this.childBuilder,
    this.footer,
    this.defaultWidth = 232,
    this.minWidth = 196,
    this.maxWidth = 360,
    this.collapsedWidth = 72,
  });

  final String title;
  final String storageKey;
  final Widget Function(BuildContext context, bool expanded) childBuilder;
  final Widget? footer;
  final double defaultWidth;
  final double minWidth;
  final double maxWidth;
  final double collapsedWidth;

  @override
  State<ResizableSidebar> createState() => _ResizableSidebarState();
}

class _ResizableSidebarState extends State<ResizableSidebar> {
  late double _width = widget.defaultWidth;
  bool _expanded = true;
  bool _isDragging = false;

  String get _expandedKey => '${widget.storageKey}.expanded';
  String get _widthKey => '${widget.storageKey}.width';

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _expanded = prefs.getBool(_expandedKey) ?? true;
      _width = (prefs.getDouble(_widthKey) ?? widget.defaultWidth).clamp(
        widget.minWidth,
        widget.maxWidth,
      );
    });
  }

  Future<void> _savePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expandedKey, _expanded);
    await prefs.setDouble(_widthKey, _width);
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      _isDragging = false;
    });
    _savePreference();
  }

  void _resize(double delta) {
    setState(() {
      _expanded = true;
      _isDragging = true;
      _width = (_width + delta).clamp(widget.minWidth, widget.maxWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeWidth = _expanded ? _width : widget.collapsedWidth;

    return AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: activeWidth,
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(right: BorderSide(color: kBorder, width: 1)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: _expanded
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _expanded ? 16 : 10),
                child: Row(
                  mainAxisAlignment: _expanded
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (_expanded)
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kTextMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    Tooltip(
                      message: _expanded
                          ? 'Navigatie inklappen'
                          : 'Navigatie uitklappen',
                      child: IconButton(
                        onPressed: _toggleExpanded,
                        style: IconButton.styleFrom(
                          foregroundColor: kTextSecondary,
                          backgroundColor: kSurfaceMuted,
                          hoverColor: kSurfaceHover,
                          fixedSize: const Size(38, 38),
                          minimumSize: const Size(38, 38),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusMd),
                            side: const BorderSide(color: kBorder),
                          ),
                        ),
                        icon: Icon(
                          _expanded
                              ? Icons.keyboard_double_arrow_left_rounded
                              : Icons.keyboard_double_arrow_right_rounded,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: widget.childBuilder(context, _expanded)),
              if (_expanded && widget.footer != null) widget.footer!,
            ],
          ),
          if (_expanded)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: 8,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) =>
                      _resize(details.delta.dx),
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _isDragging = false;
                    });
                    _savePreference();
                  },
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: _isDragging ? 2 : 1,
                      color: _isDragging ? kBrandGreenDark : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
