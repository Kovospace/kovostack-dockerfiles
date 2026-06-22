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

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

#COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Next's standalone output tracer misses libsql's native binding (dynamic require) —
# copy it in manually so the sqlite adapter import doesn't crash even when unused.
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/libsql ./node_modules/libsql
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/@libsql ./node_modules/@libsql

USER nextjs
EXPOSE 3000
ENV PORT=3000
# Docker auto-injects HOSTNAME=<container-id> at runtime, which Next's standalone
# server.js binds to instead of all interfaces — pin it back to 0.0.0.0.
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]