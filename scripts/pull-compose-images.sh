#!/usr/bin/env bash
# 按 docker compose 服务逐个拉取镜像。
# 每个服务：先尝试 1 次，失败则最多再重试 MAX_RETRIES 次（默认 10，即最多 11 次拉取）。
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

MAX_RETRIES="${MAX_RETRIES:-10}"
# 每次失败后的等待秒数，随已重试次数递增（封顶 60s）
BASE_SLEEP="${BASE_SLEEP:-3}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker 未找到，请先安装并配置 Docker CLI。" >&2
  exit 1
fi

services=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  [[ -n "${line}" ]] || continue
  services+=("${line}")
done < <(docker compose config --services 2>/dev/null | sort -u)

if [[ ${#services[@]} -eq 0 ]]; then
  echo "未能解析 compose 服务列表，请在包含 docker-compose.yml 的目录运行。" >&2
  exit 1
fi

failed=0
for svc in "${services[@]}"; do
  echo "==> 拉取服务镜像: ${svc}"
  ok=0
  retry=0
  while true; do
    if docker compose pull "$svc"; then
      ok=1
      break
    fi
    if (( retry >= MAX_RETRIES )); then
      echo "!! 服务 ${svc} 在 1 次初始拉取 + ${MAX_RETRIES} 次重试后仍失败" >&2
      failed=1
      break
    fi
    retry=$((retry + 1))
    wait=$((BASE_SLEEP * retry))
    (( wait > 60 )) && wait=60
    echo "-- ${svc} 失败，${wait}s 后进行第 ${retry}/${MAX_RETRIES} 次重试..."
    sleep "$wait"
  done
  if (( ok )); then
    echo "    ${svc} 完成（初始 + 重试共尝试 $((retry + 1)) 次）"
  fi
done

if (( failed )); then
  exit 1
fi
echo "全部服务镜像已拉取完成。"
