#!/usr/bin/env bash
# ai-bridge: Ubuntu 서버 초기 설정
set -euo pipefail

echo "🖥️  ai-bridge Ubuntu 서버 설정 시작"
echo "================================"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[[ "$(uname)" == "Linux" ]] || err "이 스크립트는 Linux 전용입니다."

# --- Docker 확인 ---
if command -v docker &>/dev/null; then
  info "✅ Docker: $(docker --version)"
else
  warn "Docker가 설치되어 있지 않습니다."
  read -rp "Docker를 설치할까요? [Y/n]: " INSTALL_DOCKER
  if [[ "${INSTALL_DOCKER,,}" != "n" ]]; then
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$(whoami)"
    info "✅ Docker 설치 완료. 로그아웃 후 재로그인 필요."
  fi
fi

# --- SSH 설정 강화 ---
SSHD_CONFIG="/etc/ssh/sshd_config"
info "SSH 설정 확인 중..."

# GatewayPorts 확인 (리버스 터널 수신 허용)
if grep -q "^GatewayPorts" "${SSHD_CONFIG}" 2>/dev/null; then
  info "GatewayPorts 설정 이미 존재"
else
  warn "GatewayPorts 설정이 없습니다."
  echo ""
  echo "  리버스 터널이 localhost에만 바인드되도록 (ai-bridge 기본 동작)"
  echo "  외부 접근이 필요하면 /etc/ssh/sshd_config에 다음을 추가하세요:"
  echo "    GatewayPorts clientspecified"
  echo ""
fi

# ClientAliveInterval 확인
if ! grep -q "^ClientAliveInterval" "${SSHD_CONFIG}" 2>/dev/null; then
  warn "ClientAliveInterval 설정 추천:"
  echo "  /etc/ssh/sshd_config에 다음 추가:"
  echo "    ClientAliveInterval 30"
  echo "    ClientAliveCountMax 3"
fi

info "✅ SSH 설정 검토 완료"

# --- Ollama 프록시 테스트 ---
echo ""
info "Ollama 터널 연결 테스트..."
if curl -sf "http://localhost:11434/api/tags" > /dev/null 2>&1; then
  info "✅ Ollama 프록시 정상 (localhost:11434)"
  echo "  사용 가능한 모델:"
  curl -sf "http://localhost:11434/api/tags" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f'    - {m["name"]}')
" 2>/dev/null || echo "    (모델 목록 조회 실패)"
else
  warn "Ollama가 localhost:11434에서 응답하지 않습니다."
  echo "  MacBook에서 터널을 먼저 실행하세요:"
  echo "    ./bridge/tunnel.sh"
fi

# --- 완료 ---
echo ""
echo "================================"
echo "🎉 Ubuntu 서버 설정 완료!"
echo ""
echo "다음 단계:"
echo "  1. MacBook에서 터널 실행: ./bridge/tunnel.sh"
echo "  2. 연결 확인: curl http://localhost:11434/api/tags"
echo "  3. VSCode Remote-SSH로 접속"
echo "================================"
