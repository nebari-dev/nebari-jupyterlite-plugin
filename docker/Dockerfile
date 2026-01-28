# Build stage - create JupyterLite static files
FROM ghcr.io/prefix-dev/pixi:latest AS builder

WORKDIR /build

# Copy pixi config
COPY pixi.toml .

# Install dependencies and build JupyterLite
RUN pixi install && pixi run build

# Production stage - serve with nginx
FROM nginx:alpine

# Copy built JupyterLite files
COPY --from=builder /build/output /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8000

CMD ["nginx", "-g", "daemon off;"]
