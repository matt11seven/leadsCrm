FROM postgres:17-alpine

# Add PostgreSQL extensions and utilities
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git \
    curl \
    ca-certificates \
    tzdata \
    wget

# Install pg_cron extension (usando uma abordagem alternativa)
RUN cd /tmp && \
    git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    # Desativar a compilação com clang que está causando problemas
    sed -i 's/clang/gcc/g' Makefile && \
    sed -i '/llvm/d' Makefile && \
    # Compilar apenas o básico necessário
    make NO_PGXS=1 && \
    cp pg_cron.so /usr/local/lib/postgresql/ && \
    cp pg_cron.control /usr/local/share/postgresql/extension/ && \
    cp pg_cron--*.sql /usr/local/share/postgresql/extension/

# Install PostgreSQL extensions
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy initialization scripts
COPY ./init/*.sql /docker-entrypoint-initdb.d/

# Environment variables are set through the Easypanel interface
# Não definimos as variáveis aqui para evitar o hardcoding de credenciais
# Os valores serão injetados pelo Easypanel através das variáveis de ambiente

# Set up for pgcrypto, pg_stat_statements
RUN echo "shared_preload_libraries = 'pg_stat_statements'" >> /usr/local/share/postgresql/postgresql.conf.sample

# A extensão pg_cron será instalada diretamente no script SQL de inicialização
# em vez de ser carregada como shared_preload_library

# Expose the PostgreSQL port
EXPOSE 5432

# Volume to persist data
VOLUME ["/var/lib/postgresql/data"]

# Set the working directory
WORKDIR /var/lib/postgresql

# Default command
CMD ["postgres"]
