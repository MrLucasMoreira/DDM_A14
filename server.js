import dotenv from 'dotenv';

dotenv.config();
dotenv.config({ path: '.env.example' });

import express from 'express';
import cors from 'cors';
import multer from 'multer';

import { randomUUID } from 'node:crypto';
import { fileTypeFromBuffer } from 'file-type';

import { createClient } from '@supabase/supabase-js';

import bcrypt from 'bcryptjs';

import { initializeApp } from 'firebase/app';
import {
  getDatabase,
  ref,
  get,
  set,
  update,
  runTransaction
} from 'firebase/database';

const app = express();
const port = 3000;

const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY,
  authDomain: 'ddmapi.firebaseapp.com',
  databaseURL: 'https://ddmapi-default-rtdb.firebaseio.com',
  projectId: 'ddmapi',
  storageBucket: 'ddmapi.firebasestorage.app',
  messagingSenderId: '724860875864',
  appId: '1:724860875864:web:9dae57c24ef0b3606f462d'
};

const firebaseApp = initializeApp(firebaseConfig);
const db = getDatabase(firebaseApp);

if (
  !process.env.SUPABASE_URL ||
  !process.env.SUPABASE_PUBLISHABLE_KEY
) {
  throw new Error('Configure SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY no .env.');
}

const supabase = createClient(
  process.env.SUPABASE_URL.trim(),
  process.env.SUPABASE_PUBLISHABLE_KEY.trim(),
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false
    }
  }
);

const bucket = 'publicacoes';

const emailValido = email =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

const chaveEmail = email =>
  email.replace(/\./g, ',');

async function proximoId(caminhoContador) {
  const resultado = await runTransaction(
    ref(db, caminhoContador),
    atual => (atual || 0) + 1
  );

  if (!resultado.committed) {
    throw new Error('Falha ao gerar ID.');
  }

  return resultado.snapshot.val();
}

async function buscarUsuario(id) {
  const numero = Number(id);

  if (!Number.isSafeInteger(numero) || numero <= 0) {
    return null;
  }

  const snapshot = await get(ref(db, `usuarios/${numero}`));
  return snapshot.exists() ? snapshot.val() : null;
}

const usuarioPublico = usuario => ({
  id: usuario.id,
  nome: usuario.nome,
  email: usuario.email
});

async function amizadesDe(usuarioId) {
  if (!usuarioId) return {};

  const snapshot = await get(ref(db, `amizades/${usuarioId}`));
  return snapshot.exists() ? snapshot.val() : {};
}

async function statusAmizade(usuarioId, outroId) {
  if (!usuarioId || !outroId) return 'nenhuma';
  if (Number(usuarioId) === Number(outroId)) return 'eu';

  const snapshot = await get(
    ref(db, `amizades/${usuarioId}/${outroId}`)
  );

  return snapshot.exists() ? snapshot.val() : 'nenhuma';
}

function montarPost(post, usuarioId, amizades) {
  const curtidas = post.curtidas || {};

  const comentarios = Object.values(post.comentarios || {})
    .filter(c => c && typeof c === 'object')
    .sort((a, b) => a.id - b.id);

  let amizade = 'nenhuma';

  if (post.autorId && usuarioId) {
    amizade = Number(post.autorId) === Number(usuarioId)
      ? 'eu'
      : (amizades[post.autorId] || 'nenhuma');
  }

  const {
    curtidas: _curtidas,
    comentarios: _comentarios,
    contadorComentarios: _contador,
    ...resto
  } = post;

  return {
    ...resto,
    totalCurtidas: Object.keys(curtidas).length,
    curtiu: Boolean(usuarioId && curtidas[usuarioId]),
    comentarios,
    amizade,
    podeComentar: amizade === 'eu' || amizade === 'amigos'
  };
}

app.use(cors());
app.use(express.json());

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024
  }
});

const extensoes = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp'
};

async function verificarBucket() {
  try {
    console.log(
      `Supabase: usando chave publicável no bucket "${bucket}".`
    );
  } catch (erro) {
    console.error(
      'Erro na verificação:',
      erro.message
    );
  }
}

verificarBucket();

app.use(express.static('public'));

app.get('/', (req, res) => {
  res.json({
    mensagem: 'API Mini X funcionando!'
  });
});

app.post('/cadastro', async (req, res) => {
  try {
    const nome = String(req.body.nome || '').trim();
    const email = String(req.body.email || '')
      .trim()
      .toLowerCase();
    const senha = String(req.body.senha || '');

    if (!nome || !email || !senha) {
      return res.status(400).json({
        erro: 'Preencha nome, e-mail e senha.'
      });
    }

    if (!emailValido(email)) {
      return res.status(400).json({
        erro: 'E-mail inválido.'
      });
    }

    if (senha.length < 6) {
      return res.status(400).json({
        erro: 'A senha deve ter pelo menos 6 caracteres.'
      });
    }

    const emailRef = ref(db, `emails/${chaveEmail(email)}`);

    if ((await get(emailRef)).exists()) {
      return res.status(409).json({
        erro: 'Este e-mail já está cadastrado.'
      });
    }

    const id = await proximoId('contadorUsuarios');

    const reserva = await runTransaction(
      emailRef,
      atual => (atual ? undefined : id)
    );

    if (!reserva.committed) {
      return res.status(409).json({
        erro: 'Este e-mail já está cadastrado.'
      });
    }

    const usuario = {
      id,
      nome,
      email,
      senhaHash: await bcrypt.hash(senha, 10),
      criadoEm: new Date().toISOString()
    };

    await set(ref(db, `usuarios/${id}`), usuario);

    return res.status(201).json({
      mensagem: 'Cadastro realizado com sucesso!',
      usuario: usuarioPublico(usuario)
    });
  } catch (erro) {
    console.error('Erro no cadastro:', erro);

    return res.status(500).json({
      erro: 'Erro ao cadastrar usuário.'
    });
  }
});

app.post('/login', async (req, res) => {
  try {
    const email = String(req.body.email || '')
      .trim()
      .toLowerCase();
    const senha = String(req.body.senha || '');

    if (!email || !senha) {
      return res.status(400).json({
        erro: 'Informe e-mail e senha.'
      });
    }

    const idSnap = await get(
      ref(db, `emails/${chaveEmail(email)}`)
    );

    const usuario = idSnap.exists()
      ? await buscarUsuario(idSnap.val())
      : null;

    if (
      !usuario ||
      !(await bcrypt.compare(senha, usuario.senhaHash))
    ) {
      return res.status(401).json({
        erro: 'E-mail ou senha incorretos.'
      });
    }

    return res.status(200).json({
      mensagem: 'Login realizado com sucesso!',
      usuario: usuarioPublico(usuario)
    });
  } catch (erro) {
    console.error('Erro no login:', erro);

    return res.status(500).json({
      erro: 'Erro ao fazer login.'
    });
  }
});

app.post(
  '/salvar',
  upload.single('imagem'),
  async (req, res) => {
    let caminhoImagem = null;
    let uploadConcluido = false;

    try {
      const autor = await buscarUsuario(req.body.usuarioId);

      if (!autor) {
        return res.status(401).json({
          erro: 'Faça login para publicar.'
        });
      }

      const texto = String(
        req.body.texto || ''
      ).trim();

      if (!texto && !req.file) {
        return res.status(400).json({
          erro: 'Informe texto ou imagem.'
        });
      }

      if (texto.length > 280) {
        return res.status(400).json({
          erro: 'Máximo de 280 caracteres.'
        });
      }

      let imagemUrl = null;

      if (req.file) {
        console.log(
          'Imagem recebida:',
          req.file.originalname
        );

        console.log(
          'Tamanho:',
          req.file.size
        );

        const tipo = await fileTypeFromBuffer(
          req.file.buffer
        );

        console.log(
          'Tipo identificado:',
          tipo?.mime
        );

        if (!tipo || !extensoes[tipo.mime]) {
          return res.status(400).json({
            erro: 'Formato inválido. Use JPG, PNG ou WebP.'
          });
        }

        const nomeArquivo =
          `${randomUUID()}${extensoes[tipo.mime]}`;

        caminhoImagem = `posts/${nomeArquivo}`;

        console.log(
          'Enviando para Supabase:',
          caminhoImagem
        );

        const { data, error } =
          await supabase.storage
            .from(bucket)
            .upload(
              caminhoImagem,
              req.file.buffer,
              {
                contentType: tipo.mime,
                upsert: false
              }
            );

        if (error) {
          console.error(
            'ERRO SUPABASE:',
            JSON.stringify({
              message: error.message,
              statusCode: error.statusCode,
              error: error.error
            }, null, 2)
          );

          return res.status(
            Number(error.statusCode) || 500
          ).json({
            erro: `Erro no Supabase: ${error.message}`,
            codigo: error.statusCode
          });
        }

        uploadConcluido = true;

        console.log(
          'Upload realizado:',
          data
        );

        const { data: urlData } =
          supabase.storage
            .from(bucket)
            .getPublicUrl(caminhoImagem);

        imagemUrl = urlData.publicUrl;
      }

      const contadorRef = ref(db, 'contador');

      const resultado = await runTransaction(
        contadorRef,
        atual => (atual || 0) + 1
      );

      if (!resultado.committed) {
        throw new Error('Falha ao gerar ID.');
      }

      const id = resultado.snapshot.val();

      const publicacao = {
        id,
        texto,
        imagemUrl,
        autorId: autor.id,
        autorNome: autor.nome,
        autorEmail: autor.email,
        criadoEm: new Date().toISOString()
      };

      await set(
        ref(db, `dados/${id}`),
        publicacao
      );

      console.log(
        'Publicação salva:',
        id
      );

      return res.status(201).json({
        mensagem: 'Publicado com sucesso!',
        ...publicacao
      });
    } catch (erro) {
      console.error(
        'ERRO AO PUBLICAR:',
        erro
      );

      if (uploadConcluido && caminhoImagem) {
        try {
          const { error } =
            await supabase.storage
              .from(bucket)
              .remove([caminhoImagem]);

          if (error) {
            console.error(
              'Erro ao remover imagem:',
              error.message
            );
          }
        } catch (erroLimpeza) {
          console.error(
            'Erro na limpeza:',
            erroLimpeza.message
          );
        }
      }

      return res.status(500).json({
        erro: erro.message
      });
    }
  }
);

app.get('/buscar', async (req, res) => {
  try {
    if (req.query.id === undefined) {
      return res.status(400).json({
        erro: 'Informe um ID.'
      });
    }

    const id = Number(req.query.id);

    if (!Number.isSafeInteger(id) || id < 0) {
      return res.status(400).json({
        erro: 'ID inválido.'
      });
    }

    const snapshot = await get(ref(db, 'dados'));

    if (!snapshot.exists()) {
      return res.status(404).json({
        mensagem: 'Nenhum registro encontrado.'
      });
    }

    const proximo = Object.values(snapshot.val())
      .filter(dado => dado && dado.id > id)
      .sort((a, b) => a.id - b.id)[0];

    if (!proximo) {
      return res.status(404).json({
        mensagem: 'Não existem publicações posteriores.'
      });
    }

    const usuarioId = Number(req.query.usuarioId) || null;

    return res.status(200).json(
      montarPost(proximo, usuarioId, await amizadesDe(usuarioId))
    );
  } catch (erro) {
    console.error('Erro na busca:', erro);

    return res.status(500).json({
      erro: erro.message
    });
  }
});

app.get('/feed', async (req, res) => {
  try {
    const snapshot = await get(ref(db, 'dados'));

    if (!snapshot.exists()) {
      return res.status(200).json([]);
    }

    const usuarioId = Number(req.query.usuarioId) || null;
    const amizades = await amizadesDe(usuarioId);

    const publicacoes = Object.values(snapshot.val())
      .filter(post => post && typeof post === 'object')
      .sort((a, b) => Number(b.id) - Number(a.id))
      .map(post => montarPost(post, usuarioId, amizades));

    return res.status(200).json(publicacoes);
  } catch (erro) {
    console.error('Erro ao carregar feed:', erro);

    return res.status(500).json({
      erro: 'Erro ao carregar publicações.'
    });
  }
});

app.post('/curtir', async (req, res) => {
  try {
    const usuario = await buscarUsuario(req.body.usuarioId);
    const postId = Number(req.body.postId);

    if (!usuario) {
      return res.status(401).json({ erro: 'Faça login.' });
    }

    if (
      !Number.isSafeInteger(postId) ||
      !(await get(ref(db, `dados/${postId}`))).exists()
    ) {
      return res.status(404).json({
        erro: 'Publicação não encontrada.'
      });
    }

    const resultado = await runTransaction(
      ref(db, `dados/${postId}/curtidas/${usuario.id}`),
      atual => (atual ? null : true)
    );

    const curtidasSnap = await get(
      ref(db, `dados/${postId}/curtidas`)
    );

    return res.status(200).json({
      curtiu: resultado.snapshot.val() === true,
      totalCurtidas: curtidasSnap.exists()
        ? Object.keys(curtidasSnap.val()).length
        : 0
    });
  } catch (erro) {
    console.error('Erro ao curtir:', erro);
    return res.status(500).json({ erro: 'Erro ao curtir.' });
  }
});

app.post('/comentar', async (req, res) => {
  try {
    const usuario = await buscarUsuario(req.body.usuarioId);
    const postId = Number(req.body.postId);
    const texto = String(req.body.texto || '').trim();

    if (!usuario) {
      return res.status(401).json({ erro: 'Faça login.' });
    }

    if (!texto || texto.length > 280) {
      return res.status(400).json({
        erro: 'O comentário deve ter de 1 a 280 caracteres.'
      });
    }

    const postSnap = Number.isSafeInteger(postId)
      ? await get(ref(db, `dados/${postId}`))
      : null;

    if (!postSnap || !postSnap.exists()) {
      return res.status(404).json({
        erro: 'Publicação não encontrada.'
      });
    }

    const status = await statusAmizade(
      usuario.id,
      postSnap.val().autorId
    );

    if (status !== 'eu' && status !== 'amigos') {
      return res.status(403).json({
        erro: 'Você só pode comentar em postagens de amigos.'
      });
    }

    const id = await proximoId(
      `dados/${postId}/contadorComentarios`
    );

    const comentario = {
      id,
      autorId: usuario.id,
      autorNome: usuario.nome,
      autorEmail: usuario.email,
      texto,
      criadoEm: new Date().toISOString()
    };

    await set(
      ref(db, `dados/${postId}/comentarios/${id}`),
      comentario
    );

    return res.status(201).json(comentario);
  } catch (erro) {
    console.error('Erro ao comentar:', erro);
    return res.status(500).json({ erro: 'Erro ao comentar.' });
  }
});

app.post('/amizade/solicitar', async (req, res) => {
  try {
    const usuario = await buscarUsuario(req.body.usuarioId);
    const amigo = await buscarUsuario(req.body.amigoId);

    if (!usuario) {
      return res.status(401).json({ erro: 'Faça login.' });
    }

    if (!amigo) {
      return res.status(404).json({
        erro: 'Usuário não encontrado.'
      });
    }

    if (usuario.id === amigo.id) {
      return res.status(400).json({
        erro: 'Você não pode se adicionar.'
      });
    }

    const atual = await statusAmizade(usuario.id, amigo.id);

    if (atual === 'amigos' || atual === 'enviada') {
      return res.status(200).json({ amizade: atual });
    }

    if (atual === 'recebida') {
      await update(ref(db), {
        [`amizades/${usuario.id}/${amigo.id}`]: 'amigos',
        [`amizades/${amigo.id}/${usuario.id}`]: 'amigos'
      });

      return res.status(200).json({
        mensagem: 'Agora vocês são amigos!',
        amizade: 'amigos'
      });
    }

    await update(ref(db), {
      [`amizades/${usuario.id}/${amigo.id}`]: 'enviada',
      [`amizades/${amigo.id}/${usuario.id}`]: 'recebida'
    });

    return res.status(201).json({
      mensagem: 'Pedido de amizade enviado!',
      amizade: 'enviada'
    });
  } catch (erro) {
    console.error('Erro ao solicitar amizade:', erro);
    return res.status(500).json({
      erro: 'Erro ao solicitar amizade.'
    });
  }
});

app.post('/amizade/responder', async (req, res) => {
  try {
    const usuario = await buscarUsuario(req.body.usuarioId);
    const amigoId = Number(req.body.amigoId);
    const aceitar =
      req.body.aceitar === true || req.body.aceitar === 'true';

    if (!usuario) {
      return res.status(401).json({ erro: 'Faça login.' });
    }

    if ((await statusAmizade(usuario.id, amigoId)) !== 'recebida') {
      return res.status(400).json({
        erro: 'Não há pedido de amizade deste usuário.'
      });
    }

    await update(ref(db), {
      [`amizades/${usuario.id}/${amigoId}`]: aceitar ? 'amigos' : null,
      [`amizades/${amigoId}/${usuario.id}`]: aceitar ? 'amigos' : null
    });

    return res.status(200).json({
      mensagem: aceitar ? 'Amizade aceita!' : 'Pedido recusado.',
      amizade: aceitar ? 'amigos' : 'nenhuma'
    });
  } catch (erro) {
    console.error('Erro ao responder amizade:', erro);
    return res.status(500).json({
      erro: 'Erro ao responder pedido.'
    });
  }
});

app.get('/amizades', async (req, res) => {
  try {
    const usuario = await buscarUsuario(req.query.usuarioId);

    if (!usuario) {
      return res.status(401).json({ erro: 'Faça login.' });
    }

    const lista = { recebidas: [], enviadas: [], amigos: [] };
    const relacoes = await amizadesDe(usuario.id);

    for (const [outroId, status] of Object.entries(relacoes)) {
      const outro = await buscarUsuario(outroId);
      if (!outro) continue;

      const grupo = status === 'recebida'
        ? 'recebidas'
        : status === 'enviada' ? 'enviadas' : 'amigos';

      lista[grupo].push(usuarioPublico(outro));
    }

    return res.status(200).json(lista);
  } catch (erro) {
    console.error('Erro ao listar amizades:', erro);
    return res.status(500).json({
      erro: 'Erro ao listar amizades.'
    });
  }
});

const normalizar = texto =>
  String(texto || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();

const arrobaDe = email =>
  normalizar(String(email || '').split('@')[0]);

const hashtagsDe = texto =>
  (normalizar(texto).match(/#[\p{L}\p{N}_]+/gu) || []);

async function todosPosts() {
  const snapshot = await get(ref(db, 'dados'));

  return snapshot.exists()
    ? Object.values(snapshot.val())
      .filter(p => p && typeof p === 'object')
      .sort((a, b) => Number(b.id) - Number(a.id))
    : [];
}

async function todosUsuarios() {
  const snapshot = await get(ref(db, 'usuarios'));

  return snapshot.exists()
    ? Object.values(snapshot.val()).filter(u => u && u.id)
    : [];
}

app.get('/pesquisar', async (req, res) => {
  try {
    const termo = normalizar(req.query.q);
    const usuarioId = Number(req.query.usuarioId) || null;

    if (!termo) {
      return res.status(400).json({ erro: 'Digite algo para pesquisar.' });
    }

    const amizades = await amizadesDe(usuarioId);
    const semArroba = termo.replace(/^[@#]/, '');

    let filtroPost;

    if (termo.startsWith('#')) {
      filtroPost = p => hashtagsDe(p.texto).includes(termo);
    } else if (termo.startsWith('@')) {
      filtroPost = p =>
        arrobaDe(p.autorEmail) === semArroba ||
        normalizar(p.texto).includes(termo);
    } else {
      filtroPost = p =>
        normalizar(p.texto).includes(termo) ||
        normalizar(p.autorNome).includes(termo);
    }

    const posts = (await todosPosts())
      .filter(filtroPost)
      .map(p => montarPost(p, usuarioId, amizades));

    const pessoas = termo.startsWith('#')
      ? []
      : (await todosUsuarios())
        .filter(u =>
          normalizar(u.nome).includes(semArroba) ||
          arrobaDe(u.email).includes(semArroba)
        )
        .map(u => ({
          ...usuarioPublico(u),
          amizade: Number(u.id) === usuarioId
            ? 'eu'
            : (amizades[u.id] || 'nenhuma')
        }));

    return res.status(200).json({ termo, posts, pessoas });
  } catch (erro) {
    console.error('Erro na pesquisa:', erro);
    return res.status(500).json({ erro: 'Erro ao pesquisar.' });
  }
});

app.get('/hashtags', async (req, res) => {
  try {
    const contagem = {};

    for (const post of await todosPosts()) {
      for (const tag of new Set(hashtagsDe(post.texto))) {
        contagem[tag] = (contagem[tag] || 0) + 1;
      }
    }

    const emAlta = Object.entries(contagem)
      .map(([tag, total]) => ({ tag, total }))
      .sort((a, b) => b.total - a.total)
      .slice(0, 10);

    return res.status(200).json(emAlta);
  } catch (erro) {
    console.error('Erro nas hashtags:', erro);
    return res.status(500).json({ erro: 'Erro ao carregar hashtags.' });
  }
});

app.get('/perfil', async (req, res) => {
  try {
    const perfil = await buscarUsuario(req.query.id);
    const usuarioId = Number(req.query.usuarioId) || null;

    if (!perfil) {
      return res.status(404).json({ erro: 'Usuário não encontrado.' });
    }

    const amizades = await amizadesDe(usuarioId);
    const amigosDoPerfil = Object.values(await amizadesDe(perfil.id))
      .filter(status => status === 'amigos').length;

    const posts = (await todosPosts())
      .filter(p => Number(p.autorId) === Number(perfil.id))
      .map(p => montarPost(p, usuarioId, amizades));

    return res.status(200).json({
      usuario: usuarioPublico(perfil),
      criadoEm: perfil.criadoEm,
      amizade: Number(perfil.id) === usuarioId
        ? 'eu'
        : (amizades[perfil.id] || 'nenhuma'),
      totalAmigos: amigosDoPerfil,
      posts
    });
  } catch (erro) {
    console.error('Erro no perfil:', erro);
    return res.status(500).json({ erro: 'Erro ao carregar perfil.' });
  }
});

app.get('/debug/storage', async (req, res) => {
  try {
    const { data, error } =
      await supabase.storage.listBuckets();

    if (error) {
      return res.status(500).json({
        erro: error.message,
        codigo: error.statusCode
      });
    }

    return res.json({
      bucketConfigurado: bucket,
      bucketsEncontrados: data.map(b => ({
        id: b.id,
        nome: b.name,
        publico: b.public
      })),
      existe: data.some(b => b.id === bucket)
    });
  } catch (erro) {
    return res.status(500).json({
      erro: erro.message
    });
  }
});

app.get('/health', (req, res) => {
  return res.status(200).json({
    status: 'UP',
    timestamp: new Date().toISOString()
  });
});

app.use((erro, req, res, next) => {
  if (erro instanceof multer.MulterError) {
    return res.status(400).json({
      erro: erro.code === 'LIMIT_FILE_SIZE'
        ? 'Imagem maior que 5 MB.'
        : erro.message
    });
  }

  console.error('Erro interno:', erro);

  return res.status(500).json({
    erro: 'Erro interno do servidor.'
  });
});

app.listen(port, () => {
  console.log(
    `Servidor rodando em http://localhost:${port}`
  );
});
