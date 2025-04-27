# Dockerfile para PostgreSQL com webhook integrado
FROM postgres:17

# Instalar Node.js e dependências necessárias para extensões PostgreSQL
RUN apt-get update && apt-get install -y curl gnupg ca-certificates postgresql-contrib wget \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    # Instalar pg_cron
    && wget https://github.com/citusdata/pg_cron/archive/refs/tags/v1.6.0.tar.gz \
    && tar -xf v1.6.0.tar.gz \
    && cd pg_cron-1.6.0 \
    && apt-get install -y postgresql-server-dev-17 gcc make \
    && make && make install \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf v1.6.0.tar.gz pg_cron-1.6.0

# Copiar arquivos de inicialização do PostgreSQL
COPY ./init/init.sql /docker-entrypoint-initdb.d/

# Criar diretório para o webhook
RUN mkdir -p /app/webhook
WORKDIR /app/webhook

# Copiar e instalar dependências do webhook
COPY ./webhook/package*.json ./
RUN npm install

# Copiar código do webhook
COPY ./webhook/*.js ./

# Criar script de inicialização
RUN echo '#!/bin/bash\n\n# Iniciar PostgreSQL em segundo plano\ndocker-entrypoint.sh postgres &\n\n# Aguardar PostgreSQL ficar disponível\nuntil pg_isready -U $POSTGRES_USER -d $POSTGRES_DB; do\n  echo "Esperando PostgreSQL iniciar..."\n  sleep 2\ndone\n\n# Definir conexão para o webhook\nexport DATABASE_URL="postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/$POSTGRES_DB"\necho "Usando DATABASE_URL=$DATABASE_URL"\n\n# Iniciar webhook listener\ncd /app/webhook && node listener.js' > /start.sh

# Tornar o script executável
RUN chmod +x /start.sh

# Expor porta do PostgreSQL
EXPOSE 5432

# Comando para iniciar ambos os serviços
CMD ["/start.sh"]
