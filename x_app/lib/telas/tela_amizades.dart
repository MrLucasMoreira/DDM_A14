import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../servicos/social_service.dart';

class TelaAmizades extends StatefulWidget {
  const TelaAmizades({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<TelaAmizades> createState() => _TelaAmizadesState();
}

class _TelaAmizadesState extends State<TelaAmizades> {
  Map<String, List<Usuario>> listas = {};
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      final dados = await SocialService.listarAmizades(widget.usuario.id);
      if (!mounted) return;
      setState(() => listas = dados);
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> responder(Usuario outro, bool aceitar) async {
    try {
      await SocialService.responderAmizade(
        widget.usuario.id,
        outro.id,
        aceitar,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aceitar
                ? 'Agora você e ${outro.nome} são amigos!'
                : 'Pedido recusado.',
          ),
        ),
      );

      await carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    }
  }

  Widget titulo(String texto, int quantidade) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        '$texto ($quantidade)',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget pessoa(Usuario u, {Widget? trailing}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(u.nome),
        subtitle: Text(u.arroba),
        trailing: trailing,
      ),
    );
  }

  Widget vazio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(texto, style: const TextStyle(color: Colors.grey)),
      );

  @override
  Widget build(BuildContext context) {
    final recebidas = listas['recebidas'] ?? [];
    final enviadas = listas['enviadas'] ?? [];
    final amigos = listas['amigos'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Amizades'),
        backgroundColor: corPrincipal,
        foregroundColor: Colors.white,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : erro != null
              ? Center(child: Text(erro!))
              : RefreshIndicator(
                  onRefresh: carregar,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      titulo('Pedidos recebidos', recebidas.length),
                      if (recebidas.isEmpty) vazio('Nenhum pedido.'),
                      ...recebidas.map(
                        (u) => pessoa(
                          u,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Recusar',
                                onPressed: () => responder(u, false),
                                icon: const Icon(Icons.close),
                              ),
                              IconButton.filled(
                                tooltip: 'Aceitar',
                                onPressed: () => responder(u, true),
                                style: IconButton.styleFrom(
                                  backgroundColor: corPrincipal,
                                ),
                                icon: const Icon(Icons.check),
                              ),
                            ],
                          ),
                        ),
                      ),

                      titulo('Amigos', amigos.length),
                      if (amigos.isEmpty)
                        vazio('Peça amizade pelos posts do feed.'),
                      ...amigos.map(
                        (u) => pessoa(
                          u,
                          trailing: const Icon(
                            Icons.people,
                            color: Colors.green,
                          ),
                        ),
                      ),

                      titulo('Pedidos enviados', enviadas.length),
                      if (enviadas.isEmpty) vazio('Nenhum pedido enviado.'),
                      ...enviadas.map(
                        (u) => pessoa(
                          u,
                          trailing: const Text(
                            'Aguardando',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
