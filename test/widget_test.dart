import 'package:flutter_test/flutter_test.dart';

import 'package:projeto_lara/main.dart';
import 'package:projeto_lara/utils/cpf.dart';

void main() {
  testWidgets('Sem login, o app abre na tela de login', (WidgetTester tester) async {
    await tester.pumpWidget(const CidadeLimpaApp());

    expect(find.text('Cidade Limpa'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Cadastrar-se'), findsOneWidget);
  });

  test('Validação de CPF', () {
    expect(cpfValido('529.982.247-25'), isTrue);
    expect(cpfValido('111.444.777-35'), isTrue);
    expect(cpfValido('123.456.789-00'), isFalse);
    expect(cpfValido('111.111.111-11'), isFalse);
    expect(cpfValido('123'), isFalse);
  });
}
