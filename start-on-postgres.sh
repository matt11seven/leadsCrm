#!/bin/bash
set -e

# Iniciar o PostgreSQL usando o entrypoint padrão
/usr/local/bin/docker-entrypoint.sh postgres "$@" &
PG_PID=$!

# Aguardar até que o PostgreSQL esteja pronto
echo "Aguardando PostgreSQL iniciar..."
until pg_isready -h localhost; do
  echo "Esperando PostgreSQL..."
  sleep 2
done

# Iniciar o listener em background
echo "Iniciando o listener Node.js..."
cd /opt/listener && node listener.js &
LISTENER_PID=$!

# Aguardar término do PostgreSQL para manter o container rodando
wait $PG_PID
