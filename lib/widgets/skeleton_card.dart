import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Pulsing grey placeholder shown while template thumbnails are loading.
/// Uses a single AnimationController shared across all cards via
/// [SkeletonScope] to keep CPU use minimal.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final animation = SkeletonScope.of(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final shade = Color.lerp(
          Colors.grey.shade200,
          Colors.grey.shade350,
          animation.value,
        )!;
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: ColoredBox(color: shade),
              ),
              Padding(
                padding: const EdgeInsets.all(kSpaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(color: shade, width: double.infinity, height: 13),
                    const SizedBox(height: kSpaceXs),
                    _Bar(color: shade, width: 56, height: 11),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.width, required this.height});
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

// ---------------------------------------------------------------------------
// SkeletonScope — one AnimationController for the whole skeleton grid.
// ---------------------------------------------------------------------------
class SkeletonScope extends StatefulWidget {
  const SkeletonScope({super.key, required this.child});
  final Widget child;

  static Animation<double> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_SkeletonInheritedWidget>();
    assert(scope != null, 'No SkeletonScope found in widget tree');
    return scope!.animation;
  }

  @override
  State<SkeletonScope> createState() => _SkeletonScopeState();
}

class _SkeletonScopeState extends State<SkeletonScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SkeletonInheritedWidget(
        animation: _animation,
        child: widget.child,
      );
}

class _SkeletonInheritedWidget extends InheritedWidget {
  const _SkeletonInheritedWidget({
    required this.animation,
    required super.child,
  });
  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonInheritedWidget old) => false;
}
