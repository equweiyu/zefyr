// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zefyr/zefyr.dart';

import 'full_page.dart';
import 'images.dart';

class FormEmbeddedScreen extends StatefulWidget {
  @override
  _FormEmbeddedScreenState createState() => _FormEmbeddedScreenState();
}

class _FormEmbeddedScreenState extends State<FormEmbeddedScreen>
    implements ZefyrControllerDelegate {
  ZefyrController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    _controller = ZefyrController(
      NotusDocument(),
      delegate: this,
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final form = ListView(
      children: <Widget>[
        TextField(decoration: InputDecoration(labelText: 'Name')),
        buildEditor(),
        TextField(decoration: InputDecoration(labelText: 'Email')),
      ],
    );
    return Scaffold(
      resizeToAvoidBottomPadding: true,
      appBar: AppBar(
        elevation: 1.0,
        backgroundColor: Colors.grey.shade200,
        brightness: Brightness.light,
        title: ZefyrLogo(),
        actions: <Widget>[
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.save),
              onPressed: () => _saveDocument(context),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: ZefyrScaffold(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: form,
          ),
        ),
      ),
    );
  }

  void _saveDocument(BuildContext context) {
    final contents = jsonEncode(_controller.document);
    print(contents);
  }

  Widget buildEditor() {
    final theme = ZefyrThemeData(
      toolbarTheme: ZefyrToolbarTheme.fallback(context).copyWith(
        color: Colors.grey.shade800,
        toggleColor: Colors.grey.shade900,
        iconColor: Colors.white,
        disabledIconColor: Colors.grey.shade500,
      ),
    );
    return ZefyrTheme(
      data: theme,
      child: ZefyrField(
        height: 200.0,
        decoration: InputDecoration(labelText: 'Description'),
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        imageDelegate: CustomImageDelegate(),
        physics: ClampingScrollPhysics(),
      ),
    );
  }

  @override
  bool handleLongPress(
      TextSelection value, RenderEditableProxyBox box, Offset offset) {
    return false;
  }

  @override
  bool handleTap(
      TextSelection value, RenderEditableProxyBox box, Offset offset) {
    final style =
        _controller.document.collectStyle(value.start, value.end - value.start);
    if (style.contains(NotusAttribute.embed)) {
      final result = _controller.document.lookupLine(value.start);
      LineNode line = result.node;
      final r = line.lookup(result.offset, inclusive: true);
      LeafNode leaf = r.node;
      int index = value.start - r.offset;
      int length = leaf.value.length;
      _controller.updateSelection(value.copyWith(
        baseOffset: index,
        extentOffset: index + length,
      ));
      return true;
    }
    return false;
  }

  @override
  bool replaceText(int index, int length, String text,
      {TextSelection selection}) {
    return false;
  }

  @override
  bool showSelectionHandle(TextSelection value) {
    final style =
        _controller.document.collectStyle(value.start, value.end - value.start);
    if (style.contains(NotusAttribute.embed)) return false;
    return true;
  }
}
