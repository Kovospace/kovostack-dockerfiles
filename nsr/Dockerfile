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
# Payload needs its generated types + admin import map before the Next build.
RUN npm run generate:types && npm run generate:importmap
RUN test -f src/payload-types.ts || (echo "ERROR: src/payload-types.ts was not generated" && exit 1)
RUN npm run build

# ── Runtime ─────────────────────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# ffmpeg is a runtime dependency of the Music upload hook, which losslessly
# re-muxes malformed MP3s on upload (see src/collections/hooks/remuxAudioUpload).
# The hook degrades gracefully if it is absent, but installing it here is what
# makes the repair actually run in production.
RUN apk add --no-cache ffmpeg

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# The standalone bundle only traces what the web server reaches. Bring in the
# full node_modules plus the Payload config source so the SQLite adapter can
# create/sync the schema (push mode) at startup.
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/src ./src
COPY --from=builder --chown=nextjs:nodejs /app/migrations ./migrations
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/tsconfig.json ./tsconfig.json

# Persistent data (mounted as volumes): the SQLite DB and the uploaded media.
RUN mkdir -p /app/data /app/public/media && chown -R nextjs:nodejs /app/data /app/public/media

COPY --chown=nextjs:nodejs docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

USER nextjs
EXPOSE 3000
ENV PORT=3000
# Docker injects HOSTNAME=<container-id>, which Next's standalone server binds
# to instead of all interfaces — pin it back to 0.0.0.0.
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["./docker-entrypoint.sh"]