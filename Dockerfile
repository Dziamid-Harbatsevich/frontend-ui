FROM node:22-alpine

# Install libc6-compat to satisfy edge compiling behaviors for native modules
RUN apk add --no-cache libc6-compat

WORKDIR /app

# Expose internal watch variables so hot-reloading registers across the Docker mount boundary
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV WATCHPACK_POLLING=true

EXPOSE 3000

# Install dependencies at build time — the anonymous volume in docker-compose
# masks /app/node_modules, so a runtime-only install would be skipped (exit 127)
COPY package.json package-lock.json ./
RUN npm ci

CMD ["npm", "run", "dev"]
