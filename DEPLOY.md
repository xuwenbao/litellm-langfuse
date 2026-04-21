# LiteLLM + Langfuse 部署说明

本目录通过 Docker Compose 启动 **Langfuse v3** 与 **LiteLLM 代理**。镜像前缀见 `docker-compose.yml`（如 `docker.1ms.run/...`）；上游大模型地址与模型名以 `litellm_config.yaml` 为准（示例：`http://10.13.31.106:19527/v1`、`XiYanSQL-QwenCoder-32B-2504`）。若本机执行 `docker` 报权限错误，见下文「Docker 权限」。

---

## 镜像加速（1ms）

参考 [1ms.run](https://1ms.run/)：

- **Docker Hub**：将 `docker.io/...` 换为 `docker.1ms.run/...`。
- **GHCR**：将 `ghcr.io/...` 换为 `ghcr.1ms.run/...`（例如 LiteLLM：`ghcr.1ms.run/berriai/litellm:main-stable`）。

实际使用的镜像名以仓库内 `docker-compose.yml` 为准；引用镜像加速服务时请遵守 1ms 使用说明与署名要求。

---

## 上游模型（LiteLLM）

- **API Base**：`http://10.13.31.106:19527/v1`（与 `litellm_config.yaml` 中配置一致）。
- **模型名**：`XiYanSQL-QwenCoder-32B-2504`。

运行 Compose 的机器必须能访问 `10.13.31.106:19527`。若上游需要 API Key，在 `litellm.env` 中设置 `UPSTREAM_OPENAI_API_KEY`。

---

## Langfuse 与 LiteLLM 联动

- `litellm_config.yaml` 中 `success_callback` / `failure_callback` 含 `langfuse`，用于把调用记录写入 Langfuse。
- LiteLLM 从 `litellm.env` 读取 `LANGFUSE_PUBLIC_KEY`、`LANGFUSE_SECRET_KEY`；`LANGFUSE_HOST` 在 `docker-compose.yml` 中指向 `http://langfuse-web:3000`。
- 首次启动：`.env` 中 `LANGFUSE_INIT_PROJECT_*` 用于种子组织/项目；`litellm.env` 里的项目公钥、私钥须与 `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`、`LANGFUSE_INIT_PROJECT_SECRET_KEY` 一致。

---

## 启动步骤

```bash
cd litellm-langfuse
cp -n .env.example .env
cp -n litellm.env.example litellm.env
# 生产环境请修改 .env、litellm.env 中的密钥与连接信息
docker compose up -d
```

---

## Docker 权限

若出现连接 `/var/run/docker.sock` **permission denied**：

1. 将当前用户加入 `docker` 组并重新登录：`sudo usermod -aG docker "$USER"`  
2. 或临时使用：`sudo docker compose up -d`（需本机 sudo 密码）

---

## 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| Langfuse 控制台 | <http://localhost:3000> | 初始账号见 `.env` 中 `LANGFUSE_INIT_USER_*` |
| LiteLLM API | <http://localhost:4000> | 请求头 `Authorization: Bearer <LITELLM_MASTER_KEY>`，密钥来自 `litellm.env` |

---

## 相关文件

| 文件 | 作用 |
|------|------|
| `docker-compose.yml` | Langfuse 全栈 + LiteLLM 服务定义 |
| `litellm_config.yaml` | 路由、Langfuse 回调、主密钥引用等 |
| `.env.example` | Langfuse / 数据库 / Redis / MinIO 等示例环境变量 |
| `litellm.env.example` | LiteLLM 与 Langfuse API 密钥示例（复制为 `litellm.env`） |

---

## 调用示例（curl）

```bash
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"XiYanSQL-QwenCoder-32B-2504","messages":[{"role":"user","content":"hi"}]}'
```

将 `<LITELLM_MASTER_KEY>` 替换为 `litellm.env` 中的实际值。
