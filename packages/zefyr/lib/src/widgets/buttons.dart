// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';

import 'theme.dart';
import 'toolbar.dart';

/// A button used in [ZefyrToolbar].
///
/// Create an instance of this widget with [ZefyrButton.icon] or
/// [ZefyrButton.text] constructors.
///
/// Toolbar buttons are normally created by a [ZefyrToolbarDelegate].
class ZefyrButton extends StatelessWidget {
  /// Creates a toolbar button with an icon.
  ZefyrButton.icon({
    @required IconData icon,
    double iconSize = 20.0,
    this.onPressed,
  })  : assert(icon != null),
        _icon = icon,
        _iconSize = iconSize,
        _text = null,
        _textStyle = null,
        super();

  /// Creates a toolbar button containing text.
  ///
  /// Note that [ZefyrButton] has fixed width and does not expand to accommodate
  /// long texts.
  ZefyrButton.text({
    @required String text,
    TextStyle style,
    this.onPressed,
  })  : assert(text != null),
        _icon = null,
        _iconSize = null,
        _text = text,
        _textStyle = style,
        super();

  final IconData _icon;
  final double _iconSize;
  final String _text;
  final TextStyle _textStyle;

  /// Callback to trigger when this button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    final iconColor = (onPressed == null)
        ? toolbarTheme.disabledIconColor
        : toolbarTheme.iconColor;
    if (_icon != null) {
      return RawZefyrButton.icon(
        icon: _icon,
        size: _iconSize,
        iconColor: iconColor,
        color: toolbarTheme.color,
        onPressed: onPressed,
      );
    } else {
      assert(_text != null);
      var style = _textStyle ?? TextStyle();
      style = style.copyWith(color: iconColor);
      return RawZefyrButton(
        child: Text(_text, style: style),
        color: toolbarTheme.color,
        onPressed: onPressed,
      );
    }
  }
}

/// Raw button widget used by [ZefyrToolbar].
///
/// See also:
///
///   * [ZefyrButton], which wraps this widget and implements most of the
///     action-specific logic.
class RawZefyrButton extends StatelessWidget {
  const RawZefyrButton({
    Key key,
    @required this.child,
    @required this.color,
    @required this.onPressed,
  }) : super(key: key);

  /// Creates a [RawZefyrButton] containing an icon.
  RawZefyrButton.icon({
    @required IconData icon,
    double size,
    Color iconColor,
    @required this.color,
    @required this.onPressed,
  })  : child = Icon(icon, size: size, color: iconColor),
        super();

  /// Child widget to show inside this button. Usually an icon.
  final Widget child;

  /// Background color of this button.
  final Color color;

  /// Callback to trigger when this button is pressed.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = theme.buttonTheme.constraints.minHeight + 4.0;
    final constraints = theme.buttonTheme.constraints.copyWith(
        minWidth: width, maxHeight: theme.buttonTheme.constraints.minHeight);
    final radius = BorderRadius.all(Radius.circular(3.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 6.0),
      child: RawMaterialButton(
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 0.0,
        fillColor: color,
        constraints: constraints,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
