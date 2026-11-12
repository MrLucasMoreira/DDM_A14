import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class Usuario {
  final int id;
  final String nome;
  final String email;

  Usuario({required this.id, required this.nome, required this.email});

  factory Usuario.fromJson(Map<String, dynamic> json) => Usuario(
        id: int.tryParse('${json['id']}') ?? 0,
        nome: '${json['nome'] ?? ''}',
        email: '${json['email'] ?? ''}',
      );

  String get arroba => '@${email.split('@').first}';
}

class AuthService {
  static const _chaveEmail = 'login_email';
  static const _chaveSenha = 'login_senha';

  static Future<Usuario> cadastrar(
    String nome,
    String email,
    String senha,
  ) {
    return _post('/cadastro', {
      'nome': nome,
      'email': email,
      'senha': senha,
    });
  }

  static Future<Usuario> login(String email, String senha) async {
    final usuario = await _post('/login', {
      'email': email,
      'senha': senha,
    });

    await salvarLogin(email, senha);
    return usuario;
  }

  static Future<Usuario> _post(
    String rota,
    Map<String, String> corpo,
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

    final dados = jsonDecode(resposta.body);

    if (resposta.statusCode >= 200 &&
        resposta.statusCode < 300 &&
        dados is Map &&
        dados['usuario'] is Map) {
      return Usuario.fromJson(
        Map<String, dynamic>.from(dados['usuario']),
      );
    }

    throw Exception(
      dados is Map ? '${dados['erro'] ?? 'Erro desconhecido'}' : 'Erro',
    );
  }

  static Future<void> salvarLogin(String email, String senha) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chaveEmail, email);
    await prefs.setString(_chaveSenha, senha);
  }

  static Future<(String, String)?> loginSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_chaveEmail);
    final senha = prefs.getString(_chaveSenha);

    if (email == null || senha == null) return null;
    return (email, senha);
  }

  static Future<void> sair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chaveSenha);
  }

  static Future<String?> ultimoEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chaveEmail);
  }
}
