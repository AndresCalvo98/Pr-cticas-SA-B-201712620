FROM node:18-alpine

WORKDIR /app

# Copiamos directamente desde la Práctica 2 para no duplicar código
# Esto cumple con el Principio de No Repetición (DRY)
COPY P2/authz-service/package*.json ./
RUN npm install

COPY P2/authz-service/ ./

EXPOSE 4000

CMD ["node", "server.js"]
