if command -v direnv >/dev/null 2>&1; then
	eval "$(direnv hook zsh)"
fi

if command -v fnox >/dev/null 2>&1; then
	# Run after direnv so .envrc can set non-secret flags like FNOX_PROFILE first.
	eval "$(fnox activate zsh)"
fi
