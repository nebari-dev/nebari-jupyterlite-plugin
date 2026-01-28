# Build stage - create JupyterLite static files
FROM python:3.12-slim AS builder

WORKDIR /build

# Install jupyterlite and common kernels
RUN pip install --no-cache-dir \
    jupyterlite-core \
    jupyterlite-pyodide-kernel \
    jupyterlab

# Build JupyterLite
RUN jupyter lite build --output-dir /build/output

# Production stage - serve with nginx
FROM nginx:alpine

# Copy built JupyterLite files
COPY --from=builder /build/output /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8000

CMD ["nginx", "-g", "daemon off;"]
