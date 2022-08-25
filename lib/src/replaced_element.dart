import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/anchor.dart';
import 'package:flutter_html/src/html_elements.dart';
import 'package:flutter_html/style.dart';
import 'package:html/dom.dart' as dom;

/// A [ReplacedElement] is a type of [StyledElement] that does not require its [children] to be rendered.
///
/// A [ReplacedElement] may use its children nodes to determine relevant information
/// (e.g. <video>'s <source> tags), but the children nodes will not be saved as [children].
abstract class ReplacedElement extends StyledElement {
  PlaceholderAlignment alignment;

  ReplacedElement({
    required super.name,
    required super.style,
    required super.elementId,
    required super.containingBlockSize,
    List<StyledElement>? children,
    super.node,
    this.alignment = PlaceholderAlignment.aboveBaseline,
  }) : super(children: children ?? []);

  static List<String?> parseMediaSources(List<dom.Element> elements) {
    return elements
        .where((element) => element.localName == 'source')
        .map((element) {
      return element.attributes['src'];
    }).toList();
  }

  Widget? toWidget(RenderContext context);
}

/// [TextContentElement] is a [ContentElement] with plaintext as its content.
class TextContentElement extends ReplacedElement {
  String? text;
  dom.Node? node;

  TextContentElement({
    required Style style,
    required this.text,
    this.node,
    dom.Element? element,
    required super.containingBlockSize,
  }) : super(name: "[text]", style: style, node: element, elementId: "[[No ID]]");

  @override
  String toString() {
    return "\"${text!.replaceAll("\n", "\\n")}\"";
  }

  @override
  Widget? toWidget(_) => null;
}

class EmptyContentElement extends ReplacedElement {
  EmptyContentElement({String name = "empty"}) : super(name: name, style: Style(), elementId: "[[No ID]]", containingBlockSize: Size.zero);

  @override
  Widget? toWidget(_) => null;
}

class RubyElement extends ReplacedElement {
  dom.Element element;

  RubyElement({
    required this.element,
    required List<StyledElement> children,
    String name = "ruby",
    required super.containingBlockSize,
  }) : super(name: name, alignment: PlaceholderAlignment.middle, style: Style(), elementId: element.id, children: children);

  @override
  Widget toWidget(RenderContext context) {
    StyledElement? node;
    List<Widget> widgets = <Widget>[];
    final rubySize = context.parser.style['rt']?.fontSize?.size ?? max(9.0, context.style.fontSize!.size! / 2);
    final rubyYPos = rubySize + rubySize / 2;
    List<StyledElement> children = [];
    context.tree.children.forEachIndexed((index, element) {
      if (!((element is TextContentElement)
          && (element.text ?? "").trim().isEmpty
          && index > 0
          && index + 1 < context.tree.children.length
          && !(context.tree.children[index - 1] is TextContentElement)
          && !(context.tree.children[index + 1] is TextContentElement))) {
        children.add(element);
      }
    });
    children.forEach((c) {
      if (c.name == "rt" && node != null) {
        final widget = Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
                alignment: Alignment.bottomCenter,
                child: Center(
                    child: Transform(
                        transform:
                        Matrix4.translationValues(0, -(rubyYPos), 0),
                        child: ContainerSpan(
                          renderContext: RenderContext(
                            buildContext: context.buildContext,
                            parser: context.parser,
                            style: c.style,
                            tree: c,
                          ),
                          style: c.style,
                          containingBlockSize: containingBlockSize,
                          child: Text(c.element!.innerHtml,
                              style: c.style
                                  .generateTextStyle()
                                  .copyWith(fontSize: rubySize)),
                        )))),
            ContainerSpan(
                renderContext: context,
                style: context.style,
                containingBlockSize: containingBlockSize,
                child: node is TextContentElement ? Text((node as TextContentElement).text?.trim() ?? "",
                    style: context.style.generateTextStyle()) : null,
                children: node is TextContentElement ? null : [context.parser.parseTree(context, node!)]),
          ],
        );
        widgets.add(widget);
      } else {
        node = c;
      }
    });
    return Padding(
      padding: EdgeInsets.only(top: rubySize),
      child: Wrap(
        key: AnchorKey.of(context.parser.key, this),
        runSpacing: rubySize,
        children: widgets.map((e) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [e],
        )).toList(),
      ),
    );
  }
}

ReplacedElement parseReplacedElement(
  dom.Element element,
  List<StyledElement> children,
  Size containingBlockSize,
) {
  switch (element.localName) {
    case "br":
      return TextContentElement(
        text: "\n",
        style: Style(whiteSpace: WhiteSpace.PRE),
        element: element,
        node: element,
        containingBlockSize: containingBlockSize,
      );
    case "ruby":
      return RubyElement(
        element: element,
        children: children,
        containingBlockSize: containingBlockSize,
      );
    default:
      return EmptyContentElement(name: element.localName == null ? "[[No Name]]" : element.localName!);
  }
}
