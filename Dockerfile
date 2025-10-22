# Dockerfile para PoC Chatbot Financiero (producción ligera)
# Basado en node:18-alpine, usa un usuario no-root y realiza build en una sola etapa para simplicidad.
FROM node:18-alpine

# Crear usuario no-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar package.json y package-lock (si existe) para aprovechar cache de Docker
COPY package.json package-lock.json* ./

# Instalar dependencias (production)
RUN npm ci --only=production

# Copiar el resto del código
COPY . .

# Ajustar permisos
RUN chown -R appuser:appgroup /app

# Exponer puerto que usa la app (server.js escucha en PORT env o 3000)
EXPOSE 3000

# Ejecutar como usuario no-root
USER appuser

# Healthcheck simple
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- --timeout=2 http://localhost:3000/health || exit 1

CMD ["node", "server.js"]