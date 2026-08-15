#!/usr/bin/env bash
set -euo pipefail

language="${1:?usage: lint-ai.sh <go|python|typescript> [files ...]}"
shift

# Lefthook supplies staged paths. Drop deleted files before passing them to tools.
files=()
for file in "$@"; do
	[[ -f "$file" ]] && files+=("$file")
done

config_home="${XDG_CONFIG_HOME:-$HOME/.config}/devcontainer/lint"

case "$language" in
go)
	[[ -f go.mod ]] || exit 0
	golangci-lint run --config "$config_home/golangci.yml" ./...
	go test ./...
	go vet ./...
	go build ./...
	;;
python)
	((${#files[@]})) || exit 0
	uvx ruff check --config "$config_home/ruff.toml" "${files[@]}"
	uvx ruff format --check --config "$config_home/ruff.toml" "${files[@]}"
	;;
typescript)
	((${#files[@]})) || exit 0
	oxlint --config "$config_home/oxlint.json" "${files[@]}"
	oxfmt --check --config "$config_home/oxfmt.json" "${files[@]}"
	if [[ -f tsconfig.json ]]; then
		tsgo --noEmit --pretty false --strict --noUncheckedIndexedAccess \
			--exactOptionalPropertyTypes --noImplicitReturns \
			--noFallthroughCasesInSwitch --noImplicitOverride -p tsconfig.json
	fi
	;;
*)
	printf 'lint-ai.sh: unsupported language: %s\n' "$language" >&2
	exit 2
	;;
esac
