// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';

import 'editable_box.dart';

abstract class ZefyrUnknowDelegate<S> {
  Widget buildUnknow(BuildContext context, Map<String, dynamic> value);
}

class Unknow extends StatefulWidget {
  const Unknow({Key key, @required this.node, @required this.delegate})
      : super(key: key);
  @override
  _UnknowState createState() => _UnknowState();
  final EmbedNode node;
  final ZefyrUnknowDelegate delegate;
}

class _UnknowState extends State<Unknow> {
  @override
  Widget build(BuildContext context) {
    EmbedAttribute attribute = widget.node.style.get(NotusAttribute.embed);
    return _EditableUnknow(
      child: widget.delegate.buildUnknow(context, attribute.value),
      node: widget.node,
    );
  }
}

class _EditableUnknow extends SingleChildRenderObjectWidget {
  _EditableUnknow({@required Widget child, @required this.node})
      : assert(node != null),
        super(child: child);

  final EmbedNode node;

  @override
  RenderEditableUnknow createRenderObject(BuildContext context) {
    return RenderEditableUnknow(node: node);
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderEditableUnknow renderObject) {
    renderObject..node = node;
  }
}

class RenderEditableUnknow extends RenderBox
    with RenderObjectWithChildMixin<RenderBox>, RenderProxyBoxMixin<RenderBox>
    implements RenderEditableBox {
  static const kPaddingBottom = 24.0;

  RenderEditableUnknow({
    RenderImage child,
    @required EmbedNode node,
  }) : _node = node {
    this.child = child;
  }

  @override
  EmbedNode get node => _node;
  EmbedNode _node;
  set node(EmbedNode value) {
    _node = value;
  }

  @override
  double get preferredLineHeight => size.height - kPaddingBottom + 2.0;

  @override
  SelectionOrder get selectionOrder => SelectionOrder.foreground;

  @override
  TextSelection getLocalSelection(TextSelection documentSelection) {
    if (!intersectsWithSelection(documentSelection)) return null;

    int nodeBase = node.documentOffset;
    int nodeExtent = nodeBase + node.length;
    int base = math.max(0, documentSelection.baseOffset - nodeBase);
    int extent =
        math.min(documentSelection.extentOffset, nodeExtent) - nodeBase;
    return documentSelection.copyWith(baseOffset: base, extentOffset: extent);
  }

  @override
  List<ui.TextBox> getEndpointsForSelection(TextSelection selection) {
    TextSelection local = getLocalSelection(selection);
    if (local.isCollapsed) {
      final dx = local.extentOffset == 0 ? _childOffset.dx : size.width;
      return [
        ui.TextBox.fromLTRBD(
            dx, 0.0, dx, size.height - kPaddingBottom, TextDirection.ltr),
      ];
    }

    final rect = _childRect;
    return [
      ui.TextBox.fromLTRBD(
          rect.left, rect.top, rect.left, rect.bottom, TextDirection.ltr),
      ui.TextBox.fromLTRBD(
          rect.right, rect.top, rect.right, rect.bottom, TextDirection.ltr),
    ];
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    int position = _node.documentOffset;

    if (offset.dx > size.width / 2) {
      position++;
    }
    return TextPosition(offset: position);
  }

  @override
  TextRange getWordBoundary(TextPosition position) {
    final start = _node.documentOffset;
    return TextRange(start: start, end: start + 1);
  }

  @override
  bool intersectsWithSelection(TextSelection selection) {
    final int base = node.documentOffset;
    final int extent = base + node.length;
    return base <= selection.extentOffset && selection.baseOffset <= extent;
  }

  @override
  Offset getOffsetForCaret(TextPosition position, Rect caretPrototype) {
    final pos = position.offset - node.documentOffset;
    Offset caretOffset = _childOffset - Offset(kHorizontalPadding, 0.0);
    if (pos == 1) {
      caretOffset =
          caretOffset + Offset(_lastChildSize.width + kHorizontalPadding, 0.0);
    }
    return caretOffset;
  }

  @override
  void paintSelection(PaintingContext context, Offset offset,
      TextSelection selection, Color selectionColor) {
    final localSelection = getLocalSelection(selection);
    assert(localSelection != null);
    if (!localSelection.isCollapsed) {
      final Paint paint = Paint()
        ..color = selectionColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final rect =
          Rect.fromLTWH(0.0, 0.0, _lastChildSize.width, _lastChildSize.height);
      context.canvas.drawRect(rect.shift(offset + _childOffset), paint);
    }
  }

  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset + _childOffset);
  }

  static const double kHorizontalPadding = 1.0;

  Size _lastChildSize;

  Offset get _childOffset {
    final dx = (size.width - _lastChildSize.width) / 2 + kHorizontalPadding;
    final dy = (size.height - _lastChildSize.height - kPaddingBottom) / 2;
    return Offset(dx, dy);
  }

  Rect get _childRect {
    return Rect.fromLTWH(_childOffset.dx, _childOffset.dy, _lastChildSize.width,
        _lastChildSize.height);
  }

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth);

    if (child != null) {
      child.layout(constraints, parentUsesSize: true);
      _lastChildSize = child.size;
      size = Size(constraints.maxWidth, _lastChildSize.height + kPaddingBottom);
    } else {
      performResize();
    }
  }
}
