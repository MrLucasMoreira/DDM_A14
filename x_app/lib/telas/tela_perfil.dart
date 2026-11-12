import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../servicos/social_service.dart';
import '../widgets/card_publicacao.dart';
import 'tela_amizades.dart';

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({
    super.key,
    required this.usuario,
    required this.perfilId,
  });

  final Usuario usuario;

  final dynamic perfilId;

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  Map<String, dynamic>? dados;
  bool carregando = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    try {
      final resposta =
          await SocialService.perfil(widget.usuario.id, widget.perfilId);
      if (!mounted) return;
      setState(() {
        dados = resposta;
        erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> pedirAmizade() async {
    try {
      final status = await SocialService.solicitarAmizade(
        widget.usuario.id,
        widget.perfilId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'amigos'
                ? 'Agora vocês são amigos!'
                : 'Pedido de amizade enviado.',
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

  Future<void> abrirAmizades() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaAmizades(usuario: widget.usuario),
      ),
    );
    await carregar();
  }

  Widget botaoAmizade(String status) {
    switch (status) {
      case 'eu':
        return const Chip(label: Text('Este é você'));
      case 'amigos':
        return const Chip(
          avatar: Icon(Icons.people, size: 16, color: Colors.green),
          label: Text('Amigos'),
        );
      case 'enviada':
        return const Chip(
          avatar: Icon(Icons.schedule, size: 16),
          label: Text('Pedido enviado'),
        );
      case 'recebida':
        return FilledButton(
          onPressed: abrirAmizades,
          child: const Text('Responder pedido'),
        );
      default:
        return FilledButton.icon(
          onPressed: pedirAmizade,
          style: FilledButton.styleFrom(backgroundColor: corPrincipal),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Adicionar amigo'),
        );
    }
  }

  String mesAno(dynamic valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    if (data == null) return '';
    const meses = [
      'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
      'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
    ];
    return '${meses[data.month - 1]} de ${data.year}';
  }

  Widget numero(int valor, String rotulo) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$valor',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(rotulo, style: const TextStyle(color: Colors.grey)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final perfil = dados?['usuario'] as Map?;
    final posts = (dados?['posts'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final email = '${perfil?['email'] ?? ''}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Text('${perfil?['nome'] ?? 'Perfil'}'),
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
                    children: [

                      Container(height: 90, color: corPrincipal.withOpacity(0.15)),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Transform.translate(
                                  offset: const Offset(0, -30),
                                  child: const CircleAvatar(
                                    radius: 40,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 36,
                                      backgroundColor: Colors.blue,
                                      child: Icon(
                                        Icons.person,
                                        size: 40,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: botaoAmizade(
                                    '${dados?['amizade'] ?? 'nenhuma'}',
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${perfil?['nome'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '@${email.split('@').first}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            if (mesAno(dados?['criadoEm']).isNotEmpty)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Entrou em ${mesAno(dados?['criadoEm'])}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 16,
                              children: [
                                numero(posts.length, 'Publicações'),
                                numero(
                                  int.tryParse('${dados?['totalAmigos']}') ?? 0,
                                  'Amigos',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (posts.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(30),
                                child: Text(
                                  'Nenhuma publicação ainda.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ...posts.map(
                              (p) => CardPublicacao(
                                key: ValueKey(p['id']),
                                post: p,
                                usuario: widget.usuario,
                                aoMudarAmizade: carregar,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
