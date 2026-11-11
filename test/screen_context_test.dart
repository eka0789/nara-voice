import 'package:flutter_test/flutter_test.dart';
import 'package:nara_voice/core/models/screen_context.dart';
import 'package:nara_voice/core/tools/tools/screen_tools.dart';

void main() {
  group('ScreenContext parsing', () {
    test('parses native map payload', () {
      final context = ScreenContext.fromMap(<Object?, Object?>{
        'status': 'ok',
        'packageName': 'com.example.app',
        'windowTitle': 'Inbox',
        'visibleText': 'Welcome\nInbox (3)',
        'truncated': false,
        'nodeCount': 42,
        'elements': [
          <Object?, Object?>{
            'id': 'e0',
            'text': 'Compose',
            'contentDescription': null,
            'className': 'android.widget.Button',
            'viewId': 'com.example.app:id/compose',
            'clickable': true,
            'editable': false,
            'scrollable': false,
            'visible': true,
            'bounds': [10, 20, 100, 60],
          },
          <Object?, Object?>{
            'id': 'e1',
            'text': null,
            'className': 'android.widget.EditText',
            'clickable': true,
            'editable': true,
            'scrollable': false,
            'visible': true,
            'bounds': [10, 70, 300, 110],
          },
        ],
      });

      expect(context.isOk, isTrue);
      expect(context.packageName, 'com.example.app');
      expect(context.interactiveElements, hasLength(2));
      expect(context.interactiveElements.first.label, 'Compose');
      expect(context.interactiveElements.last.isInputElement, isTrue);
    });

    test('password-adjacent empty payload is honest (status empty)', () {
      final context = ScreenContext.fromMap(<Object?, Object?>{'status': 'empty'});
      expect(context.isOk, isFalse);
    });
  });

  group('ScreenMemory', () {
    test('lookup by id returns remembered element', () {
      final memory = ScreenMemory();
      final context = ScreenContext.fromMap(<Object?, Object?>{
        'status': 'ok',
        'elements': [
          <Object?, Object?>{
            'id': 'e0',
            'className': 'android.widget.EditText',
            'editable': true,
            'clickable': true,
            'visible': true,
            'bounds': [0, 0, 10, 10],
          },
        ],
      });
      memory.remember(context);
      expect(memory.element('e0'), isNotNull);
      expect(memory.element('missing'), isNull);
    });
  });
}
