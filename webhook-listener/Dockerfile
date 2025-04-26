FROM node:18-alpine

WORKDIR /app

# Copiar package.json e package-lock.json
COPY package*.json ./

# Instalar dependências
RUN npm ci --only=production

# Copiar os arquivos do código-fonte
COPY . .

# Expor porta (se necessário)
# EXPOSE 3000

# Comando para iniciar a aplicação
CMD ["node", "webhook_listener.js"]
