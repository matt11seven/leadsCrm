#!/bin/bash
set -e

# Script simplificado para inicialização do PostgreSQL e listener Node.js

# Aguardar PostgreSQL estar pronto
wait_for_postgres() {
    echo "Aguardando PostgreSQL estar pronto..."
    until pg_isready -h localhost -p 5432; do
        echo "Esperando PostgreSQL iniciar..."
        sleep 2
    done
    echo "PostgreSQL está pronto!"
}

# Iniciar o listener Node.js
start_listener() {
    echo "Iniciando o listener Node.js..."
    cd /opt/listener && node listener.js
}

# Configurar acesso remoto PostgreSQL
setup_remote_access() {
    echo "Configurando acesso remoto..."
    echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    echo "host all all ::/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    pg_ctl -D "$PGDATA" reload
}

# Verificar se é o comando postgres
if [ "$1" = 'postgres' ]; then
    # Configurar Docker Entrypoint
    if [ ! -f "/docker-entrypoint-initdb.d/extensions.sh" ]; then
        echo "Criando script de configuração de extensões..."
        cat > /docker-entrypoint-initdb.d/extensions.sh << 'EOF'
#!/bin/bash
echo "Configurando extensões PostgreSQL..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
EOF
        chmod +x /docker-entrypoint-initdb.d/extensions.sh
    fi
    
    # Usar entrypoint original do PostgreSQL para fazer a inicialização padrão
    echo "Iniciando PostgreSQL..."
    /usr/local/bin/postgres "$@" &
    PG_PID=$!
    
    # Aguardar PostgreSQL iniciar completamente
    wait_for_postgres
    
    # Configurar acesso remoto
    setup_remote_access
    
    # Iniciar listener
    start_listener &
    
    # Manter container em execução
    wait $PG_PID
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
