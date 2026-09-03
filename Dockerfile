# OpenTrader — self-hosted crypto trading bot (DCA & Grid strategies)
# Upstream: https://github.com/Open-Trader/opentrader (pinned v1.0.0-beta.29)
# Multi-stage build via moonrepo toolchain (mirrors upstream Dockerfile flow).

#### BASE
FROM node:22.12-alpine3.20 AS base

ENV MOON_TOOLCHAIN_FORCE_GLOBALS=true

WORKDIR /app

# Install moon binary + pnpm (pinned to match the release toolchain)
RUN npm install -g @moonrepo/cli@1.28.3 && npm install -g pnpm@10

#### SKELETON
FROM base AS skeleton

# Copy entire repository and scaffold
COPY . .

# Copy the minimum of files necessary for installing dependencies
RUN moon docker scaffold cli

#### BUILD
FROM base AS build

# Copy toolchain
COPY --from=skeleton /root/.proto /root/.proto

# Copy workspace skeleton
COPY --from=skeleton /app/.moon/docker/workspace .
# Copy Prisma schema
COPY --from=skeleton /app/.moon/docker/sources/packages/prisma/src/schema.prisma ./packages/prisma/src/schema.prisma

# Install toolchain and dependencies
RUN moon docker setup

# Copy source files
COPY --from=skeleton /app/.moon/docker/sources .

# Build the CLI bundle (tsup -> dist/standalone.mjs, frontend/ is a committed prebuilt dist)
# Upstream lockfile drift bug: zod-prisma-types generates `import 'zod/v3'` but the
# pinned zod 3.24.1 has no /v3 subpath export. Bundle against root 'zod' (same
# version, exports ZodFirstPartyTypeKind) — runtime-resolvable without drift.
RUN moon run cli:build && sed -i "s|'zod/v3'|'zod'|g" apps/cli/dist/*.mjs

# Remove unneeded files and folders
RUN moon docker prune

#### RUNNER
FROM node:22.12-alpine3.20 AS runner
WORKDIR /app

# Runs as root: Railway volumes mount root-owned and prisma must be able to
# create/lock the SQLite file on /app/data (non-root images crash-loop EACCES).

COPY --from=build /app/apps/cli ./apps/cli
COPY --from=build /app/node_modules ./node_modules

# Upstream frontend ships a hardcoded default backendURL of http://localhost:8000
# (dev convenience). On a remote host the UI shows "backend is offline" until the
# user hand-edits Settings → backendURL. Default it to the serving origin instead:
# the standalone server serves both the UI and /api/* on the same port.
RUN sed -i 's|"http://localhost:8000"|window.location.origin|g' apps/cli/frontend/assets/*.js

# Copy Prisma schema, migrations, and seed script
# Upstream root route ("/") redirects to the bot dashboard, whose bot.list
# useSuspenseQuery fires BEFORE login and renders a raw "Error occurred:
# UNAUTHORIZED" boundary on first visit (no localStorage password yet). Land
# first-time visitors on the login page instead; after login the UI routes to
# the dashboard itself.
RUN sed -i 's|c({to:ii("bot")})|c({to:ii("login")})|g' apps/cli/frontend/assets/*.js

COPY --from=build /app/packages/prisma/src/schema.prisma ./packages/prisma/src/schema.prisma
COPY --from=build /app/packages/prisma/src/migrations ./packages/prisma/src/migrations
COPY --from=build /app/packages/prisma/seed.mjs ./packages/prisma/seed.mjs

ENV NODE_ENV=production \
    PORT=4000 \
    HOST=0.0.0.0 \
    DATABASE_URL=file:/app/data/opentrader.db

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
  CMD wget -qO- "http://127.0.0.1:${PORT}/api/trpc/public.healhcheck?input=%7B%7D" | grep -q '"status":"ok"' || exit 1

# Run DB migrations + seed, then start (upstream bin/docker-entry.sh behavior).
# PORT is pinned here: Railway injects PORT=8080 on service vars-less deploys,
# which breaks the domain targeting 4000 (verified live 502). Image default wins.
CMD ["sh", "-c", "mkdir -p /app/data && /app/node_modules/prisma/build/index.js migrate deploy --schema /app/packages/prisma/src/schema.prisma && node /app/packages/prisma/seed.mjs && cd /app/apps/cli && export PORT=4000 && exec node dist/standalone.mjs"]