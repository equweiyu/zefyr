// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:notus/notus.dart';
import 'package:quill_delta/quill_delta.dart';
import 'package:zefyr/util.dart';
import 'package:zefyr/zefyr.dart';

import 'editable_box.dart';

const TextSelection _kZeroSelection = TextSelection.collapsed(
  offset: 0,
  affinity: TextAffinity.upstream,
);

/// Owner of focus.
enum FocusOwner {
  /// Current owner is the editor.
  editor,

  /// Current owner is the toolbar.
  toolbar,

  /// No focus owner.
  none,
}

abstract class ZefyrControllerDelegate {
  /// 返回值 是否替换原来的事件
  bool handleLongPress(
      TextSelection value, RenderEditableProxyBox box, Offset offset);

  /// 返回值 是否替换原来的事件
  bool handleTap(
      TextSelection value, RenderEditableProxyBox box, Offset offset);
  bool replaceText(int index, int length, String text,
      {TextSelection selection});
}

/// Controls instance of [ZefyrEditor].
class ZefyrController extends ChangeNotifier {
  ZefyrController(
    NotusDocument document, {
    this.delegate,
  })  : assert(document != null),
        _document = document;
  final ZefyrControllerDelegate delegate;

  /// Zefyr document managed by this controller.
  NotusDocument get document => _document;
  NotusDocument _document;

  /// Currently selected text within the [document].
  TextSelection get selection => _selection;
  TextSelection _selection = _kZeroSelection;

  ChangeSource _lastChangeSource;

  /// Source of the last text or selection change.
  ChangeSource get lastChangeSource => _lastChangeSource;

  /// Store any styles attribute that got toggled by the tap of a button
  /// and that has not been applied yet.
  /// It gets reseted after each format action within the [document].
  NotusStyle get toggledStyles => _toggledStyles;
  NotusStyle _toggledStyles = new NotusStyle();

  /// Updates selection with specified [value].
  ///
  /// [value] and [source] cannot be `null`.
  void updateSelection(TextSelection value,
      {ChangeSource source = ChangeSource.remote}) {
    _updateSelectionSilent(value, source: source);
    notifyListeners();
  }

  // Updates selection without triggering notifications to listeners.
  void _updateSelectionSilent(TextSelection value,
      {ChangeSource source = ChangeSource.remote}) {
    assert(value != null && source != null);
    _selection = value;
    _lastChangeSource = source;
    _ensureSelectionBeforeLastBreak();
  }

  @override
  void dispose() {
    _document.close();
    super.dispose();
  }

  /// Composes [change] into document managed by this controller.
  ///
  /// This method does not apply any adjustments or heuristic rules to
  /// provided [change] and it is caller's responsibility to ensure this change
  /// can be composed without errors.
  ///
  /// If composing this change fails then this method throws [ComposeError].
  void compose(Delta change,
      {TextSelection selection, ChangeSource source = ChangeSource.remote}) {
    if (change.isNotEmpty) {
      _document.compose(change, source);
    }
    if (selection != null) {
      _updateSelectionSilent(selection, source: source);
    } else {
      // Transform selection against the composed change and give priority to
      // current position (force: false).
      final base =
          change.transformPosition(_selection.baseOffset, force: false);
      final extent =
          change.transformPosition(_selection.extentOffset, force: false);
      selection = _selection.copyWith(baseOffset: base, extentOffset: extent);
      if (_selection != selection) {
        _updateSelectionSilent(selection, source: source);
      }
    }
    _lastChangeSource = source;
    notifyListeners();
  }

  /// Replaces [length] characters in the document starting at [index] with
  /// provided [text].
  ///
  /// Resulting change is registered as produced by user action, e.g.
  /// using [ChangeSource.local].
  ///
  /// It also applies the toggledStyle if needed. And then it resets it
  /// in any cases as we don't want to keep it except on inserts.
  ///
  /// Optionally updates selection if provided.
  void replaceText(int index, int length, String text,
      {TextSelection selection}) {
    ensureVisibleTag = true;

    if (delegate?.replaceText(index, length, text, selection: selection) ==
        true) {
      notifyListeners();

      return;
    }

    Delta delta;

    if (length > 0 || text.isNotEmpty) {
      delta = document.replace(index, length, text);
      // If the delta is a classical insert operation and we have toggled
      // some style, then we apply it to our document.
      if (delta != null &&
          toggledStyles.isNotEmpty &&
          delta.isNotEmpty &&
          delta.length <= 2 &&
          delta.last.isInsert) {
        // Apply it.
        Delta retainDelta = new Delta()
          ..retain(index)
          ..retain(text.length, toggledStyles.toJson());
        document.compose(retainDelta, ChangeSource.local);
      }
    }

    // Always reset it after any user action, even if it has not been applied.
    _toggledStyles = new NotusStyle();

    if (selection != null) {
      if (delta == null) {
        _updateSelectionSilent(selection, source: ChangeSource.local);
      } else {
        // need to transform selection position in case actual delta
        // is different from user's version (in deletes and inserts).
        Delta user = Delta()
          ..retain(index)
          ..insert(text)
          ..delete(length);
        int positionDelta = getPositionDelta(user, delta);
        _updateSelectionSilent(
          selection.copyWith(
            baseOffset: selection.baseOffset + positionDelta,
            extentOffset: selection.extentOffset + positionDelta,
          ),
          source: ChangeSource.local,
        );
      }
    }
    _lastChangeSource = ChangeSource.local;
    notifyListeners();
  }

  void formatText(int index, int length, NotusAttribute attribute) {
    ensureVisibleTag = true;

    final change = document.format(index, length, attribute);
    _lastChangeSource = ChangeSource.local;

    if (length == 0 &&
        (attribute.key == NotusAttribute.bold.key ||
            attribute.key == NotusAttribute.italic.key ||
            attribute.key == NotusAttribute.underline.key)) {
      // Add the attribute to our toggledStyle. It will be used later upon insertion.
      _toggledStyles = toggledStyles.put(attribute);
    }

    // Transform selection against the composed change and give priority to
    // the change. This is needed in cases when format operation actually
    // inserts data into the document (e.g. embeds).
    final base = change.transformPosition(_selection.baseOffset);
    final extent = change.transformPosition(_selection.extentOffset);
    final adjustedSelection =
        _selection.copyWith(baseOffset: base, extentOffset: extent);
    if (_selection != adjustedSelection) {
      _updateSelectionSilent(adjustedSelection, source: _lastChangeSource);
    }
    notifyListeners();
  }

  /// Formats current selection with [attribute].
  void formatSelection(NotusAttribute attribute, {TextSelection selection}) {
    ensureVisibleTag = true;

    final value = selection ?? _selection;
    int index = value.start;
    int length = value.end - index;
    formatText(index, length, attribute);
  }

  void delete(bool Function(String data, NotusStyle style) test) {
    DeltaIterator iter = DeltaIterator(_document.toDelta());
    int s = 0;
    while (iter.hasNext) {
      int opLength = iter.peekLength();
      Operation op = iter.next(opLength);
      if (test(op.data, NotusStyle.fromJson(op.attributes))) {
        replaceText(s, op.data.length, '', selection: _selection);
        iter = DeltaIterator(_document.toDelta());
        s = 0;
        continue;
      }
      s += op.data.length;
    }
  }

  void deleteFrist(bool Function(String data, NotusStyle style) test) {
    DeltaIterator iter = DeltaIterator(_document.toDelta());
    int s = 0;
    while (iter.hasNext) {
      int opLength = iter.peekLength();
      Operation op = iter.next(opLength);
      if (test(op.data, NotusStyle.fromJson(op.attributes))) {
        replaceText(s, op.data.length, '', selection: _selection);
        return;
      }
      s += op.data.length;
    }
  }

  void insert(String string, NotusAttribute attribute) {
    ensureVisibleTag = true;
    final index = _selection.end;
    DeltaIterator iter = DeltaIterator(_document.toDelta());
    final previous = iter.skip(index);

    final hasEmbed = (previous != null &&
        previous.attributes != null &&
        previous.attributes.containsKey(NotusAttribute.embed.key));
    Delta change = Delta()..retain(index);
    if (hasEmbed) {
      change..insert('\n');
    }
    final style = _document.collectStyle(index, 0);
    final result = _document.lookupLine(index);
    LineNode line = result.node;
    final r = line.lookup(result.offset, inclusive: true);
    LeafNode leaf = r.node;
    if (leaf != null) {
      int length = leaf.value.length;
      if ((r.offset != 0 && length != r.offset) &&
          (style.contains(NotusAttribute.link) ||
              style.contains(NotusAttribute.game))) {
        return;
      }
    }

    change.insert(string, attribute.toJson());
    _document.compose(change, ChangeSource.local);
    updateSelection(
        TextSelection.collapsed(
            offset: _selection.end + string.length + (hasEmbed ? 1 : 0)),
        source: ChangeSource.local);
  }

  void change(TextSelection value, EmbedAttribute attribute) {
    int index = value.start;
    int length = value.end - value.start;
    Delta result = Delta()..retain(index);
    Delta change = result..retain(length, attribute.toJson());
    _document.compose(change, ChangeSource.local);
    updateSelection(TextSelection.collapsed(offset: value.end),
        source: ChangeSource.local);
  }

  /// Returns style of specified text range.
  ///
  /// If nothing is selected but we've toggled an attribute,
  ///  we also merge those in our style before returning.
  NotusStyle getSelectionStyle() {
    int start = _selection.start;
    int length = _selection.end - start;
    var lineStyle = _document.collectStyle(start, length);

    lineStyle = lineStyle.mergeAll(toggledStyles);

    return lineStyle;
  }

  TextEditingValue get plainTextEditingValue {
    return TextEditingValue(
      text: document.toPlainText(),
      selection: selection,
      composing: TextRange.collapsed(0),
    );
  }

  void _ensureSelectionBeforeLastBreak() {
    final end = _document.length - 1;
    final base = math.min(_selection.baseOffset, end);
    final extent = math.min(_selection.extentOffset, end);
    _selection = _selection.copyWith(baseOffset: base, extentOffset: extent);
  }
}
