#!/usr/bin/env bash
# ai-bridge global installer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
AI_BRIDGE_BIN="${PROJECT_ROOT}/ai-bridge"
TARGET_DIR="/usr/local/bin"
TARGET_LINK="${TARGET_DIR}/ai-bridge"

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${BOLD}AI-Bridge Global CLI Installer${RESET}"

if [[ ! -x "${AI_BRIDGE_BIN}" ]]; then
    echo -e "${YELLOW}Making ai-bridge executable...${RESET}"
    chmod +x "${AI_BRIDGE_BIN}"
fi

# Check if we have write permission to /usr/local/bin
if [[ ! -w "${TARGET_DIR}" ]]; then
    echo -e "${YELLOW}Need sudo privileges to create symlink in ${TARGET_DIR}${RESET}"
    sudo ln -sf "${AI_BRIDGE_BIN}" "${TARGET_LINK}"
else
    ln -sf "${AI_BRIDGE_BIN}" "${TARGET_LINK}"
fi

if [[ -L "${TARGET_LINK}" ]]; then
    echo -e "${GREEN}✔ Successfully installed! You can now run '${BOLD}ai-bridge${RESET}${GREEN}' from anywhere.${RESET}"
else
    echo -e "${RED}✖ Failed to create symlink.${RESET}"
    exit 1
fi
