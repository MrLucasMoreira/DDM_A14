import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';

class TelaCadastro extends StatefulWidget {
  const TelaCadastro({super.key});

  @override
  State<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends State<TelaCadastro> {
  final formKey = GlobalKey<FormState>();
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarController = TextEditingController();

  bool carregando = false;
  bool ocultarSenha = true;

  Future<void> cadastrar() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => carregando = true);

    try {
      final usuario = await AuthService.cadastrar(
        nomeController.text.trim(),
        emailController.text.trim(),
        senhaController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pop(usuario.email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Criar conta'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
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
                  const Text(
                    'Crie sua conta',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Informe seu nome.'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      final valido = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(email);
                      return valido ? null : 'Informe um e-mail válido.';
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: senhaController,
                    obscureText: ocultarSenha,
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
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Mínimo de 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: confirmarController,
                    obscureText: ocultarSenha,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar senha',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v != senhaController.text
                        ? 'As senhas não conferem.'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: carregando ? null : cadastrar,
                    style: FilledButton.styleFrom(
                      backgroundColor: corPrincipal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(carregando ? 'Cadastrando...' : 'Cadastrar'),
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
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    confirmarController.dispose();
    super.dispose();
  }
}
