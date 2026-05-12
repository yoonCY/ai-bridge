#!/usr/bin/env bash
# ai-bridge: MacBook 초기 설정 스크립트
set -euo pipefail

echo "🌉 ai-bridge MacBook 설정 시작"
echo "================================"

# --- 색상 ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- macOS 확인 ---
[[ "$(uname)" == "Darwin" ]] || err "이 스크립트는 macOS 전용입니다."

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  info "Homebrew 설치 중..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
info "✅ Homebrew 확인"

# --- 백엔드 선택 ---
echo ""
echo "🚀 사용할 로컬 추론 백엔드를 선택하세요:"
echo "  [1] Ollama (기본, 사용 편의성 우수)"
echo "  [2] MLX (Apple Silicon Unified Memory 최적화, mlx-lm)"
printf "선택 [1]: "
read -r BACKEND_CHOICE
BACKEND_CHOICE="${BACKEND_CHOICE:-1}"

if [[ "${BACKEND_CHOICE}" == "1" ]]; then
  # --- Ollama ---
  if ! command -v ollama &>/dev/null; then
    info "Ollama 설치 중..."
    brew install ollama
  fi
  info "✅ Ollama 확인: $(ollama --version 2>/dev/null || echo 'installed')"
elif [[ "${BACKEND_CHOICE}" == "2" ]]; then
  # --- MLX ---
  info "MLX (mlx-lm) 환경 설정 중..."
  if ! command -v python3 &>/dev/null; then
    info "Python3 설치 중..."
    brew install python3
  fi
  MLX_VENV="${HOME}/.ai-bridge/mlx-venv"
  if [[ ! -d "${MLX_VENV}" ]]; then
    python3 -m venv "${MLX_VENV}"
    "${MLX_VENV}/bin/pip" install --upgrade pip
    "${MLX_VENV}/bin/pip" install mlx-lm
    info "✅ MLX 가상 환경 및 mlx-lm 설치 완료: ${MLX_VENV}"
  else
    info "✅ MLX 가상 환경 확인됨: ${MLX_VENV}"
  fi
else
  err "잘못된 선택입니다."
fi

# --- autossh (선택) ---
if ! command -v autossh &>/dev/null; then
  info "autossh 설치 중 (자동 재연결용)..."
  brew install autossh
fi
info "✅ autossh 확인"

# --- SSH 키 생성 ---
SSH_KEY="${HOME}/.ssh/ai-bridge"
if [[ ! -f "${SSH_KEY}" ]]; then
  info "SSH 키 생성 중..."
  ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -C "ai-bridge-$(hostname)"
  info "✅ SSH 키 생성 완료: ${SSH_KEY}"
else
  info "✅ SSH 키 이미 존재: ${SSH_KEY}"
fi

# --- 기존 설정 로드 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIDGE_DIR="$(dirname "${SCRIPT_DIR}")/bridge"
CONF_FILE="${BRIDGE_DIR}/bridge.conf"

if [[ -f "${CONF_FILE}" ]]; then
  info "기존 설정을 발견했습니다. (${CONF_FILE})"
  # shellcheck source=/dev/null
  source "${CONF_FILE}"
fi

# --- 서버 정보 입력 ---
echo ""
echo "📡 원격 Ubuntu 서버 정보를 입력하세요:"
printf "  서버 주소 (IP 또는 hostname) [%s]: " "${BRIDGE_HOST:-}"
read -r INPUT_HOST
BRIDGE_HOST="${INPUT_HOST:-${BRIDGE_HOST:-}}"
printf "  SSH 포트 [%s]: " "${BRIDGE_PORT:-22}"
read -r INPUT_PORT
BRIDGE_PORT="${INPUT_PORT:-${BRIDGE_PORT:-22}}"
printf "  사용자명 [%s]: " "${BRIDGE_USER:-}"
read -r INPUT_USER
BRIDGE_USER="${INPUT_USER:-${BRIDGE_USER:-}}"

# --- bridge.conf 생성 ---

if [[ "${BACKEND_CHOICE}" == "2" ]]; then
  LOCAL_PORT="8080"
  REMOTE_PORT="8080"
else
  LOCAL_PORT="11434"
  REMOTE_PORT="11434"
fi

mkdir -p "${BRIDGE_DIR}"

cat > "${BRIDGE_DIR}/bridge.conf" <<EOF
# ai-bridge 설정 (자동 생성: $(date '+%Y-%m-%d %H:%M'))
BRIDGE_HOST="${BRIDGE_HOST}"
BRIDGE_USER="${BRIDGE_USER}"
BRIDGE_PORT="${BRIDGE_PORT}"
BRIDGE_SSH_KEY="${SSH_KEY}"
OLLAMA_LOCAL_PORT="${LOCAL_PORT}"
OLLAMA_REMOTE_PORT="${REMOTE_PORT}"
RECONNECT_INTERVAL="5"
RECONNECT_MAX_INTERVAL="300"
SERVER_ALIVE_INTERVAL="30"
SERVER_ALIVE_MAX="3"
LOG_DIR="\${HOME}/.ai-bridge/logs"
LOG_LEVEL="INFO"
EXTRA_FORWARDS=""
EOF
info "✅ bridge.conf 생성 완료"

# --- SSH 키 배포 ---
echo ""
info "SSH 키를 서버에 배포합니다..."
echo "  서버 비밀번호를 입력하세요 (이후에는 키 인증만 사용됩니다)"
ssh-copy-id -i "${SSH_KEY}.pub" -p "${BRIDGE_PORT}" "${BRIDGE_USER}@${BRIDGE_HOST}" || {
  warn "SSH 키 배포 실패. 수동으로 배포하세요:"
  echo "  ssh-copy-id -i ${SSH_KEY}.pub -p ${BRIDGE_PORT} ${BRIDGE_USER}@${BRIDGE_HOST}"
}

# --- SSH config 추가 ---
SSH_CONFIG="${HOME}/.ssh/config"
if ! grep -q "Host ai-bridge-dev" "${SSH_CONFIG}" 2>/dev/null; then
  cat >> "${SSH_CONFIG}" <<EOF

# ai-bridge: AI 개발 서버
Host ai-bridge-dev
    HostName ${BRIDGE_HOST}
    User ${BRIDGE_USER}
    Port ${BRIDGE_PORT}
    IdentityFile ${SSH_KEY}
    ForwardAgent yes
EOF
  info "✅ SSH config에 ai-bridge-dev 호스트 추가"
fi

# --- 로그 디렉토리 ---
mkdir -p "${HOME}/.ai-bridge/logs"

# --- 백엔드 시작 및 모델 풀 ---
if [[ "${BACKEND_CHOICE}" == "1" ]]; then
  info "Ollama 서버 시작..."
  ollama serve &>/dev/null &
  sleep 2

  # --- 기본 모델 풀 (선택) ---
  echo ""
  printf "기본 모델(qwen3:8b)을 다운로드할까요? [Y/n]: "
  read -r PULL_MODEL
  if [[ "${PULL_MODEL}" != "n" && "${PULL_MODEL}" != "N" ]]; then
    info "qwen3:8b 모델 다운로드 중..."
    ollama pull qwen3:8b
  fi
elif [[ "${BACKEND_CHOICE}" == "2" ]]; then
  info "MLX 환경 준비 완료"
  echo "  MLX 서버를 실행하려면 별도의 launchd 데몬을 활성화하거나 수동으로 실행해야 합니다."
  echo "  수동 실행 예시:"
  echo "  ~/.ai-bridge/mlx-venv/bin/python -m mlx_lm.server --model mlx-community/Qwen2.5-Coder-7B-Instruct-4bit"
  echo "  (OpenAI 호환 API가 localhost:8080에서 서빙됩니다.)"
fi

# --- 완료 ---
echo ""
echo "================================"
echo "🎉 ai-bridge MacBook 설정 완료!"
echo ""
echo "다음 단계:"
echo "  1. Ubuntu 서버에서 install/mac-native/setup-server.sh 실행"
echo "  2. 터널 시작: ./bridge/tunnel.sh"
echo "  3. 자동 재연결: ./bridge/reconnect.sh"
echo "  4. 상태 확인: ./bridge/healthcheck.sh"
echo "================================"
