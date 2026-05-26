import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Wrapper que intercepta o scroll do mouse e anima suavemente.
/// Elimina o "pulo" de quadro em quadro do Flutter Web.
class SmoothListView extends StatefulWidget {
  final ScrollController controller;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final EdgeInsetsGeometry? padding;
  final double scrollSpeed;

  const SmoothListView({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.scrollSpeed = 80.0,
  });

  @override
  State<SmoothListView> createState() => _SmoothListViewState();
}

class _SmoothListViewState extends State<SmoothListView> {
  double _targetOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncTarget);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncTarget);
    super.dispose();
  }

  void _syncTarget() {
    // Mantém target sincronizado com posição real (ex: drag, programático)
    if (!widget.controller.hasClients) return;
    if (!widget.controller.position.isScrollingNotifier.value) {
      _targetOffset = widget.controller.offset;
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent && widget.controller.hasClients) {
      final direction = event.scrollDelta.dy > 0 ? 1.0 : -1.0;
      final max = widget.controller.position.maxScrollExtent;
      _targetOffset = (_targetOffset + direction * widget.scrollSpeed).clamp(0.0, max);
      widget.controller.animateTo(
        _targetOffset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: widget.separatorBuilder != null
          ? ListView.separated(
              controller: widget.controller,
              physics: const NeverScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: widget.itemCount,
              separatorBuilder: widget.separatorBuilder!,
              itemBuilder: widget.itemBuilder,
            )
          : ListView.builder(
              controller: widget.controller,
              physics: const NeverScrollableScrollPhysics(),
              padding: widget.padding,
              itemCount: widget.itemCount,
              itemBuilder: widget.itemBuilder,
            ),
    );
  }
}
