import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../config.dart';

class TextoPost extends StatefulWidget {
  const TextoPost({
    super.key,
    required this.texto,
    required this.aoTocar,
    this.estilo,
  });

  final String texto;

  final void Function(String termo) aoTocar;

  final TextStyle? estilo;

  @override
  State<TextoPost> createState() => _TextoPostState();
}

class _TextoPostState extends State<TextoPost> {
  static final _regex = RegExp(r'[#@][\p{L}\p{N}_]+', unicode: true);

  final List<TapGestureRecognizer> _toques = [];

  void _limparToques() {
    for (final t in _toques) {
      t.dispose();
    }
    _toques.clear();
  }

  @override
  Widget build(BuildContext context) {
    _limparToques();

    final partes = <InlineSpan>[];
    var inicio = 0;

    for (final achado in _regex.allMatches(widget.texto)) {
      if (achado.start > inicio) {
        partes.add(TextSpan(text: widget.texto.substring(inicio, achado.start)));
      }

      final termo = achado.group(0)!;
      final toque = TapGestureRecognizer()..onTap = () => widget.aoTocar(termo);
      _toques.add(toque);

      partes.add(
        TextSpan(
          text: termo,
          recognizer: toque,
          style: TextStyle(
            color: corPrincipal,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      inicio = achado.end;
    }

    if (inicio < widget.texto.length) {
      partes.add(TextSpan(text: widget.texto.substring(inicio)));
    }

    return Text.rich(
      TextSpan(
        style: widget.estilo ?? DefaultTextStyle.of(context).style,
        children: partes,
      ),
    );
  }

  @override
  void dispose() {
    _limparToques();
    super.dispose();
  }
}
