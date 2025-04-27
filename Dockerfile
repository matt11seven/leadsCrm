FROM postgres:17

# Instalar extensões e utilitários do PostgreSQL
RUN apt-get update && apt-get install -y \
    postgresql-contrib \
    postgresql-17-cron \
    ca-certificates \
    tzdata \
    locales \
    curl \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Instalar Node.js 18
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Configurar localidade
RUN localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias pt_BR.UTF-8
ENV LANG pt_BR.utf8
ENV LC_ALL pt_BR.UTF-8

# Configurar timezone
ENV TZ=America/Recife

# Criar diretório para scripts de inicialização
RUN mkdir -p /docker-entrypoint-initdb.d

# Copiar scripts de inicialização
COPY ./init/*.sql /docker-entrypoint-initdb.d/

# Configurar bibliotecas compartilhadas e acesso externo
RUN echo "shared_preload_libraries = 'pg_stat_statements,pg_cron'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name = '${POSTGRES_DB:-leadscrm}'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "timezone = 'America/Recife'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "lc_messages = 'pt_BR.UTF-8'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "lc_monetary = 'pt_BR.UTF-8'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "lc_numeric = 'pt_BR.UTF-8'" >> /usr/share/postgresql/postgresql.conf.sample
RUN echo "lc_time = 'pt_BR.UTF-8'" >> /usr/share/postgresql/postgresql.conf.sample

# Configurar para aceitar conexões externas
RUN echo "listen_addresses = '*'" >> /usr/share/postgresql/postgresql.conf.sample

# Criar script de inicialização para garantir que as extensões sejam criadas e permitir acesso externo
RUN echo '#!/bin/bash\necho "Habilitando extensões necessárias..."\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"\npsql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO '\''America/Recife'\'';"\n\n# Permitir conexões de hosts remotos com senha\necho "Configurando acesso remoto..."\necho "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf\necho "host all all ::/0 md5" >> /var/lib/postgresql/data/pg_hba.conf' > /docker-entrypoint-initdb.d/00-create-extensions.sh \
    && chmod +x /docker-entrypoint-initdb.d/00-create-extensions.sh

# Configurar o listener Node.js
RUN mkdir -p /opt/listener
COPY listener/package.json listener/listener.js /opt/listener/
WORKDIR /opt/listener
RUN npm ci --omit=dev
WORKDIR /

# Copiar e configurar script de entrypoint customizado
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expor a porta do PostgreSQL
EXPOSE 5432

# Volume para persistir dados
VOLUME ["/var/lib/postgresql/data"]

# Entrypoint e comando
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
