FROM postgres:17-alpine

# Add PostgreSQL extensions and utilities
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git \
    curl \
    ca-certificates \
    tzdata \
    make \
    gcc \
    libc-dev

# Install pg_cron extension
RUN cd /tmp && \
    git clone https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make && \
    make install

# Install PostgreSQL extensions
RUN mkdir -p /docker-entrypoint-initdb.d

# Copy initialization scripts
COPY ./init/*.sql /docker-entrypoint-initdb.d/

# Environment variables are set through the Easypanel interface
# Não definimos as variáveis aqui para evitar o hardcoding de credenciais
# Os valores serão injetados pelo Easypanel através das variáveis de ambiente

# Set up for pgcrypto, pg_stat_statements, pg_cron
RUN echo "shared_preload_libraries = 'pg_stat_statements,pg_cron'" >> /usr/local/share/postgresql/postgresql.conf.sample
RUN echo "cron.database_name = 'leadscrm'" >> /usr/local/share/postgresql/postgresql.conf.sample

# Expose the PostgreSQL port
EXPOSE 5432

# Volume to persist data
VOLUME ["/var/lib/postgresql/data"]

# Set the working directory
WORKDIR /var/lib/postgresql

# Default command
CMD ["postgres"]
