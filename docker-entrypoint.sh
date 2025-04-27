#!/bin/bash
set -e

# Iniciar o listener Node.js após o PostgreSQL estar pronto
start_listener() {
    echo "Iniciando o listener Node.js para eventos do PostgreSQL..."
    cd /opt/listener && node listener.js
}

# Configurar o PostgreSQL após inicialização
setup_postgres() {
    echo "PostgreSQL iniciado. Configurando extensões..."
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
    
    echo "Permitindo conexões de hosts remotos com senha..."
    echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    echo "host all all ::/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
    
    # Recarregar configurações sem reiniciar o PostgreSQL
    echo "Recarregando configurações do PostgreSQL..."
    pg_ctl -D "$PGDATA" reload
    
    # Iniciar o listener em background
    start_listener &
}

# Verificar se é o comando postgres
if [ "$1" = 'postgres' ]; then
    # Usar o entrypoint original do PostgreSQL para iniciar o servidor
    # mas modificar para executar nossas funções após inicialização
    
    # Primeiro substituir o entrypoint original
    ORIGINAL_ENTRYPOINT=$(which docker-entrypoint.sh)
    
    # Diferenciar entre primeira inicialização e execução normal
    if [ -f "$PGDATA/PG_VERSION" ]; then
        echo "PostgreSQL já inicializado, iniciando normalmente..."
        # Servidor já inicializado, iniciar o PostgreSQL
        exec "$ORIGINAL_ENTRYPOINT" "$@" & 
        # Aguardar o PostgreSQL iniciar
        until pg_isready -h localhost -p 5432; do
            echo "Aguardando PostgreSQL ficar pronto..."
            sleep 1
        done
        # Iniciar o listener
        start_listener
    else
        echo "Primeira inicialização do PostgreSQL..."
        # Executar o entrypoint original e esperar inicialização completa
        "$ORIGINAL_ENTRYPOINT" "$@" & 
        PG_PID=$!
        
        # Aguardar o PostgreSQL iniciar
        until pg_isready -h localhost -p 5432; do
            echo "Aguardando PostgreSQL inicializar pela primeira vez..."
            sleep 2
            # Verificar se o processo do PostgreSQL ainda está em execução
            if ! kill -0 $PG_PID 2>/dev/null; then
                echo "Erro: O processo do PostgreSQL falhou ao iniciar"
                exit 1
            fi
        done
        
        # Configurar PostgreSQL
        setup_postgres
        
        # Manter o container vivo
        wait $PG_PID
    fi
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
