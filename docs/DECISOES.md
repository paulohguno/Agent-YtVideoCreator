# Decisoes

Decisoes do usuario e desvios do PDF (Orquestrador_Video_v3_Opus55.pdf, md5 81e5e90c...).
Onde este arquivo e o PDF divergem, este arquivo vale. Cada troca de decisao gera uma entrada nova.

| ID | Data | Decisao | Origem |
|---|---|---|---|
| DEC-01 | 2026-10-16 | D1: midia gratuita entra na v1, com o maximo de fontes com API oficial e licenca clara (Pexels, Pixabay, Unsplash, Wikimedia Commons, NASA, Smithsonian, Met, Openverse, Internet Archive, Library of Congress, Europeana). Nota visual >= 7 e licenca registrada. Desvio da skill motion-graphics, que nao usa stock. | Usuario |
| DEC-02 | 2026-10-16 | D2: modo automatico (catalogo de cenas) e o padrao; modo agente so com --cenas agente. | Recomendacao do PDF |
| DEC-03 | 2026-10-16 | D3: formato padrao 9:16. | Recomendacao do PDF |
| DEC-04 | 2026-10-16 | D4: sem fallback de voz hospedada; so com opt-in registrado no run.json. | Recomendacao do PDF |
| DEC-05 | 2026-10-16 | D5: voz de terceiros so com autorizacao registrada; voz propria exige declaracao do usuario. | Recomendacao do PDF |
| DEC-06 | 2026-10-16 | D6: pt-BR, --lang pt (com COPY.pt completo, ver DIFERENCAS 16). | Recomendacao do PDF |
| DEC-07 | 2026-10-16 | D7: 60 FPS; --draft na revisao. | Recomendacao do PDF |
| DEC-08 | 2026-10-16 | Claude substitui o Gemini em pesquisa (web search), roteiro, verificacao, reescrita e avaliacao visual. Modelos por tarefa em config.yaml (agente-construtor.md). Pesquisa e saida estruturada continuam em chamadas separadas. | Usuario |
| DEC-09 | 2026-10-16 | Testes reais permitidos na construcao: sintese de voz curta (etapa 2), smoke de 20 s em --draft (etapa 5) e um render final de 20 s em 9:16 (etapa 6), sempre em /saidas/<run_id>. | Usuario |
| DEC-10 | 2026-10-16 | Galeria de IA (galeria-ia-catalogo) nao e integrada como fonte nesta fase. | Usuario |
| DEC-11 | 2026-10-16 | Perfis de rigor por tipo de video: completo (historico, fatos, curiosidade...), leve (infantil, ficcao), opiniao. Previa com aprovacao e QA tecnico valem para todos. | Usuario |
| DEC-12 | 2026-10-16 | Fluxo em duas fases: run para em AWAITING_APPROVAL (estado novo, nao previsto na secao 7) apos a previa; resume --aprovar faz o render final. Paradas com pergunta usam AWAITING_INPUT. O gerador-video devolve as perguntas para a sessao principal. | Usuario |
| DEC-13 | 2026-10-16 | /agente = raiz deste repositorio; /saidas = ../saidas. Caminhos em config.yaml. | Agente construtor |
| DEC-14 | 2026-10-16 | Skill motion-graphics usada direto de vendor/motion-graphics-skills/skills/motion-graphics (sem copia em skills/). | DIFERENCAS 2 |
| DEC-15 | 2026-10-16 | v1 = etapas 1-8 + pesquisa (6.5) + midia (6.4) + QA de enquadramento, imersao e audio (6.9-6.11). Trilha code-films, thumbnails e Veo ficam para depois da v1. | Usuario |
| DEC-16 | 2026-10-16 | Voz: clonagem da propria voz do usuario no VoiceStudio, tudo local (opcao A, --voice-source own). Nenhum provedor de voz na nuvem. O perfil clonado e criado pelo usuario no app a partir do audio de referencia dele; o agente nunca clona sozinho. O voice_id do perfil ainda e confirmado em cada run (3.1). A opcao B (modelo do app) continua disponivel so se o usuario pedir. |  Usuario |
| DEC-17 | 2026-10-16 | Claude chamado pelo Claude Code CLI (`claude -p`, login do usuario), nao pela API com chave. Substitui a forma de chamada de DEC-08; os modelos por tarefa continuam. Custo e tokens vem do JSON do CLI. | Usuario |
| DEC-18 | 2026-10-16 | Midia: fontes sem chave ligadas por padrao (Wikimedia Commons, NASA, Openverse, Internet Archive, Library of Congress, Met, Art Institute of Chicago, Cleveland Museum of Art). Fontes com chave gratuita (Pexels, Pixabay, Unsplash, Europeana, Smithsonian) ficam prontas e ligam quando a chave for preenchida. | Usuario |
