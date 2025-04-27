FROM postgres:17

# Instalar extensões e utilitários do PostgreSQL
RUN apt-get update && apt-get install -y \
    postgresql-contrib \
    postgresql-17-cron \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório para scripts de inicialização
RUN mkdir -p /docker-entrypoint-initdb.d

# Copiar scripts de inicialização
COPY ./init/*.sql /docker-entrypoint-initdb.d/

# Configurar bibliotecas compartilhadas
RUN echo "shared_preload_libraries = 'pg_stat_statements,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name = '${POSTGRES_DB:-leadscrm}'" >> /usr/share/postgresql/postgresql.conf.sample

# Criar script de inicialização para garantir que as extensões sejam criadas
RUN echo '#!/bin/bash\necho "Habilitando extensões necessárias..."\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"' > /docker-entrypoint-initdb.d/00-create-extensions.sh \
    && chmod +x /docker-entrypoint-initdb.d/00-create-extensions.sh

# Expor a porta do PostgreSQL
EXPOSE 5432

# Volume para persistir dados
VOLUME ["/var/lib/postgresql/data"]

# Comando padrão
CMD ["postgres"]
