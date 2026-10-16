# Agent-YtVideoCreator

Agente que cria videos (Shorts, Reels, TikTok e 16:9) a partir de um tema: pesquisa com fontes, roteiro,
narracao com a sua voz clonada (VoiceStudio, tudo local), imagens e videos de acervos livres e composicao
em motion graphics. A especificacao esta em [docs/Orquestrador_Video_v3_Opus55.pdf](docs/Orquestrador_Video_v3_Opus55.pdf);
as decisoes que mudam o PDF estao em [docs/DECISOES.md](docs/DECISOES.md).

## Fluxo do zero

### 1. Clonar e instalar

Ubuntu/Debian ou WSL2 (Windows).

```bash
git clone git@github.com:paulohguno/Agent-YtVideoCreator.git
cd Agent-YtVideoCreator
./instalar.sh
```

O instalador e idempotente (pode rodar de novo quando quiser) e faz:

| Item | O que instala |
|---|---|
| Sistema (apt) | ffmpeg, ffprobe, git, python3-venv, poppler-utils, fontes, Google Chrome |
| Node.js | 24 via nvm, definido como padrao (a skill exige >= 22.4) |
| Claude Code CLI | `claude`, usado para pesquisa e roteiro com o seu login |
| vendor/ | os 7 repositorios de terceiros nos commits do [vendor.lock.json](vendor.lock.json) |
| Python | `.venv` com o `requirements.txt` (quando existir) |
| Pastas | `../saidas` (um diretorio por video) e `cache/` |
| config/.env | criado a partir de [config/.env.example](config/.env.example) |
| VoiceStudio | container Docker no mesmo commit do lock, em `localhost:3900`, com volume persistente |

Opcoes: `--verificar` (so confere), `--sem-sistema` (pula apt), `--sem-voicestudio`, `--gpu` (NVIDIA).

### 2. Docker para o VoiceStudio (WSL)

No Docker Desktop do Windows: **Settings > Resources > WSL integration** e ligue a sua distro.
Depois:

```bash
./instalar.sh --sem-sistema
```

Na primeira vez o VoiceStudio baixa cerca de 2,4 GB de modelos (`docker logs -f voicestudio`).

### 3. Login no Claude

```bash
claude
```

Entre com a sua conta uma vez. O agente usa `claude -p` com esse login; nao precisa de chave de API.

### 4. Clonar a sua voz

Abra http://localhost:3900, va em **Voice cloning** e crie um perfil com um audio limpo da sua voz
(sem musica nem eco, de alguns segundos a um minuto). O agente nunca clona sozinho; ele so le os perfis
pela API.

### 5. Chaves de midia (opcional)

Sem nenhuma chave o agente ja busca em Wikimedia Commons, NASA, Openverse, Internet Archive,
Library of Congress, The Met, Art Institute of Chicago e Cleveland Museum of Art. Para ter mais video de
stock, crie chaves gratuitas e preencha em `config/.env`: Pexels, Pixabay, Unsplash, Europeana, Smithsonian.

### 6. Conferir

```bash
./instalar.sh --verificar
```

### 7. Construir o sistema (uma vez)

Abra o Claude Code nesta pasta e peca: **"use o agente-construtor e comece pela etapa 0"**.
Ele segue as etapas 0 a 8 do PDF, com testes, e registra o progresso em `docs/PROGRESSO.md`.
Definicao: [.claude/agents/agente-construtor.md](.claude/agents/agente-construtor.md).

### 8. Gerar videos

Depois da etapa 8, peca: **"use o gerador-video: video de 30 s sobre <tema>, tipo historico"**.

1. Ele confirma a voz (seu perfil clonado), o tipo e o formato.
2. Gera um rascunho e para; voce assiste em `../saidas/<run_id>/`.
3. Voce aprova ou pede ajustes. So com aprovacao ele faz o render final.

Definicao: [.claude/agents/gerador-video.md](.claude/agents/gerador-video.md).

## Pastas

```
Agent-YtVideoCreator/   o agente (codigo, config, vendor, cache, testes, docs)
saidas/                 um diretorio por video, fora do agente
```

## Licencas

Os pesos padrao do OmniVoice (VoiceStudio) sao CC-BY-NC, nao comerciais. Antes de monetizar, veja
[docs/PENDENCIAS.md](docs/PENDENCIAS.md) (P-04).
