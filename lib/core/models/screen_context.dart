/// Structured snapshot of the visible screen produced by the optional
/// accessibility engine. Password fields are never represented here.
class ScreenContext {
  const ScreenContext({
    required this.status,
    required this.timestamp,
    this.packageName,
    this.windowTitle,
    this.visibleText = '',
    this.interactiveElements = const <ScreenElement>[],
    this.focusedElement,
    this.truncated = false,
    this.nodeCount = 0,
  });

  /// `ok` | `empty` | `timeout` — honest extraction outcome.
  final String status;
  final int timestamp;
  final String? packageName;
  final String? windowTitle;
  final String visibleText;
  final List<ScreenElement> interactiveElements;
  final ScreenElement? focusedElement;
  final bool truncated;
  final int nodeCount;

  bool get isOk => status == 'ok';

  static ScreenContext fromMap(Map<Object?, Object?> map) {
    final rawElements = (map['elements'] as List<Object?>?) ?? const <Object?>[];
    return ScreenContext(
      status: (map['status'] as String?) ?? 'empty',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      packageName: map['packageName'] as String?,
      windowTitle: map['windowTitle'] as String?,
      visibleText: (map['visibleText'] as String?) ?? '',
      interactiveElements: rawElements
          .whereType<Map<Object?, Object?>>()
          .map(ScreenElement.fromMap)
          .toList(growable: false),
      focusedElement: null,
      truncated: (map['truncated'] as bool?) ?? false,
      nodeCount: (map['nodeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One interactive node of a [ScreenContext]. Bounds are screen coordinates
/// used as a stable signature for follow-up actions.
class ScreenElement {
  const ScreenElement({
    required this.id,
    required this.clickable,
    required this.editable,
    required this.scrollable,
    required this.visible,
    this.text,
    this.contentDescription,
    this.className,
    this.viewId,
    this.bounds = const <int>[],
  });

  final String id;
  final bool clickable;
  final bool editable;
  final bool scrollable;
  final bool visible;
  final String? text;
  final String? contentDescription;
  final String? className;
  final String? viewId;
  final List<int> bounds;

  String get label => (text?.trim().isNotEmpty ?? false)
      ? text!.trim()
      : (contentDescription?.trim() ?? className ?? viewId ?? id);

  bool get isInputElement =>
      (className?.contains('EditText') ?? false) || editable;

  String get signatureJson {
    final buffer = StringBuffer('{');
    if (viewId != null) buffer.write('"viewId":"${_escape(viewId!)}",');
    if (bounds.length == 4) {
      buffer
        ..write('"bounds":[')
        ..write(bounds.join(','))
        ..write(']');
    }
    buffer.write('}');
    return buffer.toString();
  }

  static ScreenElement fromMap(Map<Object?, Object?> map) {
    final rawBounds = (map['bounds'] as List<Object?>?) ?? const <Object?>[];
    return ScreenElement(
      id: (map['id'] as String?) ?? 'e0',
      text: map['text'] as String?,
      contentDescription: map['contentDescription'] as String?,
      className: map['className'] as String?,
      viewId: map['viewId'] as String?,
      clickable: (map['clickable'] as bool?) ?? false,
      editable: (map['editable'] as bool?) ?? false,
      scrollable: (map['scrollable'] as bool?) ?? false,
      visible: (map['visible'] as bool?) ?? true,
      bounds: rawBounds.whereType<num>().map((n) => n.toInt()).toList(growable: false),
    );
  }

  static String _escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('"', r'\"')
      .replaceAll('\n', r'\n');
}
