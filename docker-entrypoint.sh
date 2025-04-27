#!/bin/bash
set -e

# Definição para o script que iniciará o listener depois
cat > /usr/local/bin/start-listener.sh << 'EOF'
#!/bin/bash

# Aguardar PostgreSQL estar pronto
until pg_isready -h localhost -p 5432; do
  echo "Aguardando PostgreSQL iniciar completamente..."
  sleep 2
done

# Configurar acesso remoto
echo "Configurando acesso remoto..."
echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
echo "host all all ::/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
pg_ctl -D "$PGDATA" reload

# Iniciar listener
echo "Iniciando o listener Node.js..."
cd /opt/listener && node listener.js
EOF

chmod +x /usr/local/bin/start-listener.sh

# Criar script de inicialização para extensões e notificações
cat > /docker-entrypoint-initdb.d/01-setup-extensions.sh << 'EOF'
#!/bin/bash

echo "Configurando extensões PostgreSQL..."
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_cron;"
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER DATABASE \"$POSTGRES_DB\" SET timezone TO 'America/Recife';"
EOF

chmod +x /docker-entrypoint-initdb.d/01-setup-extensions.sh

# Script para iniciar o listener após PostgreSQL iniciar
cat > /docker-entrypoint-initdb.d/99-start-listener-after-init.sh << 'EOF'
#!/bin/bash

# Iniciar o listener em background quando PostgreSQL terminar de inicializar
/usr/local/bin/start-listener.sh &
EOF

chmod +x /docker-entrypoint-initdb.d/99-start-listener-after-init.sh

# Executar o entrypoint original do PostgreSQL
exec /usr/local/bin/docker-entrypoint.sh "$@"
