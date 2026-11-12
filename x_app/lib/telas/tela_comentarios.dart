import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../servicos/social_service.dart';

Future<void> abrirComentarios(
  BuildContext context,
  Usuario usuario,
  Map<String, dynamic> post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => TelaComentarios(usuario: usuario, post: post),
  );
}

class TelaComentarios extends StatefulWidget {
  const TelaComentarios({
    super.key,
    required this.usuario,
    required this.post,
  });

  final Usuario usuario;
  final Map<String, dynamic> post;

  @override
  State<TelaComentarios> createState() => _TelaComentariosState();
}

class _TelaComentariosState extends State<TelaComentarios> {
  final textoController = TextEditingController();

  late final List<Map<String, dynamic>> comentarios =
      (widget.post['comentarios'] as List? ?? [])
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();

  bool enviando = false;

  bool get podeComentar => widget.post['podeComentar'] == true;

  Future<void> enviar() async {
    final texto = textoController.text.trim();
    if (texto.isEmpty) return;

    setState(() => enviando = true);

    try {
      final comentario = await SocialService.comentar(
        widget.usuario.id,
        widget.post['id'],
        texto,
      );

      textoController.clear();

      setState(() {
        comentarios.add(comentario);
        widget.post['comentarios'] = List.of(comentarios);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final autor = '${widget.post['autorNome'] ?? 'Usuário'}';

    return Padding(

        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text(
                'Comentários',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),

              Expanded(
                child: comentarios.isEmpty
                    ? const Center(
                        child: Text('Nenhum comentário ainda.'),
                      )
                    : ListView.builder(
                        itemCount: comentarios.length,
                        itemBuilder: (_, i) {
                          final c = comentarios[i];
                          return ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text(
                              '${c['autorNome'] ?? 'Usuário'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${c['texto'] ?? ''}'),
                          );
                        },
                      ),
              ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(12),
                child: podeComentar
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textoController,
                              maxLength: 280,
                              enabled: !enviando,
                              onSubmitted: (_) => enviar(),
                              decoration: const InputDecoration(
                                hintText: 'Escreva um comentário...',
                                border: OutlineInputBorder(),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: enviando ? null : enviar,
                            style: IconButton.styleFrom(
                              backgroundColor: corPrincipal,
                            ),
                            icon: const Icon(Icons.send),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.lock_outline, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Só amigos podem comentar. '
                              'Adicione $autor como amigo.',
                              style: const TextStyle(color: Colors.grey),
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

  @override
  void dispose() {
    textoController.dispose();
    super.dispose();
  }
}
