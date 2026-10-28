```sh
;--------------------------------------------------------------
; alembic (docker compose)
;--------------------------------------------------------------
% work3, alembic

# alembic : display current revision [(head):latest]
docker compose run --rm <service> alembic current

# alembic : display head revision
docker compose run --rm <service> alembic heads

# alembic : display history [-i:indicate current][-v:verbose]
docker compose run --rm <service> alembic history -i -v

# alembic : create migration [--autogenerate:detect model diff]
docker compose run --rm <service> alembic revision --autogenerate -m "<message>"

# alembic : upgrade to head
docker compose run --rm <service> alembic upgrade head

# alembic : downgrade to selected revision (fzf)
docker compose run --rm <service> alembic downgrade <revision>

# alembic : downgrade all (base)
docker compose run --rm <service> alembic downgrade base

# alembic : recreate dev db [down -v:remove volume = all existing data is lost] (dev only)
docker compose down -v && docker compose up -d <db_service> && docker compose run --rm <service> alembic upgrade head
```

$ service: { echo app; docker compose config --services; } | awk '!seen[$0]++'
$ db_service: docker compose config --services
$ revision: docker compose run --rm -T <service> alembic history \
  --- --fzf-overrides '--reverse' --map "sed -E 's/^([^ ]+) -> ([^ ,]+).*/\2/'"
;$
