#!/bin/bash
set -e

# Função para configurar acesso remoto depois que o PostgreSQL iniciar
setup_postgres() {
    # Aguardar o PostgreSQL iniciar
    until pg_isready -h localhost -p 5432; do
        echo "Esperando o PostgreSQL iniciar..."
        sleep 1
    done
    
    echo "PostgreSQL iniciado. Configurando acesso remoto..."
    # Configurar acesso remoto
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
    
    echo "Permitindo conexões de hosts remotos com senha..."
    echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    echo "host all all ::/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    
    # Reiniciar PostgreSQL para aplicar configurações
    pg_ctl -D /var/lib/postgresql/data -m fast -w restart
    
    # Iniciar o listener Node.js
    echo "Iniciando o listener Node.js para eventos do PostgreSQL..."
    cd /opt/listener && node listener.js &
}

# Verificar se é o comando postgres
if [ "$1" = 'postgres' ]; then
    # Iniciar PostgreSQL em background
    /usr/local/bin/docker-entrypoint.sh postgres "$@" &
    
    # Configurar PostgreSQL e iniciar o listener em outro processo
    setup_postgres &
    
    # Manter o container vivo
    wait
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
