import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class SocialService {
  static Future<(bool, int)> curtir(int usuarioId, dynamic postId) async {
    final dados = await _post('/curtir', {
      'usuarioId': usuarioId,
      'postId': postId,
    });

    return (
      dados['curtiu'] == true,
      int.tryParse('${dados['totalCurtidas']}') ?? 0,
    );
  }

  static Future<Map<String, dynamic>> comentar(
    int usuarioId,
    dynamic postId,
    String texto,
  ) {
    return _post('/comentar', {
      'usuarioId': usuarioId,
      'postId': postId,
      'texto': texto,
    });
  }

  static Future<String> solicitarAmizade(int usuarioId, dynamic amigoId) async {
    final dados = await _post('/amizade/solicitar', {
      'usuarioId': usuarioId,
      'amigoId': amigoId,
    });

    return '${dados['amizade']}';
  }

  static Future<void> responderAmizade(
    int usuarioId,
    int amigoId,
    bool aceitar,
  ) {
    return _post('/amizade/responder', {
      'usuarioId': usuarioId,
      'amigoId': amigoId,
      'aceitar': aceitar,
    });
  }

  static Future<Map<String, List<Usuario>>> listarAmizades(
    int usuarioId,
  ) async {
    final resposta = await http
        .get(Uri.parse('$apiUrl/amizades?usuarioId=$usuarioId'))
        .timeout(const Duration(seconds: 15));

    final dados = _ler(resposta);

    List<Usuario> lista(String chave) => (dados[chave] as List? ?? [])
        .whereType<Map>()
        .map((u) => Usuario.fromJson(Map<String, dynamic>.from(u)))
        .toList();

    return {
      'recebidas': lista('recebidas'),
      'enviadas': lista('enviadas'),
      'amigos': lista('amigos'),
    };
  }

  static Future<Map<String, dynamic>> pesquisar(
    int usuarioId,
    String termo,
  ) {
    return _get('/pesquisar', {
      'q': termo,
      'usuarioId': '$usuarioId',
    });
  }

  static Future<List<Map<String, dynamic>>> emAlta() async {
    final resposta = await http
        .get(Uri.parse('$apiUrl/hashtags'))
        .timeout(const Duration(seconds: 15));

    final dados = jsonDecode(resposta.body);

    return dados is List
        ? dados
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : [];
  }

  static Future<Map<String, dynamic>> perfil(int usuarioId, dynamic id) {
    return _get('/perfil', {
      'id': '$id',
      'usuarioId': '$usuarioId',
    });
  }

  static Future<Map<String, dynamic>> _get(
    String rota,
    Map<String, String> parametros,
  ) async {
    final http.Response resposta;

    try {
      resposta = await http
          .get(
            Uri.parse('$apiUrl$rota')
                .replace(queryParameters: parametros),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('Não foi possível conectar ao servidor.');
    }

    return _ler(resposta);
  }

  static Future<Map<String, dynamic>> _post(
    String rota,
    Map<String, dynamic> corpo,
  ) async {
    final http.Response resposta;

    try {
      resposta = await http
          .post(
            Uri.parse('$apiUrl$rota'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(corpo),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw Exception('Não foi possível conectar ao servidor.');
    }

    return _ler(resposta);
  }

  static Map<String, dynamic> _ler(http.Response resposta) {
    final dados = jsonDecode(resposta.body);

    if (resposta.statusCode >= 200 &&
        resposta.statusCode < 300 &&
        dados is Map) {
      return Map<String, dynamic>.from(dados);
    }

    throw Exception(
      dados is Map ? '${dados['erro'] ?? 'Erro desconhecido'}' : 'Erro',
    );
  }
}
