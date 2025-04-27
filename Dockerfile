# Dockerfile unificado para o CRM PostgreSQL + Webhook
FROM node:18-alpine

WORKDIR /app

# Copiar arquivos do projeto
COPY . .

# Instalar dependências do webhook
WORKDIR /app/webhook
RUN npm install

# Voltar para a raiz
WORKDIR /app

# Instalar docker-compose (para ambiente Easypanel)
RUN apk add --no-cache docker-compose

# Expor a porta do PostgreSQL
EXPOSE 5432

# Comando para iniciar utilizando docker-compose
CMD ["docker-compose", "up", "-d"]
