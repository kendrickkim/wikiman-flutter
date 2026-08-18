import 'package:flutter_test/flutter_test.dart';
import 'package:wikiman_app/wikiman_native_command.dart';

void main() {
  test('웹 메시지를 네이티브 명령으로 구분한다', () {
    expect(parseWikimanNativeMessage('goHome'), WikimanNativeCommand.goHome);
    expect(parseWikimanNativeMessage('speech:start'), WikimanNativeCommand.speechStart);
    expect(parseWikimanNativeMessage('record:stop'), WikimanNativeCommand.recordStop);
    expect(
      parseWikimanNativeMessage('background:{"page":"#fff"}'),
      WikimanNativeCommand.background,
    );
    expect(parseWikimanNativeMessage('logout'), WikimanNativeCommand.changeConnection);
    expect(parseWikimanNativeMessage('keyboard:focus'), WikimanNativeCommand.keyboardFocus);
    expect(parseWikimanNativeMessage('update:check'), WikimanNativeCommand.updateCheck);
    expect(parseWikimanNativeMessage('update:start'), WikimanNativeCommand.updateStart);
    expect(parseWikimanNativeMessage('update:cancel'), WikimanNativeCommand.updateCancel);
  });
}
