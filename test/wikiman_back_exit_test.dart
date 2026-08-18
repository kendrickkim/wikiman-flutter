import 'package:flutter_test/flutter_test.dart';
import 'package:wikiman_app/wikiman_back_exit.dart';

void main() {
  test('첫 뒤로가기는 종료하지 않고 두 번째만 종료한다', () {
    var now = DateTime(2026, 8, 18, 10);
    final gate = WikimanBackExitGate(now: () => now);

    expect(gate.confirmExit(), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(gate.confirmExit(), isTrue);
  });

  test('2초가 지나면 다시 확인을 받는다', () {
    var now = DateTime(2026, 8, 18, 10);
    final gate = WikimanBackExitGate(now: () => now);

    expect(gate.confirmExit(), isFalse);
    now = now.add(const Duration(seconds: 2));
    expect(gate.confirmExit(), isFalse);
    now = now.add(const Duration(milliseconds: 100));
    expect(gate.confirmExit(), isTrue);
  });

  test('웹뷰가 뒤로 가면 종료 확인을 초기화한다', () {
    var now = DateTime(2026, 8, 18, 10);
    final gate = WikimanBackExitGate(now: () => now);
    expect(gate.confirmExit(), isFalse);
    gate.reset();
    now = now.add(const Duration(milliseconds: 200));
    expect(gate.confirmExit(), isFalse);
  });
}
