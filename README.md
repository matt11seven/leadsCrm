# Leads CRM PostgreSQL

Sistema para gerenciamento de leads com PostgreSQL e notificações em tempo real via webhooks.

## Estrutura do Projeto

O sistema consiste em:

- **Banco de dados PostgreSQL** com tabelas para leads, eventos e NPS
- **Triggers e funções PL/pgSQL** para sincronização de dados e notificações
- **Webhook Listener** para enviar eventos via HTTP POST
- **Automação de deploy** com GitHub Actions

## Tabelas do Banco de Dados

- `leads`: Armazena informações básicas dos leads
- `lead_events`: Registra eventos relacionados aos leads
- `lead_nps`: Armazena pontuações NPS fornecidas pelos leads

## Extensões PostgreSQL

- `pgcrypto`: Para geração de UUIDs e criptografia
- `pg_stat_statements`: Para monitoramento de performance de queries
- `pg_cron`: Para agendamento de tarefas no banco de dados

## Funções e Triggers

- `sync_lead_event()`: Atualiza dados JSONB e contadores em `leads`
- `notify_lead_event()`: Emite notificações NOTIFY ao canal `lead_event_channel`

## Como Executar Localmente

### Pré-requisitos

- Docker e Docker Compose instalados
- Git (opcional, para clonar o repositório)

### Passos

1. Clone o repositório:
   ```bash
   git clone https://github.com/seu-usuario/leads-crm.git
   cd leads-crm
   ```

2. Crie um arquivo `.env` baseado no exemplo:
   ```bash
   cp .env.example .env
   ```

3. Edite o arquivo `.env` com suas configurações:
   ```bash
   # Configurações do PostgreSQL
   POSTGRES_USER=postgres
   POSTGRES_PASSWORD=sua_senha_segura
   POSTGRES_DB=leadscrm
   POSTGRES_PORT=5432
   
   # Configuração do Webhook
   WEBHOOK_URL=http://seu-endpoint-webhook.com/api/lead-event
   ```

4. Inicie os containers:
   ```bash
   docker-compose up -d
   ```

5. Verifique se os containers estão rodando:
   ```bash
   docker-compose ps
   ```

## Testes

Para testar a funcionalidade de eventos e webhook, insira um lead e um evento:

```sql
-- Conecte-se ao banco de dados
docker-compose exec postgres psql -U postgres -d leadscrm

-- Insira um novo lead
INSERT INTO leads (email, name) VALUES ('cliente@exemplo.com', 'Cliente Teste');

-- Insira um evento para este lead
INSERT INTO lead_events (lead_id, event_type, data) 
SELECT id, 'contato', '{"via": "email", "assunto": "Orçamento"}' 
FROM leads 
WHERE email = 'cliente@exemplo.com';
```

## Configurando o Deploy Automatizado

### Pré-requisitos

- Repositório GitHub privado
- Servidor com Docker e Docker Compose instalados
- Acesso SSH ao servidor

### Configuração do GitHub Secrets

Configure os seguintes secrets no seu repositório GitHub:

1. `SSH_PRIVATE_KEY`: Sua chave SSH privada para acesso ao servidor
2. `TARGET_HOST`: Hostname ou IP do servidor (ex: `seu-servidor.com`)
3. `TARGET_USER`: Usuário SSH no servidor (ex: `ubuntu`)
4. `TARGET_DIR`: Diretório para deploy no servidor (ex: `/opt/leads-crm`)
5. `POSTGRES_USER`: Usuário do PostgreSQL
6. `POSTGRES_PASSWORD`: Senha do PostgreSQL
7. `POSTGRES_DB`: Nome do banco de dados
8. `WEBHOOK_URL`: URL para onde enviar os webhooks

### Deploy "Com Um Clique"

Após configurar os secrets, você pode fazer o deploy:

1. Vá para a aba "Actions" no seu repositório GitHub
2. Selecione o workflow "Deploy PostgreSQL with Leads CRM"
3. Clique em "Run workflow"
4. Selecione a branch (normalmente `main`)
5. Selecione o ambiente (`staging` ou `production`)
6. Clique em "Run workflow"

O GitHub Actions irá:
- Enviar os arquivos para o servidor
- Configurar as variáveis de ambiente
- Iniciar os containers Docker
- Verificar se o deploy foi bem-sucedido

## Estrutura do Diretório

```
leads-crm/
├── .github/
│   └── workflows/
│       └── deploy.yml       # Workflow para deploy automático
├── webhook-listener/
│   ├── webhook_listener.js  # Código do listener
│   ├── package.json         # Dependências do Node.js
│   └── Dockerfile           # Para construir a imagem Docker
├── docker-compose.yml       # Configuração dos containers
├── init.sql                 # Scripts SQL para inicialização do banco
├── .env.example             # Exemplo de variáveis de ambiente
└── README.md                # Esta documentação
```

## Contribuindo

1. Faça um fork do repositório
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Faça commit das suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Faça push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).
