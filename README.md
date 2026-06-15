# research-agent

这是一个 OpenClaw AI agent gateway 的配置仓库。本文档面向第一次接触本仓库的同学，重点说明如何在本地用 Docker 跑 benchmark、如何配置本地环境变量，以及如何在 fork 出来的 GitHub 仓库里配置 CI 所需的 secrets。

## 你需要先准备什么

1. **Git**：用于克隆仓库、提交代码。
2. **Docker Desktop**：推荐本地 benchmark 使用 Docker。
   - macOS：安装并打开 Docker Desktop，等菜单栏 Docker 图标显示为运行中。
   - Linux：确保 `docker` 命令可用，并且当前用户有权限运行 Docker。
3. **Python 3.11+**：benchmark 的 `metrics.py` 会用到 Python。
4. **LLM API Key**：本地和 CI benchmark 都需要 `LLM_API_KEY`。

检查 Docker 是否已经启动：

```bash
docker ps
```

如果这条命令报错，通常说明 Docker Desktop 还没打开，或者 Docker daemon 没有启动。

## 本地配置 benchmark 环境变量

本地 benchmark 不要把 API Key 写进仓库文件。请复制模板文件：

```bash
cp docker/.env.bench.example docker/.env.bench
```

然后编辑 `docker/.env.bench`：

```bash
LLM_API_KEY=你的_api_key
LLM_BASE_URL=https://api.minimaxi.com/anthropic
LLM_MODEL=minimax/MiniMax-M2.7
```

字段说明：

| 变量 | 必填 | 说明 |
| --- | --- | --- |
| `LLM_API_KEY` | 是 | LLM provider 的 API Key。本地 benchmark 没有它会直接失败。 |
| `LLM_BASE_URL` | 否 | LLM provider 的 Anthropic-compatible API 地址；默认是 `https://api.minimaxi.com/anthropic`。 |
| `LLM_MODEL` | 否 | benchmark 使用的模型；默认是 `minimax/MiniMax-M2.7`。 |

也可以不写 `docker/.env.bench`，直接在命令行临时传入：

```bash
benchmarks/_common/run_local_benchmark.sh \
  --api-key "你的_api_key" \
  --base-url "https://api.minimaxi.com/anthropic" \
  --model "minimax/MiniMax-M2.7" \
  idea-generate-1
```

优先级从高到低是：

1. `run_local_benchmark.sh` 的 `--api-key` / `--base-url` / `--model` 参数；
2. `docker/.env.bench`；
3. 当前 shell 环境变量 `LLM_API_KEY` / `LLM_BASE_URL` / `LLM_MODEL`。

## 如何本地启动 Docker 并运行 benchmark

推荐使用统一脚本运行单个 benchmark：

```bash
benchmarks/_common/run_local_benchmark.sh idea-generate-1
```

脚本会自动做这些事：

1. 读取 `docker/.env.bench` 里的环境变量；
2. 选择容器运行时，默认优先 Docker；
3. 启动 OpenClaw benchmark 容器；
4. 等待 `openclaw health` 就绪；
5. 运行目标 benchmark 的 `env.sh` 写入 fixture；
6. 运行目标 benchmark 的 `metrics.py`；
7. 输出 benchmark report 路径。

常用命令：

```bash
# 跑一个 benchmark
benchmarks/_common/run_local_benchmark.sh idea-generate-1

# 明确指定 Docker，不使用自动探测
benchmarks/_common/run_local_benchmark.sh --runtime docker idea-generate-1

# 保留容器，方便排查失败原因
benchmarks/_common/run_local_benchmark.sh --keep-container idea-generate-1

# 打开 debug artifact
benchmarks/_common/run_local_benchmark.sh --debug idea-generate-1
```

运行成功后，通常会看到类似输出：

```text
[local-bench] report: /path/to/benchmarks/idea-generate-1/bench-report.json
[local-bench] summary: /path/to/bench-results/idea-generate-1.json
```

如果你想手动执行与 CI 等价的步骤，可以运行：

```bash
bash benchmarks/_common/env_setup.sh
bash benchmarks/idea-generate-1/env.sh
python3 benchmarks/idea-generate-1/metrics.py
```

除非正在调试 benchmark 基础设施，否则优先使用 `run_local_benchmark.sh`。

## 如何在 forked repo 中配置 GitHub Secrets 跑 CI

如果你 fork 了本仓库，并希望在自己的 fork 上打开 PR 前先跑 benchmark CI，需要在 fork 仓库里配置 GitHub Actions secrets。

步骤：

1. 打开你的 fork 仓库页面，例如 `https://github.com/<你的用户名>/research-agent`。
2. 进入 **Settings**。
3. 左侧进入 **Secrets and variables** → **Actions**。
4. 点击 **New repository secret**。
5. 添加下面这些 secret。

| Secret | 必填 | 示例 / 默认值 | 用途 |
| --- | --- | --- | --- |
| `LLM_API_KEY` | 是 | 你的 LLM API Key | main agent 和 LLM judge 都会用它。未配置时 workflow 会 fail-fast。 |
| `LLM_BASE_URL` | 否 | `https://api.minimaxi.com/anthropic` | LLM provider API 地址。不填则使用 CI 默认值。 |
| `LLM_MODEL` | 否 | `minimax/MiniMax-M2.7` | benchmark 使用的模型。不填则使用 CI 默认值。 |
| `BENCH_BASE_RESULTS_JSON` | 否 | 上次 main 跑出的 summary 的 base64 字符串 | 用于 PR 评论展示 delta；没有也可以跑 benchmark。 |

配置完成后，进入 fork 仓库的 **Actions** 页面，确认 workflow 没有被禁用。然后：

1. 从 fork 创建或更新一个 PR；
2. 等待 `Benchmark` workflow 跑完；
3. 确认所有 benchmark job 通过；
4. 再向上游仓库开 PR 或请求合并。

> 注意：不要把 API Key 写进代码、README、issue、PR 描述或日志。只放在 `docker/.env.bench`（本地，gitignored）或 GitHub Actions secrets 里。

## PR 前必须完成的检查

开 PR 前必须满足：

1. 已经在本地运行相关 benchmark，且结果通过；
2. 已经在 forked repo 跑过 GitHub Actions benchmark CI，且结果通过；
3. PR 描述或 PR 评论中贴出 benchmark 结果摘要；
4. 如果改动涉及 skill、agent、workflow 或配置，必须实际触发 OpenClaw 端到端验证。

如果本地测试没跑，或者 forked repo 的 CI 没通过，不要向上游仓库开 PR。
