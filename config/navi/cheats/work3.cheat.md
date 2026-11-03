```sh
;--------------------------------------------------------------
; alembic (docker compose)
;--------------------------------------------------------------
% work3, alembic

# alembic : downgrade to selected revision (fzf)
docker compose run --rm <service> alembic downgrade <revision>

# alembic : downgrade all (base)
docker compose run --rm <service> alembic downgrade base
```

$ service: { echo app; docker compose config --services; } | awk '!seen[$0]++'
$ revision: docker compose run --rm -T <service> alembic history \
  --- --fzf-overrides '--reverse' --map "sed -E 's/^([^, ]+(, [^, ]+)*) -> ([^ ,]+).*/\3/'"
;$
