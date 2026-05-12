# Docker Compose 기반 AI 추론 서버 설정 (Windows/Linux)

이 가이드는 NVIDIA GPU가 장착된 Windows(WSL2) 및 Linux 환경에서 로컬 AI 추론 서버(Ollama/vLLM)를 띄우기 위한 설정입니다.

## 사전 요구사항

1. [Docker Desktop (Windows)](https://docs.docker.com/desktop/install/windows-install/) 또는 Docker Engine (Linux)
2. [NVIDIA GPU Drivers](https://www.nvidia.com/download/index.aspx)
3. (Linux의 경우) [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

> **Note**: Windows에서 Docker Desktop을 사용하는 경우, 최신 버전에 NVIDIA Container Toolkit이 내장되어 있어 별도 설치가 필요하지 않습니다. 단, WSL2 백엔드가 활성화되어 있어야 합니다.

## 실행 방법

1. Ollama 컨테이너 실행 (백그라운드):
   ```bash
   docker compose up -d ollama
   ```

2. (옵션) vLLM 컨테이너 실행:
   - `docker-compose.yml` 파일에서 `vllm` 서비스의 주석을 해제합니다.
   - 실행:
     ```bash
     docker compose up -d vllm
     ```

## 포트 정보
- **Ollama**: `http://localhost:11434`
- **vLLM**: `http://localhost:8000` (OpenAI API 호환)

## bridge.conf 연동 가이드
이 환경을 구동하는 호스트 컴퓨터에서 AI 작업을 수행하는 외부 서버(예: Ubuntu 랩탑 등)로 역방향 SSH 터널을 생성하려면:

1. `ai-bridge/bridge/bridge.conf` 파일을 수동으로 생성하거나 편집합니다.
2. `OLLAMA_LOCAL_PORT` 값을 `11434` (Ollama) 또는 `8000` (vLLM)으로 맞춥니다.
