# PostgreSQL 17 Deployment with Easypanel

Este repositório contém a configuração necessária para deploy do PostgreSQL 17 no Easypanel para o sistema Leads CRM.

## Estrutura do Projeto

- `Dockerfile`: Configuração do PostgreSQL 17 com extensões necessárias
- `init/01-init.sql`: Script SQL para inicialização do banco de dados com tabelas e funções
- `docker-compose.yml`: Configuração para desenvolvimento local
- `easypanel.yml`: Configuração específica para deploy no Easypanel

## Extensões PostgreSQL Incluídas

- pgcrypto: Para funções criptográficas e geração de UUIDs
- pg_stat_statements: Para monitoramento de performance
- pg_cron: Para agendamento de tarefas no banco de dados

## Tabelas e Funcionalidades

O banco de dados inclui as seguintes tabelas:
- `leads`: Armazena informações básicas dos leads
- `lead_events`: Rastreia todos os eventos relacionados aos leads
- `lead_nps`: Armazena avaliações NPS dos leads

Além disso, há triggers e funções para:
- Sincronização automática de eventos
- Notificações de eventos em tempo real

## Como Fazer o Deploy no Easypanel

1. Faça login no painel do Easypanel
2. Crie um novo projeto
3. Selecione a opção "Deploy from Git repository"
4. Cole a URL deste repositório
5. Configure as variáveis de ambiente:
   - `POSTGRES_USER`: Usuário para o PostgreSQL
   - `POSTGRES_PASSWORD`: Senha para o PostgreSQL
   - `POSTGRES_DB`: Nome do banco de dados (padrão: leadscrm)
6. Clique em "Deploy"

## Desenvolvimento Local

Para executar o banco de dados localmente:

```bash
docker-compose up -d
```

Isso iniciará o PostgreSQL na porta 5432. Você pode conectar usando qualquer cliente PostgreSQL com as seguintes credenciais:
- Host: localhost
- Porta: 5432
- Usuário: postgres (ou o valor definido em POSTGRES_USER)
- Senha: postgres (ou o valor definido em POSTGRES_PASSWORD)
- Banco de dados: leadscrm (ou o valor definido em POSTGRES_DB)

## Webhook Listener

Para integrar com o webhook listener que recebe notificações do PostgreSQL, certifique-se de que o aplicativo Node.js esteja configurado para se conectar a este banco de dados.
