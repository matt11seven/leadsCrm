#!/bin/bash
set -e

# Verificar se o PostgreSQL está completamente pronto para receber conexões
wait_for_postgres() {
    echo "Verificando se o PostgreSQL está pronto para conexões..."
    # Esperar até que o PostgreSQL esteja aceitando conexões
    until pg_isready -h localhost -p 5432; do
        echo "Aguardando PostgreSQL ficar pronto para conexões..."
        sleep 2
    done
    
    # Verificar adicionalmente se é possível estabelecer uma conexão real
    until psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" > /dev/null 2>&1; do
        echo "Aguardando PostgreSQL aceitar consultas SQL..."
        sleep 2
    done
    
    echo "PostgreSQL está pronto e aceitando conexões!"
}

# Iniciar o listener Node.js após o PostgreSQL estar pronto
start_listener() {
    # Garantir que o PostgreSQL está completamente pronto
    wait_for_postgres
    
    echo "Iniciando o listener Node.js para eventos do PostgreSQL..."
    cd /opt/listener && node listener.js
}

# Configurar o PostgreSQL após inicialização
setup_postgres() {
    # Garantir que o PostgreSQL está pronto antes de configurar
    wait_for_postgres
    
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
        # Servidor já inicializado, iniciar o PostgreSQL e aguardar que esteja em execução
        "$ORIGINAL_ENTRYPOINT" "$@" &
        PG_MAIN_PID=$!
        
        echo "PostgreSQL iniciado com PID $PG_MAIN_PID, aguardando ficar pronto..."
        # Iniciar o listener após garantir que o PostgreSQL esteja pronto
        start_listener &
        
        # Aguardar o processo principal do PostgreSQL (para manter o container vivo)
        wait $PG_MAIN_PID
    else
        echo "Primeira inicialização do PostgreSQL..."
        # Executar o entrypoint original e esperar inicialização completa
        "$ORIGINAL_ENTRYPOINT" "$@" & 
        PG_PID=$!
        
        # Monitorar o processo do PostgreSQL enquanto aguarda inicialização
        TIMEOUT=120 # 2 minutos de timeout
        ELAPSED=0
        while ! pg_isready -h localhost -p 5432 >/dev/null 2>&1; do
            echo "Aguardando PostgreSQL inicializar pela primeira vez... ($ELAPSED/$TIMEOUT segundos)"
            sleep 5
            ELAPSED=$((ELAPSED+5))
            
            # Verificar se o processo do PostgreSQL ainda está em execução
            if ! kill -0 $PG_PID 2>/dev/null; then
                echo "Erro: O processo do PostgreSQL falhou ao iniciar"
                exit 1
            fi
            
            # Adicionar timeout para evitar loop infinito
            if [ $ELAPSED -ge $TIMEOUT ]; then
                echo "Timeout atingido ao aguardar pelo PostgreSQL. Verificando logs:"
                tail -n 30 "$PGDATA/log/"*.log 2>/dev/null || echo "Nenhum log encontrado"
                exit 1
            fi
        done
        
        echo "PostgreSQL detectado como pronto para conexões iniciais"
        
        # Configurar PostgreSQL
        setup_postgres
        
        # Manter o container vivo
        wait $PG_PID
    fi
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
