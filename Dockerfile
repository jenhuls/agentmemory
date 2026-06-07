FROM node:20-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim
WORKDIR /app

# Pre-install iii-engine binary at build time so the CLI finds it on first start.
# Using a temp dir + find to handle any tar directory nesting from cargo-dist.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    mkdir -p /root/.agentmemory/bin /tmp/iii-install && \
    curl -fsSL "https://github.com/iii-hq/iii/releases/download/iii/v0.11.2/iii-x86_64-unknown-linux-gnu.tar.gz" \
      | tar -xz -C /tmp/iii-install && \
    find /tmp/iii-install -name 'iii' -type f -exec mv {} /root/.agentmemory/bin/iii \; && \
    chmod +x /root/.agentmemory/bin/iii && \
    rm -rf /tmp/iii-install && \
    apt-get purge -y --auto-remove curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

# Use railway config as the active iii-config (0.0.0.0 bind, open CORS, /data persistence)
COPY iii-config.railway.yaml ./iii-config.yaml

# Set PORT=3111 in Railway Variables to match this.
EXPOSE 3111

CMD ["node", "dist/cli.mjs"]
