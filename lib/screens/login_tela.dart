import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../services/api_service.dart';
import '../utils/cpf.dart';
import 'cadastro_tela.dart';
import 'mapa_tela.dart';

final cpfFormatter = MaskTextInputFormatter(
  mask: '###.###.###-##',
  filter: {'#': RegExp(r'[0-9]')},
  type: MaskAutoCompletionType.lazy,
);

class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _entrando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _erro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
  }

  Future<void> _entrar() async {
    final cpf = _cpfController.text;
    final senha = _senhaController.text;
    if (cpf.isEmpty || senha.isEmpty) return _erro('Por favor, preencha o CPF e a senha.');
    if (!cpfValido(cpf)) return _erro('CPF inválido.');

    setState(() => _entrando = true);
    try {
      await ApiService.login(cpf, senha);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapaTela()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _entrando = false);
      _erro(e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.location_on, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Cidade Limpa',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Faça login com o CPF',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _cpfController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [cpfFormatter],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'CPF',
                      hintText: '000.000.000-00',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _senhaController,
                    obscureText: !_mostrarSenha,
                    onSubmitted: (_) => _entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Esqueci minha senha'),
                          content: const Text(
                            'Procure o atendimento da Prefeitura de Palhoça para redefinir sua senha.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ok')),
                          ],
                        ),
                      ),
                      child: const Text('Esqueci minha senha', style: TextStyle(color: Colors.green)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _entrando ? null : _entrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _entrando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Não tem uma conta? '),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CadastroTela()),
                        ),
                        child: const Text(
                          'Cadastrar-se',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
