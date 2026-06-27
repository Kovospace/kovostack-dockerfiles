FROM node:22-alpine AS base

# ── Install dependencies ────────────────────────────────────────────────────
FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# ── Build ───────────────────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run generate:types && npm run generate:importmap
RUN test -f src/payload-types.ts || (echo "ERROR: src/payload-types.ts was not generated" && exit 1)
RUN npm run build

# ── Runtime ─────────────────────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# The backup/restore admin feature shells out to pg_dump/pg_restore and GNU tar.
# postgresql16-client matches the postgres:16 server used in production.
RUN apk add --no-cache postgresql16-client tar

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Standalone output only bundles what Next's tracer finds reachable from the web
# server — it omits the Payload CLI/migration runner entirely. Bring in the full
# node_modules plus the migration files and config source so `npm run migrate`
# works at container startup.
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/migrations ./migrations
COPY --from=builder --chown=nextjs:nodejs /app/src ./src
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/tsconfig.json ./tsconfig.json

COPY --chown=nextjs:nodejs docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

USER nextjs
EXPOSE 3000
ENV PORT=3000
# Docker auto-injects HOSTNAME=<container-id> at runtime, which Next's standalone
# server.js binds to instead of all interfaces — pin it back to 0.0.0.0.
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["./docker-entrypoint.sh"]