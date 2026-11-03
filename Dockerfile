# syntax=docker/dockerfile:1
# Two stages:
#   verify  - starts a throwaway PostgreSQL inside the build, loads sql/ and
#             runs tests/. A failing test fails the image build.
#   runtime - the official image with the starter schema in
#             /docker-entrypoint-initdb.d, so a fresh volume is seeded on first start.

# ---- verify -----------------------------------------------------------------
FROM postgres:18-alpine AS verify
RUN apk add --no-cache bash
WORKDIR /work
COPY sql/ sql/
COPY tests/ tests/
COPY scripts/ scripts/
RUN chown -R postgres:postgres /work
USER postgres
RUN initdb --pgdata=/tmp/verify --auth=trust --username=postgres >/dev/null \
 && pg_ctl --pgdata=/tmp/verify --options="-c listen_addresses=''" --wait --silent start \
 && PGHOST=/var/run/postgresql PGUSER=postgres bash scripts/run-tests.sh \
 && pg_ctl --pgdata=/tmp/verify --wait --silent stop

# ---- runtime ----------------------------------------------------------------
FROM postgres:18-alpine AS runtime
COPY --from=verify --chown=postgres:postgres /work/sql/ /docker-entrypoint-initdb.d/
# The entrypoint supports running as the postgres user; it skips the chown
# steps it would run as root.
USER postgres
EXPOSE 5432
# Checks TCP on 127.0.0.1, which only answers after the init scripts finish
# (during init the server listens on the Unix socket only).
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=12 \
  CMD pg_isready --host=127.0.0.1 --port=5432 --username="${POSTGRES_USER:-postgres}" || exit 1
