import 'package:flutter/material.dart';

class InputSheet extends StatefulWidget {
  const InputSheet({
    super.key,
    required this.isVisible,
    required this.controller,
    required this.focusNode,
    required this.title,
    required this.hintText,
    required this.onDismissRequested,
    this.onOpened,
    this.onClosed,
    this.minLines = 6,
  });

  final bool isVisible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final String hintText;
  final VoidCallback onDismissRequested;
  final VoidCallback? onOpened;
  final VoidCallback? onClosed;
  final int minLines;

  @override
  State<InputSheet> createState() => _InputSheetState();
}

class _InputSheetState extends State<InputSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;
  AnimationStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    )..addStatusListener(_handleStatusChange);

    if (widget.isVisible) {
      _controller.value = 1;
      _requestFocus();
    }
  }

  @override
  void didUpdateWidget(InputSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _controller.forward();
      _requestFocus();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      widget.focusNode.unfocus();
      _controller.reverse();
    } else if (widget.focusNode != oldWidget.focusNode && widget.isVisible) {
      _requestFocus();
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (_lastStatus == status) {
      return;
    }
    _lastStatus = status;
    switch (status) {
      case AnimationStatus.completed:
        widget.onOpened?.call();
        break;
      case AnimationStatus.dismissed:
        widget.onClosed?.call();
        break;
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isVisible && !widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _curve.removeStatusListener(_handleStatusChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    widget.onDismissRequested();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? _) {
        final double t = _curve.value;
        final bool isInactive =
            t == 0 && _controller.status == AnimationStatus.dismissed;
        if (isInactive) {
          return const SizedBox.shrink();
        }

        final ThemeData theme = Theme.of(context);
        final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

        return IgnorePointer(
          ignoring: t == 0,
          child: Stack(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleDismiss,
                child: Container(
                  color: theme.colorScheme.scrim.withOpacity(
                    0.3 * t.clamp(0.0, 1.0),
                  ),
                ),
              ),
              FractionalTranslation(
                translation: Offset(0, 1 - t),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: EdgeInsets.only(bottom: keyboardInset),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: theme.colorScheme.shadow.withOpacity(
                              0.12 * t.clamp(0.0, 1.0),
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
                            child: Row(
                              children: <Widget>[
                                const SizedBox(width: 48),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _handleDismiss,
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        theme.colorScheme.primary,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              child: TextField(
                                controller: widget.controller,
                                focusNode: widget.focusNode,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: widget.minLines,
                                maxLines: null,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  isCollapsed: true,
                                  hintText: widget.hintText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
