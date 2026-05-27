FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY src/ ./src/
RUN npm run build

# ── prod stage ────────────────────────────────
FROM nginx:alpine AS prod
WORKDIR /usr/share/nginx/html

# Copy built frontend
COPY --from=builder /app/dist .

# Optional: nginx config for SPA routing
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
  listen 80;
  root /usr/share/nginx/html;
  
  # SPA routing — all routes go to index.html
  location / {
    try_files $uri $uri/ /index.html;
  }
  
  # Cache static assets
  location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
EOF

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]