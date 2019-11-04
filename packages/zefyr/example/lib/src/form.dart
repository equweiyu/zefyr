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

class _FormEmbeddedScreenState extends State<FormEmbeddedScreen> {
  ZefyrController _controller;
  final FocusNode _focusNode = FocusNode();

  bool _handleTap(TextSelection value, ZefyrController controller) {
    final style =
        controller.document.collectStyle(value.start, value.end - value.start);
    if (style.contains(NotusAttribute.embed)) {
      EmbedAttribute embed = style.get(NotusAttribute.embed);
      if (embed.type == EmbedType.image) {
        print('tap image');
        // controller.change(
        // value,
        // NotusAttribute.embed.image(
        //     'https://image.xiniujiao.net/5cb8cee206d7051bf88cef29270855f5.jpg'));
      }
      return true;
    }
    return false;
  }

  bool _handleLongPress(TextSelection value, ZefyrController controller) {
    final style =
        controller.document.collectStyle(value.start, value.end - value.start);
    if (style.contains(NotusAttribute.link)) {
      // controller.formatSelection(NotusAttribute.link.fromString('123123'));
      print('tag link');
      return false;
    }
    return false;
  }

  @override
  void initState() {
    _controller = ZefyrController(
      NotusDocument(),
      handleTap: (value) => _handleTap(value, _controller),
      handleLongPress: (value) => _handleLongPress(value, _controller),
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
      body: ZefyrScaffold(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: form,
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
}
