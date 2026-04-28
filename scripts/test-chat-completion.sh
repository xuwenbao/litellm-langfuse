#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
CONFIG_FILE="${LITELLM_CONFIG_FILE:-$ROOT/litellm_config.yaml}"
LITELLM_BASE_URL="${LITELLM_BASE_URL:-http://localhost:4000}"
TEST_MESSAGE="${TEST_MESSAGE:-hi}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "未找到 .env，请先执行：cp -n .env.example .env" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "未找到 litellm_config.yaml，请先执行：cp -n litellm_config.yaml.example litellm_config.yaml" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
  echo ".env 中缺少 LITELLM_MASTER_KEY" >&2
  exit 1
fi

MODEL_NAME="${MODEL_NAME:-$(awk -F': *' '/^[[:space:]]*- model_name:/ {print $2; exit}' "$CONFIG_FILE")}"
if [[ -z "$MODEL_NAME" ]]; then
  echo "未能从 litellm_config.yaml 读取 model_name，也未设置 MODEL_NAME" >&2
  exit 1
fi

echo "请求 LiteLLM: ${LITELLM_BASE_URL}/v1/chat/completions"
echo "模型: ${MODEL_NAME}"

curl -s "${LITELLM_BASE_URL}/v1/chat/completions" \
  -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"${MODEL_NAME}\",\"messages\":[{\"role\":\"user\",\"content\":\"${TEST_MESSAGE}\"}]}"
echo
