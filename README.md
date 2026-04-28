# LiteLLM + Langfuse

本项目用于快速搭建一套“OpenAI 兼容接口 + 智能体观测 + 数据收集”环境。

适用场景：

- 对外提供 OpenAI 兼容接口，让智能体、应用或测试脚本统一调用 `http://localhost:4000/v1`。
- 监测智能体提示词、模型请求、响应内容、错误和耗时，方便调试 prompt 与工作流。
- 收集测试数据、训练数据和评测样本，为后续微调、回归测试或效果分析做准备。

项目使用 LiteLLM Proxy 统一转发模型请求，使用 Langfuse 记录请求链路。默认通过 Docker Compose 启动本地完整栈：LiteLLM、Langfuse、Postgres、ClickHouse、Redis、MinIO。

## 新手：先跑起来

只想本地体验，按这几步走。

### 1. 复制配置

```bash
cp -n .env.example .env
cp -n litellm_config.yaml.example litellm_config.yaml
```

### 2. 只改最少内容

打开 `.env`，新手通常只需要改这几个：

```env
# Langfuse 控制台初始管理员密码，登录 http://localhost:3000 时使用。
LANGFUSE_INIT_USER_PASSWORD=changeme_admin_password

# LiteLLM 接口访问密钥，调用 http://localhost:4000/v1/... 时作为 Bearer token。
LITELLM_MASTER_KEY=sk-litellm-change-me

# 上游模型服务 API key；如果上游不需要鉴权，可以先保留 dummy。
UPSTREAM_OPENAI_API_KEY=dummy
```

打开 `litellm_config.yaml`，把模型名和上游地址改成你的 OpenAI 兼容模型服务：

```yaml
model_list:
  - model_name: your-model-name
    litellm_params:
      model: openai/your-model-name
      api_base: https://your-openai-compatible-api.example.com/v1
      api_key: os.environ/UPSTREAM_OPENAI_API_KEY
```

### 3. 启动

```bash
docker compose up -d
```

### 4. 打开页面

- Langfuse 控制台：[http://localhost:3000](http://localhost:3000)
- LiteLLM OpenAI 兼容接口：[http://localhost:4000](http://localhost:4000)

Langfuse 初始账号来自 `.env`：

- 邮箱：`LANGFUSE_INIT_USER_EMAIL`，默认 `admin@example.com`
- 密码：`LANGFUSE_INIT_USER_PASSWORD`，默认 `changeme_admin_password`

### 5. 发一个测试请求

推荐直接使用脚本测试。脚本会读取 `.env` 中的 `LITELLM_MASTER_KEY`，并读取 `litellm_config.yaml` 中第一个 `model_name`。

```bash
bash scripts/test-chat-completion.sh
```

也可以临时覆盖测试内容：

```bash
TEST_MESSAGE="你好" bash scripts/test-chat-completion.sh
MODEL_NAME="your-model-name" bash scripts/test-chat-completion.sh
```

如果想手动 curl，把 `<LITELLM_MASTER_KEY>` 替换为 `.env` 中的值，把 `your-model-name` 替换为 `litellm_config.yaml` 里的 `model_name`。

```bash
curl -s http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"your-model-name","messages":[{"role":"user","content":"hi"}]}'
```

请求成功后，可以在 Langfuse 控制台里查看 trace，用来分析提示词、模型输入输出、错误和耗时。

## 进阶：按场景启动

本项目用 Docker Compose profiles 控制启动哪些服务。profile 写在 `.env` 的 `COMPOSE_PROFILES` 中。

常见组合：

- 本地开发/首次体验：`app,local-postgres,local-clickhouse,local-redis,local-minio`
- 测试环境：`app,local-postgres,local-clickhouse,local-redis,local-minio`
- 生产环境，全部基础设施外置：`app`
- 生产环境，已有 Postgres：`app,local-clickhouse,local-redis,local-minio`
- 生产环境，已有对象存储：`app,local-postgres,local-clickhouse,local-redis`

每个 profile 对应的服务：

- `app`：`litellm`、`langfuse-web`、`langfuse-worker`
- `local-postgres`：本地 Postgres
- `local-clickhouse`：本地 ClickHouse
- `local-redis`：本地 Redis
- `local-minio`：本地 MinIO

### 已有 Postgres

如果你已经有 Postgres，不想启动本地 Postgres，可以这样配置 `.env`：

```env
COMPOSE_PROFILES=app,local-clickhouse,local-redis,local-minio
DATABASE_URL=postgresql://user:password@your-postgres-host:5432/langfuse
LITELLM_DATABASE_URL=postgresql://user:password@your-postgres-host:5432/litellm
```

注意：Langfuse 和 LiteLLM 不要共用同一个数据库或 schema，否则两边的 Prisma 表结构可能互相影响。

### 常用命令

```bash
docker compose config --profiles
docker compose ps
docker compose logs -f litellm
docker compose logs -f langfuse-web
docker compose down
```

临时指定 profile：

```bash
COMPOSE_PROFILES=app docker compose up -d
COMPOSE_PROFILES=app,local-postgres,local-clickhouse,local-redis,local-minio docker compose up -d
```

清理本地数据卷：

```bash
docker compose down -v
```

镜像拉取不稳定时，可以先执行：

```bash
./scripts/pull-compose-images.sh
```

## 高手：生产和运维

生产环境建议至少修改这些值：

- `NEXTAUTH_SECRET`
- `SALT`
- `ENCRYPTION_KEY`
- `LANGFUSE_INIT_USER_PASSWORD`
- `LITELLM_MASTER_KEY`
- `POSTGRES_PASSWORD`
- `CLICKHOUSE_PASSWORD`
- `REDIS_AUTH`
- `MINIO_ROOT_PASSWORD`
- `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`
- `LANGFUSE_INIT_PROJECT_SECRET_KEY`
- `LANGFUSE_PUBLIC_KEY`
- `LANGFUSE_SECRET_KEY`

如果生产环境的 Postgres、ClickHouse、Redis、对象存储都由外部服务提供，只启用应用服务：

```env
COMPOSE_PROFILES=app
DATABASE_URL=postgresql://user:password@your-postgres-host:5432/langfuse
LITELLM_DATABASE_URL=postgresql://user:password@your-postgres-host:5432/litellm
CLICKHOUSE_URL=https://your-clickhouse.example.com
REDIS_HOST=your-redis-host
LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT=https://your-object-storage.example.com
LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT=https://your-object-storage.example.com
LANGFUSE_S3_BATCH_EXPORT_ENDPOINT=https://your-object-storage.example.com
```

`litellm_config.yaml` 不提交到仓库，建议按环境分别维护。可以从 `litellm_config.yaml.example` 复制后修改：

- `model_name`：对调用方暴露的模型名。
- `litellm_params.model`：LiteLLM 识别的上游模型名，OpenAI 兼容服务通常写成 `openai/<model>`。
- `api_base`：上游 OpenAI 兼容接口地址。
- `api_key`：默认从 `.env` 的 `UPSTREAM_OPENAI_API_KEY` 读取。

## 文件说明

- `docker-compose.yml`：定义 LiteLLM、Langfuse 和本地基础设施服务，并配置 profiles。
- `.env.example`：所有环境变量示例，新手复制为 `.env` 后修改。
- `litellm_config.yaml.example`：LiteLLM 路由配置示例，新手复制为 `litellm_config.yaml` 后修改。
- `.gitignore`：忽略真实 `.env`、`litellm_config.yaml` 等本地配置。
- `scripts/pull-compose-images.sh`：按服务拉取镜像并重试，适合网络不稳定时使用。

## 镜像源

Compose 文件默认使用毫秒镜像（1ms mirror）：

- Docker Hub 镜像使用 `docker.1ms.run/...`
- GHCR 镜像可使用 `ghcr.1ms.run/...`

如果拉取失败，可以按 [https://1ms.run/](https://1ms.run/) 的说明调整镜像地址，或切换回官方 registry。

## Docker 权限

如果执行 `docker compose up -d` 时遇到 `/var/run/docker.sock` 的 `permission denied`：

1. 将当前用户加入 `docker` 组后重新登录：`sudo usermod -aG docker "$USER"`
2. 或使用 `sudo docker compose up -d`
