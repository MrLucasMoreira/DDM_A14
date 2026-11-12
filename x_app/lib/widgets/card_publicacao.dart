import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../servicos/social_service.dart';
import '../telas/tela_amizades.dart';
import '../telas/tela_comentarios.dart';
import '../telas/tela_perfil.dart';
import '../telas/tela_pesquisa.dart';
import 'texto_post.dart';

class CardPublicacao extends StatefulWidget {
  const CardPublicacao({
    super.key,
    required this.post,
    required this.usuario,
    this.aoMudarAmizade,
  });

  final Map<String, dynamic> post;
  final Usuario usuario;

  final Future<void> Function()? aoMudarAmizade;

  @override
  State<CardPublicacao> createState() => _CardPublicacaoState();
}

class _CardPublicacaoState extends State<CardPublicacao> {
  Map<String, dynamic> get post => widget.post;

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  String erroTexto(Object e) => '$e'.replaceFirst('Exception: ', '');

  String formatarData(dynamic valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    if (data == null) return '';

    final local = data.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');

    return '${dois(local.day)}/${dois(local.month)}/${local.year}'
        ' às ${dois(local.hour)}:${dois(local.minute)}';
  }

  String resolverImagem(dynamic url) {
    if (url == null || '$url'.isEmpty) return '';
    return Uri.parse(apiUrl).resolve('$url').toString();
  }

  void abrirPesquisa(String termo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaPesquisa(
          usuario: widget.usuario,
          termoInicial: termo,
        ),
      ),
    );
  }

  void abrirPerfil() {
    if (post['autorId'] == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaPerfil(
          usuario: widget.usuario,
          perfilId: post['autorId'],
        ),
      ),
    );
  }

  Future<void> curtir() async {
    try {
      final (curtiu, total) =
          await SocialService.curtir(widget.usuario.id, post['id']);

      if (!mounted) return;

      setState(() {
        post['curtiu'] = curtiu;
        post['totalCurtidas'] = total;
      });
    } catch (e) {
      mostrarMensagem(erroTexto(e));
    }
  }

  Future<void> comentar() async {
    await abrirComentarios(context, widget.usuario, post);
    if (mounted) setState(() {});
  }

  Future<void> pedirAmizade() async {
    try {
      final status = await SocialService.solicitarAmizade(
        widget.usuario.id,
        post['autorId'],
      );

      mostrarMensagem(
        status == 'amigos'
            ? 'Agora vocês são amigos!'
            : 'Pedido de amizade enviado para ${post['autorNome']}.',
      );

      setState(() => post['amizade'] = status);
      await widget.aoMudarAmizade?.call();
    } catch (e) {
      mostrarMensagem(erroTexto(e));
    }
  }

  Future<void> abrirAmizades() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaAmizades(usuario: widget.usuario),
      ),
    );
    await widget.aoMudarAmizade?.call();
  }

  Widget botaoAmizade() {
    if (post['autorId'] == null) return const SizedBox.shrink();

    switch (post['amizade']) {
      case 'eu':
        return const SizedBox.shrink();

      case 'amigos':
        return const Chip(
          avatar: Icon(Icons.people, size: 16, color: Colors.green),
          label: Text('Amigos'),
          visualDensity: VisualDensity.compact,
        );

      case 'enviada':
        return const Chip(
          avatar: Icon(Icons.schedule, size: 16),
          label: Text('Pedido enviado'),
          visualDensity: VisualDensity.compact,
        );

      case 'recebida':
        return FilledButton.tonal(
          onPressed: abrirAmizades,
          child: const Text('Responder pedido'),
        );

      default:
        return OutlinedButton.icon(
          onPressed: pedirAmizade,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: const Text('Adicionar'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texto = '${post['texto'] ?? ''}';
    final imagemUrl = resolverImagem(post['imagemUrl']);
    final id = '${post['id'] ?? '-'}';
    final autorNome = '${post['autorNome'] ?? 'Usuário'}';
    final autorEmail = '${post['autorEmail'] ?? ''}';
    final arroba = autorEmail.isEmpty
        ? '@usuario'
        : '@${autorEmail.split('@').first}';
    final temAutor = post['autorId'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: temAutor ? abrirPerfil : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 21,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                autorNome,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '$arroba · Post #$id',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                botaoAmizade(),
              ],
            ),

            const SizedBox(height: 14),

            if (texto.isNotEmpty)
              TextoPost(
                texto: texto,
                aoTocar: abrirPesquisa,
                estilo: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.black87,
                ),
              ),

            if (imagemUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imagemUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Text('Não foi possível carregar a foto.'),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),

            Text(
              formatarData(post['criadoEm']),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const Divider(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: comentar,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                  ),
                  icon: Icon(
                    post['podeComentar'] == true
                        ? Icons.chat_bubble_outline
                        : Icons.lock_outline,
                    size: 20,
                  ),
                  label: Text(
                    '${(post['comentarios'] as List?)?.length ?? 0}',
                  ),
                ),
                TextButton.icon(
                  onPressed: curtir,
                  style: TextButton.styleFrom(
                    foregroundColor: post['curtiu'] == true
                        ? Colors.red
                        : Colors.grey.shade700,
                  ),
                  icon: Icon(
                    post['curtiu'] == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 20,
                  ),
                  label: Text('${post['totalCurtidas'] ?? 0}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
