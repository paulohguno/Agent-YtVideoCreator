#!/usr/bin/env bash
# Instalador de dependencias do Agent-YtVideoCreator (Ubuntu/Debian, inclusive WSL2).
# Idempotente: pode rodar de novo quando quiser; so instala o que falta.
#
# Uso:
#   ./instalar.sh                 instala tudo
#   ./instalar.sh --verificar     so confere o ambiente, sem instalar nada
#   ./instalar.sh --sem-sistema   pula apt (ffmpeg, python, Chrome)
#   ./instalar.sh --sem-voicestudio   nao sobe o container do VoiceStudio
#   ./instalar.sh --gpu           sobe o VoiceStudio com GPU NVIDIA (--gpus all)
#
# Nada aqui imprime chaves. Segredos ficam so em config/.env (fora do git).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAIDAS="$(cd "$RAIZ/.." && pwd)/saidas"
ENV_FILE="$RAIZ/config/.env"
NODE_MIN="22.4.0"
NODE_VERSAO="24"
VS_CONTAINER="voicestudio"
VS_VOLUME="voicestudio-data"
VS_PORTA="3900"

SO_VERIFICAR=0; SEM_SISTEMA=0; SEM_VS=0; GPU=0
for a in "$@"; do
  case "$a" in
    --verificar) SO_VERIFICAR=1 ;;
    --sem-sistema) SEM_SISTEMA=1 ;;
    --sem-voicestudio) SEM_VS=1 ;;
    --gpu) GPU=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "opcao desconhecida: $a"; exit 2 ;;
  esac
done

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$*"; }
aviso(){ printf '  \033[33mAVISO\033[0m %s\n' "$*"; }
falha(){ printf '  \033[31mFALTA\033[0m %s\n' "$*"; }
etapa(){ printf '\n\033[1m== %s\033[0m\n' "$*"; }

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
eh_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Le uma chave do config/.env sem imprimir o valor.
env_get() { [ -f "$ENV_FILE" ] && grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true; }
env_set() {
  local k="$1" v="$2"
  if grep -qE "^$k=" "$ENV_FILE"; then
    python3 - "$ENV_FILE" "$k" "$v" <<'PY'
import sys
p, k, v = sys.argv[1:]
linhas = open(p).read().splitlines()
open(p, "w").write("\n".join(f"{k}={v}" if l.startswith(k + "=") else l for l in linhas) + "\n")
PY
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
}

versao_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

carregar_nvm() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  # nvm nao funciona com set -eu; desliga so para ele.
  set +eu
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  set -eu
}
nvm_seguro() { set +eu; nvm "$@"; local r=$?; set -eu; return $r; }

achar_chrome() {
  [ -n "${CHROME_PATH:-}" ] && [ -x "$CHROME_PATH" ] && { echo "$CHROME_PATH"; return; }
  for n in google-chrome-stable google-chrome chromium chromium-browser microsoft-edge brave-browser; do
    command -v "$n" >/dev/null 2>&1 && { command -v "$n"; return; }
  done
}

# ---------------------------------------------------------------- sistema
instalar_sistema() {
  etapa "Pacotes do sistema (apt)"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq git curl ca-certificates ffmpeg python3 python3-venv python3-pip \
    poppler-utils fonts-noto fonts-noto-color-emoji >/dev/null
  ok "git, curl, ffmpeg, python3-venv, poppler-utils, fontes"

  if [ -z "$(achar_chrome)" ]; then
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
      local tmp; tmp="$(mktemp -d)"
      curl -fsSL -o "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
      $SUDO apt-get install -y -qq "$tmp/chrome.deb" >/dev/null
      rm -rf "$tmp"
      ok "Google Chrome instalado"
    else
      # No Ubuntu o pacote chromium e um atalho para snap, que nao roda bem no WSL.
      aviso "arquitetura $(dpkg --print-architecture): instale Chromium manualmente e defina CHROME_PATH"
    fi
  else
    ok "navegador ja instalado: $(achar_chrome)"
  fi
}

# ---------------------------------------------------------------- node
instalar_node() {
  etapa "Node.js >= $NODE_MIN (via nvm)"
  carregar_nvm
  if ! command -v nvm >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash >/dev/null
    carregar_nvm
  fi
  nvm_seguro install "$NODE_VERSAO" >/dev/null
  nvm_seguro alias default "$NODE_VERSAO" >/dev/null
  nvm_seguro use default >/dev/null
  ok "node $(node -v) definido como padrao"
}

# ---------------------------------------------------------------- claude cli
instalar_claude() {
  etapa "Claude Code CLI (pesquisa e roteiro via claude -p)"
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v claude >/dev/null 2>&1; then
    curl -fsSL https://claude.ai/install.sh | bash >/dev/null
  fi
  if command -v claude >/dev/null 2>&1; then
    ok "claude $(claude --version 2>/dev/null | head -1)"
    echo "        Se ainda nao fez login: rode 'claude' uma vez no terminal."
  else
    aviso "nao consegui instalar o claude; veja https://docs.claude.com/claude-code"
  fi
}

# ---------------------------------------------------------------- vendor
instalar_vendor() {
  etapa "Repositorios de terceiros (vendor.lock.json)"
  mkdir -p "$RAIZ/vendor"
  python3 -c '
import json, sys
for r in json.load(open(sys.argv[1]))["repos"]:
    print(r["nome"], r["origem"], r["commit"])
' "$RAIZ/vendor.lock.json" | while read -r nome origem commit; do
    local dir="$RAIZ/vendor/$nome"
    if [ ! -d "$dir/.git" ]; then
      git clone -q "$origem" "$dir"
    elif ! git -C "$dir" cat-file -e "$commit^{commit}" 2>/dev/null; then
      git -C "$dir" fetch -q origin
    fi
    git -C "$dir" -c advice.detachedHead=false checkout -q "$commit"
    ok "$nome @ $(git -C "$dir" rev-parse --short=7 HEAD)"
  done
}

# ---------------------------------------------------------------- python
instalar_python() {
  etapa "Ambiente Python (.venv)"
  [ -d "$RAIZ/.venv" ] || python3 -m venv "$RAIZ/.venv"
  "$RAIZ/.venv/bin/pip" install -q --upgrade pip
  if [ -f "$RAIZ/requirements.txt" ]; then
    "$RAIZ/.venv/bin/pip" install -q -r "$RAIZ/requirements.txt"
    ok "requirements.txt instalado"
  else
    aviso "requirements.txt ainda nao existe (o agente-construtor cria na etapa 1); rode este script de novo depois"
  fi
}

# ---------------------------------------------------------------- pastas e .env
preparar_pastas() {
  etapa "Pastas e configuracao"
  mkdir -p "$SAIDAS" "$RAIZ/cache" "$RAIZ/config"
  ok "saidas: $SAIDAS"
  if [ ! -f "$ENV_FILE" ]; then
    cp "$RAIZ/config/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    ok "config/.env criado a partir do .env.example (preencha as chaves)"
  else
    ok "config/.env ja existe (nao foi alterado)"
  fi
}

# ---------------------------------------------------------------- voicestudio
subir_voicestudio() {
  etapa "VoiceStudio local (Docker, commit do lock)"
  if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    falha "Docker nao disponivel nesta distro."
    if eh_wsl; then
      echo "        No Docker Desktop do Windows: Settings > Resources > WSL integration > ligar esta distro."
    else
      echo "        Instale o Docker Engine: https://docs.docker.com/engine/install/"
    fi
    echo "        Depois rode: ./instalar.sh --sem-sistema"
    return 0
  fi

  local commit imagem
  commit="$(python3 -c 'import json,sys;print([r["commit"] for r in json.load(open(sys.argv[1]))["repos"] if r["nome"]=="voicestudio"][0])' "$RAIZ/vendor.lock.json")"
  imagem="ghcr.io/debpalash/voicestudio:sha-$commit"

  if [ -z "$(env_get OMNIVOICE_API_KEY)" ]; then
    env_set OMNIVOICE_API_KEY "$(python3 -c 'import secrets;print(secrets.token_urlsafe(32))')"
    ok "OMNIVOICE_API_KEY gerada e gravada em config/.env"
  fi

  if docker ps -a --format '{{.Names}}' | grep -qx "$VS_CONTAINER"; then
    docker start "$VS_CONTAINER" >/dev/null
    ok "container $VS_CONTAINER iniciado"
  else
    docker pull -q "$imagem" >/dev/null
    local gpu_args=(); [ "$GPU" -eq 1 ] && gpu_args=(--gpus all)
    OMNIVOICE_API_KEY="$(env_get OMNIVOICE_API_KEY)" docker run -d --name "$VS_CONTAINER" \
      "${gpu_args[@]}" \
      -p "127.0.0.1:$VS_PORTA:3900" \
      -e OMNIVOICE_API_KEY \
      -e OMNIVOICE_ANALYTICS_DISABLED=1 \
      -v "$VS_VOLUME:/app/omnivoice_data" \
      --restart unless-stopped \
      "$imagem" >/dev/null
    ok "container $VS_CONTAINER criado ($imagem)"
  fi

  printf '        aguardando /health'
  for _ in $(seq 1 60); do
    if [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$VS_PORTA/health")" = "200" ]; then
      echo; ok "VoiceStudio pronto em http://localhost:$VS_PORTA"; return 0
    fi
    printf '.'; sleep 5
  done
  echo; aviso "VoiceStudio ainda subindo (primeira vez baixa ~2,4 GB de modelos). Acompanhe: docker logs -f $VS_CONTAINER"
}

# ---------------------------------------------------------------- verificacao
verificar() {
  etapa "Verificacao do ambiente"
  local erros=0
  carregar_nvm
  if command -v node >/dev/null 2>&1 && versao_ge "$(node -v | tr -d v)" "$NODE_MIN"; then ok "node $(node -v)"
  else falha "node >= $NODE_MIN (atual: $(node -v 2>/dev/null || echo nenhum))"; erros=$((erros+1)); fi

  for b in ffmpeg ffprobe git; do
    if command -v "$b" >/dev/null 2>&1; then ok "$b"; else falha "$b"; erros=$((erros+1)); fi
  done

  local py; py="$(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])')"
  if versao_ge "$py" "3.11"; then ok "python $py"; else falha "python >= 3.11 (atual $py)"; erros=$((erros+1)); fi
  if [ -x "$RAIZ/.venv/bin/python" ]; then ok ".venv"; else falha ".venv"; erros=$((erros+1)); fi

  local c; c="$(achar_chrome || true)"
  if [ -n "$c" ]; then ok "navegador $c"; else falha "Chrome/Chromium (ou defina CHROME_PATH)"; erros=$((erros+1)); fi

  python3 -c '
import json, sys
for r in json.load(open(sys.argv[1]))["repos"]:
    print(r["nome"], r["commit"])
' "$RAIZ/vendor.lock.json" | while read -r nome commit; do
    local dir="$RAIZ/vendor/$nome"
    if [ -d "$dir/.git" ] && [[ "$(git -C "$dir" rev-parse HEAD)" == "$commit"* ]]; then ok "vendor/$nome @ $commit"
    else falha "vendor/$nome no commit $commit"; fi
  done

  export PATH="$HOME/.local/bin:$PATH"
  if command -v claude >/dev/null 2>&1; then ok "claude CLI $(claude --version 2>/dev/null | head -1)"
  else falha "claude CLI (rode ./instalar.sh)"; erros=$((erros+1)); fi

  if [ -f "$ENV_FILE" ]; then
    ok "config/.env"
    local ativas=""
    for k in PEXELS_API_KEY PIXABAY_API_KEY UNSPLASH_ACCESS_KEY EUROPEANA_API_KEY SMITHSONIAN_API_KEY; do
      v="$(env_get "$k" | sed 's/[[:space:]]*#.*//')"
      [ -n "$v" ] && ativas="$ativas ${k%%_*}"
    done
    ok "midia sem chave: Wikimedia, NASA, Openverse, Internet Archive, LoC, Met, AIC, Cleveland"
    [ -n "$ativas" ] && ok "midia com chave:$ativas" || aviso "nenhuma fonte com chave (opcional: Pexels, Pixabay...)"
  else
    falha "config/.env"; erros=$((erros+1))
  fi

  local h; h="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$VS_PORTA/health" || true)"
  case "$h" in
    200) ok "VoiceStudio respondendo em :$VS_PORTA" ;;
    503) aviso "VoiceStudio iniciando (503)" ;;
    *)   aviso "VoiceStudio fora do ar em :$VS_PORTA" ;;
  esac

  echo
  if [ "$erros" -eq 0 ]; then echo "Ambiente pronto para o agente-construtor."
  else echo "$erros item(ns) faltando. Rode ./instalar.sh (sem --verificar)."; fi
  return 0
}

# ---------------------------------------------------------------- main
cd "$RAIZ"
if [ "$SO_VERIFICAR" -eq 1 ]; then verificar; exit 0; fi
[ "$SEM_SISTEMA" -eq 1 ] || instalar_sistema
instalar_node
instalar_claude
instalar_vendor
preparar_pastas
instalar_python
[ "$SEM_VS" -eq 1 ] || subir_voicestudio
verificar
