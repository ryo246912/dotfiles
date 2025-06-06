#! /usr/bin/env python3

# /// script
# requires-python = ">=3.8"
# dependencies = [
#  "tiktoken",
# ]
# ///

import os

import tiktoken


def count_tokens_in_directory(
    directory_path, model_name="gpt-4o", exclude_dirs=None, include_extensions=None
):
    """
    指定されたディレクトリ内のファイルのトークン数を計算します。
    """
    if exclude_dirs is None:
        exclude_dirs = [
            ".git",
        ]

        # javascript
        exclude_dirs += [
            "__pycache__",
            "node_modules",
            "build",
            "dist",
        ]

        # python
        exclude_dirs += [
            "venv",
            ".venv",
            ".mypy_cache",
            ".pytest_cache",
            ".tox",
            ".coverage",
            "coverage_html_report",
            "htmlcov",
            "docs",
        ]
    if include_extensions is None:
        # 一般的なコードやドキュメントの拡張子
        include_extensions = [
            ".py",
            ".js",
            ".ts",
            ".java",
            ".go",
            ".rs",
            ".cs",
            ".php",
            ".cpp",
            ".h",
            ".c",
            ".html",
            ".css",
            ".scss",
            ".yaml",
            ".yml",
            ".xml",
            ".md",
            ".txt",
            ".vue",
            ".svelte",
            ".jsx",
            ".tsx",
            ".sh",
        ]

    enc = tiktoken.encoding_for_model(model_name)
    total_tokens = 0
    file_count = 0
    excluded_files_count = 0

    for root, dirs, files in os.walk(directory_path):
        # 除外ディレクトリの処理
        dirs[:] = [d for d in dirs if d not in exclude_dirs]

        for file_name in files:
            file_path = os.path.join(root, file_name)

            # 許可された拡張子のみを処理
            if any(file_name.endswith(ext) for ext in include_extensions):
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        content = f.read()
                        tokens = enc.encode(content)
                        total_tokens += len(tokens)
                        file_count += 1
                except UnicodeDecodeError:
                    print(
                        f"警告: UTF-8でデコードできないファイル: {file_path} (スキップ)"
                    )
                    excluded_files_count += 1
                except Exception as e:
                    print(
                        f"エラー: {file_path} の処理中にエラーが発生しました: {e} (スキップ)"
                    )
                    excluded_files_count += 1
            else:
                excluded_files_count += 1

    print(f"処理されたファイル数: {file_count}")
    print(
        f"スキップされたファイル数 (非テキストまたは許可されていない拡張子): {excluded_files_count}"
    )
    return total_tokens


if __name__ == "__main__":
    repo_path = "."  # 現在のディレクトリ（リポジトリのルート）を指定
    model_to_use = "gpt-4o"

    print(f"'{repo_path}' リポジトリのトークン数を '{model_to_use}' モデルで計算中...")
    tokens = count_tokens_in_directory(repo_path, model_name=model_to_use)
    print(f"リポジトリ全体の合計トークン数 ({model_to_use}): {tokens}")
