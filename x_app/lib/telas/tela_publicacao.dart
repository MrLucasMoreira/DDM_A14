import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../servicos/auth_service.dart';
import '../widgets/card_publicacao.dart';
import 'tela_amizades.dart';
import 'tela_login.dart';
import 'tela_perfil.dart';
import 'tela_pesquisa.dart';

class TelaPublicacao extends StatefulWidget {
  const TelaPublicacao({super.key, required this.usuario});

  final Usuario usuario;

  @override
  State<TelaPublicacao> createState() => _TelaPublicacaoState();
}

class _TelaPublicacaoState extends State<TelaPublicacao> {
  final textoController = TextEditingController();
  final idController = TextEditingController();
  final ImagePicker picker = ImagePicker();

  XFile? imagemSelecionada;
  Uint8List? imagemBytes;
  MediaType? imagemTipo;

  List<Map<String, dynamic>> publicacoes = [];
  Map<String, dynamic>? publicacaoBuscada;

  bool carregando = false;
  bool carregandoFeed = false;
  String? erroFeed;

  @override
  void initState() {
    super.initState();
    carregarFeed();
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  MediaType? identificarMime(String nome) {
    final extensao = nome.split('.').last.toLowerCase();

    switch (extensao) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');

      case 'png':
        return MediaType('image', 'png');

      case 'webp':
        return MediaType('image', 'webp');

      default:
        return null;
    }
  }

  Future<void> selecionarImagem(ImageSource origem) async {
    try {
      final imagem = await picker.pickImage(
        source: origem,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (imagem == null) return;

      final tipo = identificarMime(imagem.name);

      if (tipo == null) {
        mostrarMensagem('Use imagens JPG, PNG ou WebP.');
        return;
      }

      final bytes = await imagem.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        mostrarMensagem('Imagem maior que 5 MB.');
        return;
      }

      if (!mounted) return;

      setState(() {
        imagemSelecionada = imagem;
        imagemBytes = bytes;
        imagemTipo = tipo;
      });
    } catch (e) {
      mostrarMensagem('Erro ao selecionar imagem: $e');
    }
  }

  void removerImagem() {
    setState(() {
      imagemSelecionada = null;
      imagemBytes = null;
      imagemTipo = null;
    });
  }

  Future<void> publicar() async {
    final texto = textoController.text.trim();

    if (texto.isEmpty && imagemBytes == null) {
      mostrarMensagem('Digite um texto ou escolha uma foto.');
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final requisicao = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/salvar'),
      );

      requisicao.fields['texto'] = texto;

      requisicao.fields['usuarioId'] = '${widget.usuario.id}';

      if (imagemSelecionada != null &&
          imagemBytes != null &&
          imagemTipo != null) {
        requisicao.files.add(
          http.MultipartFile.fromBytes(
            'imagem',
            imagemBytes!,
            filename: imagemSelecionada!.name,
            contentType: imagemTipo,
          ),
        );
      }

      final stream =
          await requisicao.send().timeout(const Duration(seconds: 30));

      final resposta = await http.Response.fromStream(stream);
      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        textoController.clear();
        removerImagem();

        FocusScope.of(context).unfocus();

        mostrarMensagem('Publicado com sucesso!');

        await carregarFeed();
      } else {
        mostrarMensagem(
          'Erro: ${dados['erro'] ?? 'Falha na publicação'}',
        );
      }
    } catch (e) {
      mostrarMensagem('Erro ao publicar: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> carregarFeed() async {
    if (!mounted) return;

    setState(() {
      carregandoFeed = true;
      erroFeed = null;
    });

    try {
      final resposta = await http
          .get(Uri.parse('$apiUrl/feed?usuarioId=${widget.usuario.id}'))
          .timeout(const Duration(seconds: 15));

      if (resposta.statusCode != 200) {
        throw Exception('Servidor retornou ${resposta.statusCode}');
      }

      final dados = jsonDecode(resposta.body);

      if (dados is! List) {
        throw Exception('Formato de feed inválido.');
      }

      final lista = dados.whereType<Map<String, dynamic>>().toList();

      lista.sort((a, b) {
        final idA = int.tryParse('${a['id']}') ?? 0;
        final idB = int.tryParse('${b['id']}') ?? 0;
        return idB.compareTo(idA);
      });

      if (!mounted) return;

      setState(() {
        publicacoes = lista;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erroFeed = 'Não foi possível carregar o feed.';
      });

      debugPrint('Erro no feed: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregandoFeed = false;
        });
      }
    }
  }

  Future<void> buscar() async {
    final id = int.tryParse(idController.text.trim());

    if (id == null || id < 0) {
      mostrarMensagem('Informe um ID válido.');
      return;
    }

    setState(() {
      carregando = true;
      publicacaoBuscada = null;
    });

    try {
      final resposta = await http
          .get(Uri.parse(
            '$apiUrl/buscar?id=$id&usuarioId=${widget.usuario.id}',
          ))
          .timeout(const Duration(seconds: 15));

      final dados = jsonDecode(resposta.body);

      if (!mounted) return;

      if (resposta.statusCode == 200 && dados is Map) {
        setState(() {
          publicacaoBuscada = Map<String, dynamic>.from(dados);
        });

        mostrarMensagem('Publicação encontrada!');
      } else {
        mostrarMensagem(
          dados is Map
              ? '${dados['mensagem'] ?? dados['erro'] ?? 'Não encontrada'}'
              : 'Publicação não encontrada.',
        );
      }
    } catch (e) {
      mostrarMensagem('Erro ao buscar: $e');
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> sair() async {
    await AuthService.sair();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
    );
  }

  Future<void> abrirAmizades() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaAmizades(usuario: widget.usuario),
      ),
    );

    await carregarFeed();
  }

  Future<void> abrirPesquisa() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaPesquisa(usuario: widget.usuario),
      ),
    );

    await carregarFeed();
  }

  Future<void> abrirMeuPerfil() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaPerfil(
          usuario: widget.usuario,
          perfilId: widget.usuario.id,
        ),
      ),
    );
    await carregarFeed();
  }

  Widget card(Map<String, dynamic> post) => CardPublicacao(
        key: ValueKey(post['id']),
        post: post,
        usuario: widget.usuario,
        aoMudarAmizade: carregarFeed,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('X Bolsonaro | Publicações'),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Pesquisar',
            onPressed: abrirPesquisa,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Meu perfil',
            onPressed: abrirMeuPerfil,
            icon: const Icon(Icons.account_circle),
          ),
          IconButton(
            tooltip: 'Amizades',
            onPressed: abrirAmizades,
            icon: const Icon(Icons.people),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: carregarFeed,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Olá, ${widget.usuario.nome}!',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.usuario.arroba,
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
                  const SizedBox(height: 18),
                  TextField(
                    controller: textoController,
                    maxLines: 3,
                    maxLength: 280,
                    decoration: const InputDecoration(
                      hintText: 'O que está acontecendo?',
                      border: InputBorder.none,
                    ),
                  ),
                  if (imagemBytes != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            imagemBytes!,
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton.filled(
                            onPressed: carregando ? null : removerImagem,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Galeria',
                        onPressed: carregando
                            ? null
                            : () => selecionarImagem(
                                  ImageSource.gallery,
                                ),
                        icon: const Icon(Icons.image),
                        color: Colors.blue.shade900,
                      ),
                      IconButton(
                        tooltip: 'Câmera',
                        onPressed: carregando
                            ? null
                            : () => selecionarImagem(
                                  ImageSource.camera,
                                ),
                        icon: const Icon(Icons.camera_alt),
                        color: Colors.blue.shade900,
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: carregando ? null : publicar,
                        icon: const Icon(Icons.send, size: 18),
                        label: Text(
                          carregando ? 'Enviando...' : 'Publicar',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const SizedBox(height: 12),

            if (publicacaoBuscada != null) ...[
              const SizedBox(height: 15),
              card(publicacaoBuscada!),
            ],

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Feed de Publicações',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: carregandoFeed ? null : carregarFeed,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (carregandoFeed && publicacoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            if (erroFeed != null) ...[
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      erroFeed!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: carregarFeed,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ],

            if (!carregandoFeed && erroFeed == null && publicacoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text(
                    'Nenhuma publicação ainda.\n'
                    'Seja o primeiro a publicar!',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            ...publicacoes.map(card),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    textoController.dispose();
    idController.dispose();
    super.dispose();
  }
}
