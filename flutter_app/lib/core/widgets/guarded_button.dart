import 'package:flutter/material.dart';

/// A drop-in replacement for [ElevatedButton] that accepts an **async**
/// onPressed callback. It automatically:
///   • disables itself after the first tap
///   • shows a small circular progress indicator instead of the label
///   • re-enables once the Future resolves (success or error)
///
/// This prevents accidental double-submissions on slow connections.
class GuardedElevatedButton extends StatefulWidget {
  const GuardedElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.loadingColor = Colors.white,
  });

  final Future<void> Function()? onPressed;
  final Widget child;
  final ButtonStyle? style;

  /// Color of the loading spinner shown while the action runs.
  final Color loadingColor;

  @override
  State<GuardedElevatedButton> createState() =>
      _GuardedElevatedButtonState();
}

class _GuardedElevatedButtonState
    extends State<GuardedElevatedButton> {
  bool _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed:
          (_loading || widget.onPressed == null) ? null : _run,
      style: widget.style,
      child: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: widget.loadingColor,
              ),
            )
          : widget.child,
    );
  }
}

/// A drop-in replacement for [FloatingActionButton] with the same
/// auto-disable + spinner behaviour as [GuardedElevatedButton].
class GuardedFab extends StatefulWidget {
  const GuardedFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.heroTag,
    this.mini = false,
    this.tooltip,
    this.elevation,
  });

  final Future<void> Function()? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Object? heroTag;
  final bool mini;
  final String? tooltip;
  final double? elevation;

  @override
  State<GuardedFab> createState() => _GuardedFabState();
}

class _GuardedFabState extends State<GuardedFab> {
  bool _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed:
          (_loading || widget.onPressed == null) ? null : _run,
      backgroundColor: widget.backgroundColor,
      foregroundColor: widget.foregroundColor,
      heroTag: widget.heroTag,
      mini: widget.mini,
      tooltip: widget.tooltip,
      elevation: widget.elevation,
      child: _loading
          ? SizedBox(
              width: widget.mini ? 16 : 22,
              height: widget.mini ? 16 : 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: widget.foregroundColor ?? Colors.white,
              ),
            )
          : widget.child,
    );
  }
}

/// A guard for [IconButton] / plain [GestureDetector] actions.
/// Wraps any async callback so it can only run one instance at a time.
class GuardedIconButton extends StatefulWidget {
  const GuardedIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.color,
    this.iconSize,
    this.tooltip,
    this.padding,
  });

  final Future<void> Function()? onPressed;
  final Widget icon;
  final Color? color;
  final double? iconSize;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;

  @override
  State<GuardedIconButton> createState() => _GuardedIconButtonState();
}

class _GuardedIconButtonState extends State<GuardedIconButton> {
  bool _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed:
          (_loading || widget.onPressed == null) ? null : _run,
      icon: _loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.color ?? Theme.of(context).primaryColor,
              ),
            )
          : widget.icon,
      color: widget.color,
      iconSize: widget.iconSize,
      tooltip: widget.tooltip,
      padding: widget.padding,
    );
  }
}
