import 'package:flutter/material.dart';

import 'config.dart';
import 'servicos/auth_service.dart';
import 'telas/tela_login.dart';
import 'telas/tela_publicacao.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'X Bolsonaro | Publicações',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: corPrincipal),
        useMaterial3: true,
      ),
      home: const TelaInicial(),
    );
  }
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  @override
  void initState() {
    super.initState();
    verificarLogin();
  }

  Future<void> verificarLogin() async {
    Widget destino = const TelaLogin();

    final salvo = await AuthService.loginSalvo();

    if (salvo != null) {
      try {
        final usuario = await AuthService.login(salvo.$1, salvo.$2);
        destino = TelaPublicacao(usuario: usuario);
      } catch (_) {}
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipal,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'XB',
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
