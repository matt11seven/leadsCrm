#!/bin/bash
set -e

# Diretório para sinalizar quando o listener já está em execução
LISTENER_FLAG="/tmp/.listener_running"

# Função para iniciar o listener Node.js em um processo separado
start_listener() {
    if [ ! -f "$LISTENER_FLAG" ]; then
        echo "Iniciando o listener Node.js para eventos do PostgreSQL..."
        cd /opt/listener && node listener.js &
        # Criar sinalizador para que não iniciemos o listener repetidamente
        touch "$LISTENER_FLAG"
    else
        echo "Listener Node.js já está em execução."
    fi
}

# Este script será executado após o PostgreSQL já estar em execução
conf_and_start_listener() {
    # Configurar as extensões e ajustes de acesso
    echo "Configurando extensões e acesso remoto..."
    # Esperar o PostgreSQL estar realmente pronto
    sleep 5
    
    # Extensões
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
    
    # Configurar acesso remoto se ainda não estiver configurado
    if ! grep -q "0.0.0.0/0 md5" "$PGDATA/pg_hba.conf"; then
        echo "Configurando acesso remoto..."
        echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
        echo "host all all ::/0 md5" >> "$PGDATA/pg_hba.conf"
        
        # Recarregar configurações
        echo "Recarregando configurações do PostgreSQL..."
        pg_ctl -D "$PGDATA" reload
    fi
    
    # Iniciar o listener
    start_listener
}

# Apenas usar o entrypoint original do PostgreSQL
if [ "$1" = 'postgres' ]; then
    echo "Iniciando PostgreSQL com entrypoint padrão..."
    
    # Iniciar o processo de configuração e o listener em background
    # mas aguardar um pouco para dar tempo ao PostgreSQL iniciar primeiro
    (sleep 10 && conf_and_start_listener) &
    
    # Excutar o entrypoint original do PostgreSQL
    ORIGINAL_PATH=$(dirname "$(which docker-entrypoint.sh)")
    PATH="$ORIGINAL_PATH:$PATH" exec /usr/local/bin/docker-entrypoint.sh "$@"
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
