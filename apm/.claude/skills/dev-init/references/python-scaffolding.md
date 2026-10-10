# Python スキャフォールディングガイド

## CLI ツール

| FW | コマンド | 備考 |
|----|---------|------|
| 汎用 | `uv init <name>` | pyproject.toml + src レイアウト生成 |
| Django | `uv run django-admin startproject <name>` | Django の標準スキャフォールド |
| FastAPI | なし | 直接生成 |
| Flask | なし | 直接生成 |

### 環境構築手順

```
uv init <project-name>
cd <project-name>
uv add <dependencies>
uv sync
```

`uv` がない環境のフォールバック: `python -m venv .venv && source .venv/bin/activate && pip install -e ".[dev]"`

## パッケージ定義

### 必須依存パッケージ

| タイプ | FW | dependencies | dev-dependencies |
|--------|-----|-------------|-----------------|
| Web | Django | `django` | `pytest pytest-django ruff` |
| API | FastAPI | `fastapi uvicorn[standard]` | `pytest httpx ruff` |
| API | Flask | `flask` | `pytest ruff` |
| CLI | Typer | `typer` | `pytest ruff` |
| ライブラリ | — | — | `pytest ruff` |

### pyproject.toml 重要フィールド

- `project.requires-python`: `">=3.12"`
- `project.scripts`: CLI エントリポイント
- `build-system`: `hatchling` / `setuptools`
- `tool.uv.dev-dependencies`: 開発用依存

## 設定ファイル

### pyproject.toml（ツール設定統合）

- `tool.ruff.line-length`: `88`（デフォルト）/ `120`（チーム規模大）
- `tool.ruff.lint.select`: `["E", "F", "I", "UP"]`（推奨最小セット）
- `tool.ruff.format.quote-style`: `"double"`
- `tool.pytest.ini_options.testpaths`: `["tests"]`
- `tool.pytest.ini_options.addopts`: `"-v --tb=short"`

### チーム規模別 ruff 設定

- 個人: `select = ["E", "F"]`
- 小規模: `select = ["E", "F", "I", "UP", "B"]`
- 大規模: `select = ["E", "F", "I", "UP", "B", "SIM", "RUF"]` + `lint.isort.known-first-party`

## エントリポイント

| タイプ | パス | 内容 |
|--------|------|------|
| API (FastAPI) | `src/app/main.py` | FastAPI app 作成・ルーター登録 |
| API (Django) | `<name>/wsgi.py` | WSGI アプリケーション |
| CLI (Typer) | `src/<name>/cli.py` | Typer app 定義・コマンド登録 |
| ライブラリ | `src/<name>/__init__.py` | パブリック API |

## テスト雛形

- ファイル配置: `tests/test_<module>.py`
- FastAPI: `httpx.AsyncClient` + `app` で非同期テスト
- Django: `django.test.TestCase` or `pytest-django`
- 最小構成: インポート確認テスト + ヘルスチェックテスト（API の場合）

## Docker ガイド

- ベースイメージ: `python:3.12-slim`
- マルチステージ: `builder`（uv + 依存インストール）→ `runner`（コピー）
- uv in Docker: `COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv`
- `.dockerignore`: `.venv`, `__pycache__`, `.git`, `.env*`, `*.pyc`

### 開発用 Docker

- 開発用ベースイメージ: `python:3.12-slim` + uv
- Volume mount: `- .:/app` でソースコードをマウント
- Hot-reload: `uv run uvicorn --reload`（FastAPI）/ `uv run python manage.py runserver`（Django）で自動再起動
- Dockerfile.dev: マルチステージ不要、uv インストール + 依存 sync + dev server コマンド

## CI (GitHub Actions) ガイド

- Python セットアップ: `actions/setup-python@v5` + `python-version: '3.12'`
- uv セットアップ: `astral-sh/setup-uv@v3`
- キャッシュ: uv が自動キャッシュ管理
- ステップ: `uv sync` → `uv run ruff check` → `uv run ruff format --check` → `uv run pytest`

## 検証コマンド

| 操作 | コマンド |
|------|---------|
| 依存インストール | `uv sync` |
| テスト | `uv run pytest` |
| Lint | `uv run ruff check .` |
| フォーマット確認 | `uv run ruff format --check .` |
| 開発サーバー (FastAPI) | `uv run uvicorn app.main:app --reload` |
| 開発サーバー (Django) | `uv run python manage.py runserver` |
