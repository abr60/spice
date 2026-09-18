# Local AI tools

## Aider

Aider is installed as an isolated `uv` tool using Python 3.13:

```bash
mise exec python@3.13 -- uv tool install --force --python 3.13 \
  --with audioop-lts aider-chat
```

Use it from a Git repository:

```bash
aider --model ollama/qwen2.5-coder:3b --no-auto-commits
```

Use `qwen2.5-coder:7b` for slower, deeper coding tasks.

## OpenCode profiles

Keep the existing cloud-capable profile with:

```bash
opencode
```

Use the fully local model profile with:

```bash
opencode-local
```

The local launcher uses `qwen2.5-coder:7b-16k` for planning/build work,
`qwen2.5-coder:3b` for quick exploration, and `qwen2.5vl:3b` for vision.
It leaves the normal `opencode` command and its cloud configuration unchanged.
Use `opencode-local -m ollama/qwen2.5-coder:3b` when you want the fast model
for the whole session.

## Open WebUI

Open WebUI provides a browser interface at `http://localhost:3000` and uses
host networking to reach the Ollama service bound to localhost. This avoids
exposing Ollama beyond localhost.
From this directory, start it with:

```bash
docker compose up -d
```

The Docker daemon must be running and the user must have access to the Docker
socket. The persistent data is stored in `open-webui-data/`.

## Current benchmark

On the i5-1145G7, a short 64-token shell explanation measured approximately:

| Model | Generated tokens/sec | Wall time |
|---|---:|---:|
| `qwen2.5-coder:3b` | 7.8 | 14.0 s |
| `qwen2.5-coder:7b` | 3.9 | 9.1 s |
| `llama3.1:8b` | 3.2 | 65.5 s |

These are single-request measurements, not a guarantee for long-context
editing. Start with the 3B coder for fast tasks and test the 7B coder for
quality-sensitive work.
