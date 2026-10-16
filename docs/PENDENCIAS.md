# Pendencias

| ID | Pendencia | Bloqueia | Proxima acao |
|---|---|---|---|
| P-01 | Etapa 0 foi feita em macOS; este ambiente e Linux/WSL. vendor/ ja clonado pelo instalar.sh. | Etapa 1 | Refazer a leitura da Etapa 0 aqui e atualizar DIFERENCAS.md. |
| P-02 | Resolvido pelo instalar.sh: Node 24 como padrao do nvm. | - | - |
| P-03 | Resolvido pelo instalar.sh: Google Chrome instalado. | - | - |
| P-04 | Pesos padrao do OmniVoice sao CC-BY-NC (nao comercial); tokenizer com termos Higgs Audio/Llama. | Uso comercial dos audios | Conferir no LICENSE-NOTICE.md quais engines locais com clonagem permitem uso comercial antes de monetizar (DEC-16). |
| P-05 | VoiceStudio nao esta rodando neste ambiente (localhost:3900); perfis de voz nao consultados. | Etapa 2 | Ligar a integracao WSL do Docker Desktop e rodar ./instalar.sh --sem-sistema; depois criar o perfil clonado com o audio de referencia do usuario e rodar GET /v1/audio/voices. |
| P-06 | Claude Code CLI precisa estar instalado no WSL e logado (`claude`). Chaves de midia sao opcionais (DEC-18). | Etapa 3 | Rodar `claude` uma vez e fazer login. Opcional: chaves gratuitas de Pexels/Pixabay em config/.env. |
