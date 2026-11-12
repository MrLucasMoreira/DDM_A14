import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../servicos/social_service.dart';
import '../widgets/card_publicacao.dart';
import 'tela_perfil.dart';

class TelaPesquisa extends StatefulWidget {
  const TelaPesquisa({
    super.key,
    required this.usuario,
    this.termoInicial = '',
  });

  final Usuario usuario;
  final String termoInicial;

  @override
  State<TelaPesquisa> createState() => _TelaPesquisaState();
}

class _TelaPesquisaState extends State<TelaPesquisa> {
  late final buscaController =
      TextEditingController(text: widget.termoInicial);

  Timer? espera;

  String termoAtual = '';
  List<Map<String, dynamic>> posts = [];
  List<Map<String, dynamic>> pessoas = [];
  List<Map<String, dynamic>> emAlta = [];

  bool carregando = false;
  String? erro;

  @override
  void initState() {
    super.initState();

    SocialService.emAlta().then((tags) {
      if (mounted) setState(() => emAlta = tags);
    }).catchError((_) {});

    if (widget.termoInicial.isNotEmpty) pesquisar(widget.termoInicial);
  }

  void aoDigitar(String texto) {
    espera?.cancel();
    espera = Timer(
      const Duration(milliseconds: 400),
      () => pesquisar(texto),
    );
  }

  Future<void> pesquisar(String texto) async {
    espera?.cancel();
    final termo = texto.trim();

    if (termo.isEmpty || termo == '#' || termo == '@') {
      setState(() {
        termoAtual = '';
        posts = [];
        pessoas = [];
        erro = null;
      });
      return;
    }

    setState(() {
      carregando = true;
      erro = null;
      termoAtual = termo;
    });

    try {
      final dados = await SocialService.pesquisar(widget.usuario.id, termo);

      if (!mounted || termo != termoAtual) return;

      List<Map<String, dynamic>> lista(String chave) =>
          (dados[chave] as List? ?? [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();

      setState(() {
        posts = lista('posts');
        pessoas = lista('pessoas');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted && termo == termoAtual) {
        setState(() => carregando = false);
      }
    }
  }

  void usarTermo(String termo) {
    buscaController.text = termo;
    pesquisar(termo);
  }

  Widget listaEmAlta() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Em alta',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pesquise por palavras, #hashtags ou @pessoas.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (emAlta.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Nenhuma hashtag ainda.\n'
              'Use #algumacoisa nas suas publicações!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ...emAlta.asMap().entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: corPrincipal.withOpacity(0.1),
                  child: Text(
                    '${e.key + 1}',
                    style: TextStyle(color: corPrincipal),
                  ),
                ),
                title: Text(
                  '${e.value['tag']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${e.value['total']} '
                  '${e.value['total'] == 1 ? 'publicação' : 'publicações'}',
                ),
                onTap: () => usarTermo('${e.value['tag']}'),
              ),
            ),
      ],
    );
  }

  Widget vazio(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );

  Widget abaPosts() {
    if (posts.isEmpty) {
      return vazio('Nenhuma publicação para "$termoAtual".');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: posts
          .map(
            (p) => CardPublicacao(
              key: ValueKey(p['id']),
              post: p,
              usuario: widget.usuario,
              aoMudarAmizade: () => pesquisar(termoAtual),
            ),
          )
          .toList(),
    );
  }

  Widget abaPessoas() {
    if (pessoas.isEmpty) {
      return vazio('Ninguém encontrado para "$termoAtual".');
    }

    const rotulos = {
      'eu': 'Você',
      'amigos': 'Amigos',
      'enviada': 'Pedido enviado',
      'recebida': 'Quer ser seu amigo',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: pessoas.map((p) {
        final email = '${p['email'] ?? ''}';

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            '${p['nome']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('@${email.split('@').first}'),
          trailing: rotulos[p['amizade']] == null
              ? null
              : Text(
                  rotulos[p['amizade']]!,
                  style: const TextStyle(color: Colors.grey),
                ),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TelaPerfil(
                  usuario: widget.usuario,
                  perfilId: p['id'],
                ),
              ),
            );

            pesquisar(termoAtual);
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          titleSpacing: 0,
          title: TextField(
            controller: buscaController,
            autofocus: widget.termoInicial.isEmpty,
            textInputAction: TextInputAction.search,
            onChanged: aoDigitar,
            onSubmitted: pesquisar,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Pesquisar no X Bolsonaro',
              hintStyle: const TextStyle(color: Colors.white70),
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              suffixIcon: buscaController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => usarTermo(''),
                    ),
            ),
          ),
          bottom: termoAtual.isEmpty
              ? null
              : TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(text: 'Posts (${posts.length})'),
                    Tab(text: 'Pessoas (${pessoas.length})'),
                  ],
                ),
        ),
        body: termoAtual.isEmpty
            ? listaEmAlta()
            : carregando && posts.isEmpty && pessoas.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : erro != null
                    ? vazio(erro!)
                    : TabBarView(
                        children: [abaPosts(), abaPessoas()],
                      ),
      ),
    );
  }

  @override
  void dispose() {
    espera?.cancel();
    buscaController.dispose();
    super.dispose();
  }
}
