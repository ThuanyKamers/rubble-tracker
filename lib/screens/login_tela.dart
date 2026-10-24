import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../services/api_service.dart';
import '../theme.dart';
import '../utils/cpf.dart';
import '../widgets/layout_entrada.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _senhaFoco = FocusNode();
  bool _entrando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    _senhaFoco.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _entrando = true);
    try {
      await ApiService.login(_cpfController.text, _senhaController.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MapaTela()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _entrando = false);
      mostrarAviso(context, e.mensagem, tipo: TipoAviso.erro);
    }
  }

  void _esqueciSenha() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.support_agent_rounded, color: Cores.verde, size: 36),
        title: const Text('Esqueceu a senha?'),
        content: const Text(
          'Procure o atendimento da Prefeitura de Palhoça para redefinir sua senha.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutEntrada(
      titulo: 'Bem-vindo(a)!',
      subtitulo: 'Entre com seu CPF para registrar ou recolher entulhos.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [cpfFormatter],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                onFieldSubmitted: (_) => _senhaFoco.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'CPF',
                  hintText: '000.000.000-00',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Informe seu CPF.';
                  return cpfValido(v!) ? null : 'CPF inválido. Confira os números.';
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _senhaController,
                focusNode: _senhaFoco,
                obscureText: !_mostrarSenha,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _entrar(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                    icon: Icon(_mostrarSenha ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                  ),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Informe sua senha.' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _esqueciSenha,
                  child: const Text('Esqueci minha senha'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _entrando ? null : _entrar,
                child: _entrando ? const CarregandoBotao() : const Text('Entrar'),
              ),
              const SizedBox(height: 28),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Primeira vez aqui?', style: TextStyle(color: Cores.textoSuave)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _entrando
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CadastroTela()),
                        ),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Criar conta de cidadão'),
              ),
              const SizedBox(height: 20),
              const _AvisoTrabalhador(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoTrabalhador extends StatelessWidget {
  const _AvisoTrabalhador();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cores.verdeClaro,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.engineering_rounded, color: Cores.verde),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'É da equipe de coleta? Use o CPF e a senha que a prefeitura cadastrou para você.',
              style: TextStyle(color: Cores.verdeEscuro, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
