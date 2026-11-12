import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import 'tela_cadastro.dart';
import 'tela_publicacao.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;
  bool ocultarSenha = true;

  @override
  void initState() {
    super.initState();

    AuthService.ultimoEmail().then((email) {
      if (email != null && mounted) emailController.text = email;
    });
  }

  Future<void> entrar() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => carregando = true);

    try {
      final usuario = await AuthService.login(
        emailController.text.trim(),
        senhaController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TelaPublicacao(usuario: usuario),
        ),
      );
    } catch (e) {
      mostrarMensagem('$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> abrirCadastro() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TelaCadastro()),
    );

    if (email != null && mounted) {
      emailController.text = email;
      senhaController.clear();
      mostrarMensagem('Conta criada! Agora faça o login.');
    }
  }

  void mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: corPrincipal,
                    child: const Text(
                      'XB',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Entrar no X Bolsonaro',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Informe um e-mail válido.'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: senhaController,
                    obscureText: ocultarSenha,
                    onFieldSubmitted: (_) => carregando ? null : entrar(),
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => ocultarSenha = !ocultarSenha),
                        icon: Icon(
                          ocultarSenha
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: carregando ? null : entrar,
                    style: FilledButton.styleFrom(
                      backgroundColor: corPrincipal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(carregando ? 'Entrando...' : 'Entrar'),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton(
                    onPressed: carregando ? null : abrirCadastro,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Criar conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }
}
