# X Bolsonaro — Mini Twitter (DDM, Aula 14)

App em Flutter parecido com o X (Twitter), com servidor em Node.js.

- **Firebase Realtime Database**: usuários, publicações, curtidas, comentários e amizades
- **Supabase Storage**: fotos das publicações
- **shared_preferences**: login salvo no aparelho

## O que o app faz

| Funcionalidade | Onde testar |
|---|---|
| Cadastro (nome, e-mail, senha) e login (e-mail, senha) | Tela inicial |
| Login salvo no `shared_preferences`: ao reabrir, entra direto | Feche e abra o app |
| Publicar texto e foto (opcional), só logado | Topo do feed |
| Ver as publicações de todos | Feed |
| Curtir / descurtir | Coração no post |
| Pedir amizade ao autor de um post | Botão **Adicionar** no post |
| Aceitar ou recusar pedidos | Ícone de pessoas na barra superior |
| Comentar **só em posts de amigos** | Balão no post (cadeado se não for amigo) |
| Pesquisa por texto, `#hashtag` ou `@usuario`, com abas Posts e Pessoas | Lupa na barra superior |
| `#hashtags` e `@menções` clicáveis, hashtags em alta | Texto dos posts / tela de pesquisa |
| Perfil do usuário com os posts dele | Toque no nome do autor |

## Como rodar

Precisa de **Node.js 18+** e **Flutter**.

### 1. Servidor (Node)

Na pasta do projeto:

```bash
npm install
node server.js
```

Deve aparecer `Servidor rodando em http://localhost:3000`.

As chaves públicas do Firebase e do Supabase já estão no `.env.example`, que o servidor
lê automaticamente. Não é preciso criar `.env`.

### 2. App (Flutter)

Em outro terminal, com o servidor ligado:

```bash
cd x_app
flutter pub get
flutter run -d chrome
```

**Chrome é o jeito mais fácil.** No **emulador Android** use `flutter run`. O app acessa o
servidor por `10.0.2.2:3000`, que é o endereço do PC visto de dentro do emulador.
No Windows desktop o Flutter exige o "Modo de desenvolvedor" ligado.

### Roteiro de teste sugerido

1. Crie duas contas (ex.: em duas abas anônimas do Chrome).
2. Com a conta A, publique um texto com `#teste` e uma foto.
3. Com a conta B, curta o post e tente comentar: fica bloqueado (cadeado).
4. Com a conta B, toque em **Adicionar**; com a conta A, aceite pelo ícone de pessoas.
5. Agora a conta B consegue comentar.
6. Toque em `#teste` para abrir a pesquisa, e no nome do autor para abrir o perfil.

## Estrutura

```
server.js                  API (Express) — rotas abaixo
public/index.html          versão web simples do feed
x_app/lib/
  main.dart                abertura: verifica login salvo
  config.dart              endereço do servidor
  servicos/                auth_service (login/cadastro), social_service (interações)
  telas/                   login, cadastro, publicação (feed), comentários,
                           amizades, pesquisa, perfil
  widgets/                 card do post e texto com links (#/@)
```

### Rotas da API

| Método | Rota | Uso |
|---|---|---|
| POST | `/cadastro` | `{ nome, email, senha }` |
| POST | `/login` | `{ email, senha }` |
| POST | `/salvar` | multipart: `usuarioId`, `texto`, `imagem` (opcional) |
| GET | `/feed?usuarioId=` | todas as publicações |
| GET | `/buscar?id=&usuarioId=` | próxima publicação após o ID |
| POST | `/curtir` | `{ usuarioId, postId }` (alterna) |
| POST | `/comentar` | `{ usuarioId, postId, texto }` (só amigos) |
| POST | `/amizade/solicitar` | `{ usuarioId, amigoId }` |
| POST | `/amizade/responder` | `{ usuarioId, amigoId, aceitar }` |
| GET | `/amizades?usuarioId=` | pedidos recebidos, enviados e amigos |
| GET | `/pesquisar?q=&usuarioId=` | posts e pessoas |
| GET | `/hashtags` | hashtags em alta |
| GET | `/perfil?id=&usuarioId=` | dados e posts de um usuário |
