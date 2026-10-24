import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/cpf.dart';
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

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await ApiService.cadastrar(
        _nomeController.text.trim(),
        _cpfController.text,
        _senhaController.text,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MapaTela()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red),
      );
    }
  }

  InputDecoration _campo(String rotulo, IconData icone) => InputDecoration(
        labelText: rotulo,
        prefixIcon: Icon(icone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _campo('Nome completo', Icons.badge),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Informe seu nome completo.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [cpfFormatter],
                  decoration: _campo('CPF', Icons.person),
                  validator: (v) => cpfValido(v ?? '') ? null : 'CPF inválido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: _campo('Senha', Icons.lock),
                  validator: (v) =>
                      (v ?? '').length < 6 ? 'A senha precisa ter pelo menos 6 caracteres.' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  obscureText: true,
                  decoration: _campo('Repita a senha', Icons.lock_outline),
                  validator: (v) => v != _senhaController.text ? 'As senhas não são iguais.' : null,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _enviando ? null : _cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Cadastrar', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginTela()),
                  ),
                  child: const Text('Já tenho conta', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
