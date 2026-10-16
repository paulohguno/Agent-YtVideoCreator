# Diferencas entre o PDF (v3, md5 81e5e90c...) e a realidade dos repositorios

Etapa 0, 2026-10-16. Regra: quando o PDF e a realidade divergem, a realidade vence (agente-construtor.md).
Cada item: o que o PDF diz -> o que existe de fato -> como o sistema se adapta. Fonte entre parenteses.

## A. Repositorios e commits (vendor.lock.json)

Todos clonados e com hash conferido (`git rev-parse HEAD` comeca pelo commit do lock):

| nome (lock) | commit fixado | HEAD completo | ponta do branch padrao | licenca lida |
|---|---|---|---|---|
| voicestudio | 28d1802 | 28d18023436229830debe8e65faf3eba4426f31b | 86825f6 (upstream avancou) | AGPL-3.0-only (LICENSE-NOTICE.md) |
| motion-graphics-skills | 7f0c371 | 7f0c3714dc81bea52644a5287c6350345009e579 | igual | MIT |
| code-films | 657bf91 | 657bf91ea9bc008afbd032d7b0a4b429998aec24 | igual | MIT |
| youtube-agent-skill | a2feb21 | a2feb2104981a375ffd4f87ee04f4f5344ac43c6 | igual | MIT |
| youtube-thumbnail-generator-ai | 21f0674 | 21f06742e61d801ae2e264797435db6c96e9720f | igual | MIT |
| youtube-thumbnail-generator-pil | 3f3ff63 | 3f3ff63d256d041c5eec44f90b02536c0048012d | igual | MIT |
| galeria-ia-catalogo | 81d0231 | 81d02313f48d16c7ba9d3ec42742aa1592870687 | igual | CC0-1.0 |

1. **Nomes de pasta.** PDF 3.2: `vendor/galeria-ia/` e `vendor/thumbnails/` (tres repos dentro). Realidade: o lock
   usa `vendor/galeria-ia-catalogo/` e tres pastas separadas (`youtube-agent-skill`, `youtube-thumbnail-generator-ai`,
   `youtube-thumbnail-generator-pil`). Adaptacao: segue o lock; os caminhos ficam em `config.yaml` (`paths.vendor.*`).
2. **skills/motion-graphics.** PDF 3.2 pede uma copia fixada em `/agente/skills/motion-graphics/`. A skill vive em
   `vendor/motion-graphics-skills/skills/motion-graphics/`. Adaptacao: `config.yaml` aponta `paths.skill_motion` para a
   pasta do vendor (sem copia duplicada, sem editar nada). 
3. **VoiceStudio upstream avancou** alem de 28d1802. Mantido o commit fixado.

## B. VoiceStudio (API)

4. **Servidor nao esta rodando.** `GET http://localhost:3900/health` -> conexao recusada. O app esta instalado
   (`/Applications/VoiceStudio.app`), mas nao foi aberto: subir o backend carrega modelos (pesado) e precisa de
   decisao do usuario. Consequencia: `GET /v1/audio/voices` e `GET /openapi.json` NAO foram consultados ao vivo; o
   perfil 'Paulo' NAO foi resolvido por ID. O contrato abaixo veio da leitura do codigo no commit fixado.
5. **Versao instalada != versao fixada.** App instalado: 0.5.6 (Info.plist). Repo fixado: 0.5.7 (pyproject.toml).
   Entre v0.5.6 e 28d1802 o `openai_compat.py` mudou (+186 linhas): a resolucao de voz por NOME (sem distinguir
   maiusculas) e o **409 de nome ambiguo** com `matching_ids` so existem na 0.5.7. Na 0.5.6 instalada, nome nao e
   resolvido como perfil. Adaptacao: o cliente sempre envia o **ID do perfil** descoberto em `/v1/audio/voices`
   (nunca o nome) e registra a versao do `/openapi.json` (`info.version`) no run.json. Pendente: confirmar ao vivo.
6. **model padrao.** PDF 5.2 usa `"model": "omnivoice"`. Codigo: default `omnivoice`; aceita os ids de engine
   (`omnivoice`, `voxcpm2`, `cosyvoice`, `mlx-audio`, `kittentts`, `moss-tts-nano`, ...) e aliases OpenAI (`tts-1`
   etc.) que caem no engine ativo. Engine indisponivel -> **400** `model_not_available`, modelo desconhecido -> 400
   `model_not_found`. Adaptacao: o engine vem do campo `engines` de `/v1/audio/voices` e e gravado no run.json.
7. **Formato de `/v1/audio/voices`.** Resposta real: `{"voices": [...], "engines": [...]}`. Cada voz tem
   `voice_id`, `name`, `type` (`openai_alias` ou `profile`), e para perfis `language` e `addressable_by_name`.
   Os aliases OpenAI (alloy, nova...) aparecem sempre e mapeiam para a voz padrao do engine: o passo zero
   (opcao B) **nao** os oferece como vozes reais (PDF 3.1 ja exigia isso).
8. **Erros de validacao sao 400, nao 422.** O router reescreve RequestValidationError para 400 no formato OpenAI
   (`{"error": {"message", "type", "param", "code"}}`). O cliente trata 400 como erro definitivo (sem retry).
9. **Codigos adicionais que o PDF nao lista:** 403 `ModelLicenceNotAccepted` (licenca do modelo nao aceita no app —
   e diferente de falta de credencial; o cliente informa a causa pelo `code`), 429 com `Retry-After` (fila/hardware
   ocupado), 503 com `Retry-After: 30` e `X-OmniVoice-Retryable: true` (modelo carregando/baixando), 500 generico,
   504 em transcricao. Adaptacao: 429/503 -> no maximo 2 tentativas respeitando Retry-After (limitado por config);
   400/401/403/404/409 -> sem retry.
10. **Campos extras do SpeechRequest** nao citados no PDF: `instructions`, `instruct`, `description`, `duration`
    (alvo em segundos), `seed`, `denoise`, `preprocess_prompt`, `num_step`, `guidance_scale`, `stream_format`,
    `chunk_*`. Adaptacao: o cliente envia so os campos do contrato 5.2 mais `seed` (determinismo, entra no hash do
    cache). `duration` NAO e usado: forcar duracao no TTS seria esticar fala, e o PDF 6.7 manda reescrever.
11. **Cabecalho `X-OmniVoice-Routing`.** Quando o engine roda em rota diferente da pedida (ex.: CPU em vez de GPU),
    a resposta traz esse aviso. Adaptacao: o cliente grava o aviso no run.json/eventos (nao e erro).
12. **`/health`.** Confirmado: 503 `{"status":"starting","step":...}` durante a subida, 200 quando pronto
    (`backend/main.py`). Nao ha `Retry-After` no /health; o cliente usa espera configuravel.
13. **Licenca.** VoiceStudio e AGPL-3.0 (uso comercial do app permitido). **O modelo padrao OmniVoice tem pesos
    CC-BY-NC** (nao comercial) e o tokenizer tem termos Higgs Audio/Llama (LICENSE-NOTICE.md). O PDF so diz
    "verificar". Isso afeta uso comercial dos audios: ver PENDENCIAS.md (P-04).

## C. Skill motion-graphics (v1.4.1)

14. **Flags conferidas** (cabecalho dos scripts; `render.mjs` nao tem `--help` — rodar sem argumentos inicia um
    render; por isso as flags foram lidas no codigo):
    - `new-project.mjs <dir> [--name] [--format 16:9|9:16|1:1|4:5] [--fps 60] [--bpm 120] [--lang xx] [--force]`
      (existe `--fps`, que o PDF nao cita).
    - `render.mjs [--draft] [--range a-b] [--skip-frames] [--jobs N] [--sub 16] [--chunk 2] [--query ...]
      [--audio <wav>] [--out <mp4>] [--crf 15] [--grain 3] [--no-web] [--no-covers] [--no-qa] [--scale]`.
      `--audio` existe (PDF 6.2 correto). Sem `--audio`, usa `out/music.wav` (ou `out/music-<lang>.wav`).
    - `capture.mjs doctor | still <t...> | sheet <t0> <t1> <n> | review | verify [--n] | render | eval "<expr>"
      [--times a,b]`; comuns `--query`, `--debug`, `--root`, `--browser`. `--query only=<cena>` existe.
    - `kit.mjs <arquivos|pastas> [--out audio/kit]`: `--help` responde. Rodado num wav sintetico: **converte cada
      arquivo para WAV 48 kHz estereo em `audio/kit/` e grava `audio/kit/KIT.md`** (duracao, pico, momento mais alto).
      Ele nao so "informa a duracao" (PDF 2/6.2): escreve no projeto. O orquestrador mede a duracao com ffprobe
      (fonte de verdade para as janelas) e usa o kit.mjs para colocar os clipes em `audio/kit/`.
    - `plan-check.mjs` (sem flags), `audio-check.mjs [wav] [--lufs -14] [--zoom a-b] [--against ...]`,
      `qa.mjs [mp4] [--lufs -14] [--draft]`, `export-timeline.mjs`, `cutdown.mjs --ranges`.
15. **Comandos do PDF 6.2 rodam a partir da pasta do projeto** (`node tools/...`), exceto `new-project.mjs` e os
    `scripts/` da skill. O skill_runner usa `cwd=<projeto do run>`.
16. **`--lang pt` quebra o template demo.** Com `--lang pt`, `js/copy.mjs` fica com `DEFAULT_LANG = "pt"`, mas o
    COPY do demo so tem `en`: `capture.mjs` da `page error` (`Cannot read properties of undefined (reading 'hook')`)
    e `audio/score.mjs` falha (`reading 'contacts'`). Adaptacao: o ProjectBuilder **sempre** grava `COPY.pt`
    completo (mesmas chaves que as cenas usam) antes de qualquer captura. Teste de contrato cobre isso.
17. **A voz entra no score, nao num mix externo.** pipeline.md 12: os clipes vao para `audio/kit/` e o
    `audio/score.mjs` os posiciona com `sample(LINE.<cena>, 'audio/kit/vo-<cena>.wav', { align: 'start' })`;
    o duck e por barramento (`bus(name, { duck: [{ from, depth, attack, release }] })`, gatilhos via `trigger()`).
    footage.md 12 recomenda duck de 12-15 dB sob a voz; o PDF 6.12.5 pede < -20 dB. Adaptacao: alvo -20 dB
    (o mais restritivo) configuravel. `render.mjs --audio <mix.wav>` continua possivel para a trilha orquestral.
18. **Timeline de voz-over** (pipeline.md 12): `PRE=0.5, GAP=0.4, TAIL=2.5, OVER=0.3` no exemplo; o PDF exige guarda
    minima 0.2 s e `clip_frames(seconds, fps, pad_s=0.2)`. Compativel: GAP >= 0.2; valores em config.yaml.
19. **Area segura 9:16.** PDF 6.10.2: 120 px topo / 300 px base. pipeline.md 7: texto dentro do meio 1080x1420
    (UI cobre ~220 px no topo e ~320 px na base); footage.md 13 idem. Adaptacao: usa os valores da skill
    (220/320), mais restritivos, configuraveis.
20. **Modulos de cena: extensao `.js`**, nao `.mjs` (template: `js/scenes/hook.js`, lista `SCENES` em `js/reel.js`).
    O requisito de economia cita `js/scenes/*.mjs`; o sistema segue a skill (`.js`).
21. **Cookbook** confere com as secoes citadas no PDF (2 kinetic type, 4 decode, 5 rolling numbers, 15 grade 2x2,
    18 charts, 19 lockup, 24 words from mask, 25 proof number, 26 loop end card, 28 rack focus...). OK.
22. **QA da skill falha no score demo** (`unique` FAIL) e avisa `template` enquanto houver codigo `@template-demo`.
    O catalogo de cenas e o gerador de score precisam substituir todos os arquivos demo.
23. **Captura trava sem saida clara.** Num erro de pagina, `capture.mjs` espera 60 s por `window.__ready`; uma
    execucao de `verify` ficou parada sem saida. Adaptacao: o skill_runner aplica timeout proprio e mata so os PIDs
    que iniciou.
24. **A skill proibe stock e video de IA** ("No stock footage or music libraries, no AI video"). D1 (midia gratuita)
    e Veo sao desvios registrados em DECISOES.md, como o PDF ja previa.

## D. code-films (trilha)

25. `engine/pipeline/orchestra.py` existe com strings, brass, choir, piano, harp, taiko, timpani, crash, braam, sub,
    pulse/arp e `class Score` + `reverb`. Depende de `numpy` e `scipy` (requirements.txt do repo) — ainda nao estao no
    ambiente. `loudnorm.py` mira **-16 LUFS / TP -1.5**, confirmado; o projeto usa -14 / -1 (wrapper proprio).
    Documentacao em chines, confirmado. Modulo opcional (pos-etapa 8).

## E. Thumbnails e hooks

26. `youtube-agent-skill`: `skills/yt-script/hooks.json` tem **21** formulas (`{version, note, rules, hooks}`),
    `skills/yt-script/hookscore.py` e `skills/yt-package/title.py` existem. As heuristicas sao em ingles (amostra de
    74 hooks em ingles, segundo o proprio script): para pt-BR a nota e indicativa. Modulo opcional.
27. `youtube-thumbnail-generator-pil`: 1280x720 e limite de 2 MB confirmados; otimizado para chines/ingles.
28. `youtube-thumbnail-generator-ai`: app completo (api, workers, banco). Uso apenas de `scene_detection.py`,
    `face_extraction.py` como referencia/wrapper. Modulo opcional.

## F. Galeria IA

29. PDF 6.17: "60 produtos ... mais 20 imagens de variantes, com o campo aiGenerated ... em catalogue.json; uma
    imagem sem aiGenerated verdadeiro nao e tratada como gerada". Realidade: 60 produtos, **200 imagens**, e o campo
    `aiGenerated` fica **em cada imagem** (`products[].images[].aiGenerated`, todas `true`), nao no produto.
    Adaptacao: a origem e decidida por imagem. Por decisao do usuario, a galeria nao e integrada como fonte nesta
    fase (DECISOES.md DEC-10).

## G. Mudancas da nova versao do PDF (md5 81e5e90c...)

30. 3.1: o passo zero agora tambem pergunta o **Veo** depois da voz (`--veo off|api|prompt`).
31. 13.1 nova: tabela dos repositorios fixados (igual ao lock). Cita `purffle-shorts (bab8d5f, MIT)` como referencia
    descartada (nao clonado).

## H. Ambiente

32. Node 24.11.1 (>= 22.4 ok), ffmpeg/ffprobe 9.0.1, Google Chrome instalado, Python 3.13 (>= 3.11 ok).
    `pdftotext`/`pdftoppm` ausentes (PDF lido com pypdf num venv temporario).
33. Smoke da skill (antes da ordem de nao renderizar): `new-project` 9:16 pt ok, `plan-check` 0 FAIL / 2 WARN
    (template), `capture still` e `verify` (PASS, 14 tempos) com `--query lang=en`, `kit.mjs` ok, e um
    `render --draft` do demo (540x960, 60 fps, 13 s, -14.1 LUFS, QA 1 FAIL `unique` esperado no demo). A pasta
    do smoke foi apagada. Depois disso nenhum render foi feito: render so com pedido do usuario.
