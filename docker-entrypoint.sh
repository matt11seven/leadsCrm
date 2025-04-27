#!/bin/bash
set -e

# Este é um script simplificado para evitar quaisquer problemas de inicialização

# Se for o comando postgres, simplesmente executar o entrypoint original
if [ "$1" = 'postgres' ]; then
    # Primeiro, iniciar o PostgreSQL normalmente
    echo "Iniciando PostgreSQL (usando script padrão)..."
    
    # Iniciar uma tarefa em background para configurar as extensões e iniciar o listener depois
    (
        # Aguardar tempo suficiente para o PostgreSQL inicializar completamente
        echo "Agendando início do listener para daqui a 30 segundos..."
        sleep 30
        
        # Tentar conectar ao PostgreSQL para verificar se está funcionando
        echo "Verificando conexão com PostgreSQL..."
        if PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;" > /dev/null 2>&1; then
            echo "PostgreSQL está respondendo. Configurando extensões..."
            
            # Criar extensões
            PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
            PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
            PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
            PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
            
            # Adicionar configuração para acesso remoto
            echo "Configurando acesso remoto..."
            echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
            echo "host all all ::/0 md5" >> "$PGDATA/pg_hba.conf"
            
            # Recarregar configurações
            pg_ctl -D "$PGDATA" reload
            
            # Iniciar o listener Node.js
            echo "Iniciando o listener Node.js para eventos do PostgreSQL..."
            cd /opt/listener && exec node listener.js &
        else
            echo "ERRO: Não foi possível conectar ao PostgreSQL após 30 segundos."
        fi
    ) &
    
    # Executar o entrypoint original do PostgreSQL (sem chamar nosso script novamente)
    exec /usr/lib/postgresql/17/bin/postgres -D "$PGDATA"
else
    # Se não for o comando postgres, executar normalmente
    exec "$@"
fi
