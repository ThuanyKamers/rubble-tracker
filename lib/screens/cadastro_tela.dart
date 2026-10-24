import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/cpf.dart';
import '../widgets/layout_entrada.dart';
import 'login_tela.dart';
import 'mapa_tela.dart';

// Cadastro de cidadão. Contas de trabalhador são criadas pela prefeitura.
class CadastroTela extends StatefulWidget {
  const CadastroTela({super.key});

  @override
  State<CadastroTela> createState() => _CadastroTelaState();
}

class _CadastroTelaState extends State<CadastroTela> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _enviando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      final usuario = await ApiService.cadastrar(
        _nomeController.text.trim(),
        _cpfController.text,
        _senhaController.text,
      );
      if (!mounted) return;
      mostrarAviso(
        context,
        'Conta criada! Bem-vindo(a), ${usuario.nome.split(' ').first}.',
        tipo: TipoAviso.sucesso,
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MapaTela()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      mostrarAviso(context, e.mensagem, tipo: TipoAviso.erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconeSenha = IconButton(
      tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
      icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
      onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
    );

    return LayoutEntrada(
      mostrarVoltar: true,
      titulo: 'Criar conta',
      subtitulo: 'Leva menos de um minuto. Depois é só fotografar o entulho.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nomeController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Nome completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Informe seu nome completo.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _cpfController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [cpfFormatter],
              decoration: const InputDecoration(
                labelText: 'CPF',
                hintText: '000.000.000-00',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => cpfValido(v ?? '') ? null : 'CPF inválido. Confira os números.',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _senhaController,
              obscureText: !_mostrarSenha,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Senha',
                helperText: 'Pelo menos 6 caracteres',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: iconeSenha,
              ),
              validator: (v) =>
                  (v ?? '').length < 6 ? 'A senha precisa ter pelo menos 6 caracteres.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              obscureText: !_mostrarSenha,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _cadastrar(),
              decoration: const InputDecoration(
                labelText: 'Repita a senha',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: (v) => v != _senhaController.text ? 'As senhas não são iguais.' : null,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _enviando ? null : _cadastrar,
              child: _enviando ? const CarregandoBotao() : const Text('Criar minha conta'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _enviando
                  ? null
                  : () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginTela()),
                      ),
              child: const Text('Já tenho conta. Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
