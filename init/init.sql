-- init/init.sql

-- 1) Extensões necessárias
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2) Tabela de leads: perfil, aquisição, cadência, pipeline, touchpoints, pós-venda etc.
CREATE TABLE public.leads (
  id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name              VARCHAR(100),
  user_ns                 VARCHAR(100),
  nome_completo           VARCHAR(100) NOT NULL,
  email                   VARCHAR(150),
  telefone                VARCHAR(20)  NOT NULL,
  instagram               VARCHAR(50),
  seguidores              INTEGER,
  genero                  VARCHAR(20),

  -- rastreamento de dispositivo e localização
  location_data           JSONB        NOT NULL DEFAULT '{}'::jsonb,
  device_info             JSONB        NOT NULL DEFAULT '{}'::jsonb,

  -- perfil profissional e objetivos
  localizacao             VARCHAR(100),
  cargo                   VARCHAR(100),
  area_atuacao            VARCHAR(100),
  info_pessoais           TEXT,
  objetivo_principal      VARCHAR(100),
  tipo_servico            VARCHAR(50),
  uso_ia                  BOOLEAN,
  necessidade_automacao   VARCHAR(100),
  meta_proximos_meses     BIGINT,
  motivacao               TEXT,
  score_qualificacao      INTEGER,

  -- aquisição & tracking de anúncios
  origem_trafego          VARCHAR(50),
  utm_params              JSONB        NOT NULL DEFAULT '{}'::jsonb,
  ctwa_clid               VARCHAR(100),
  ads_url                 TEXT,
  ad_anuncio              VARCHAR(100),
  ad_conjunto             VARCHAR(100),
  cta                     VARCHAR(50),
  referral_code           VARCHAR(50),

  -- conversão & compras
  status                  VARCHAR(50),
  data_compra             DATE,
  id_compra               VARCHAR(50),
  purchase_count          INTEGER      NOT NULL DEFAULT 0,
  total_spent             NUMERIC(12,2) NOT NULL DEFAULT 0,

  -- jornada interna & cadência
  estagio_jornada         VARCHAR(50),
  estagio_conversacao     VARCHAR(50),
  comprou_via             VARCHAR(50),
  temperatura_lead        VARCHAR(50),
  nivel_conhecimento_ia   VARCHAR(50),
  nivel_consciencia       VARCHAR(50),
  engajamento_evento      VARCHAR(50),
  intencao_aplicar_ia     VARCHAR(50),
  area_aplicacao          TEXT,
  expectativa_imersao     TEXT,

  -- históricos em JSONB (arrays de objetos)
  kanban                  JSONB        NOT NULL DEFAULT '[]'::jsonb,  -- { data, kanban }
  ads                     JSONB        NOT NULL DEFAULT '[]'::jsonb,  -- { data, anuncio }
  rotas                   JSONB        NOT NULL DEFAULT '[]'::jsonb,  -- { data, anuncio }
  calls                   JSONB        NOT NULL DEFAULT '[]'::jsonb,  -- { join_time, leave_time, call_id, call_name }
  grupos                  JSONB        NOT NULL DEFAULT '[]'::jsonb,  -- { joined_at, left_at, group_id, group_name }

  -- cadência avançada & scoring
  last_contacted_at       TIMESTAMPTZ,
  next_followup_at        TIMESTAMPTZ,
  lead_score              INTEGER,
  preferred_channel       VARCHAR(20),

  -- segmentação & pós-venda
  tags                    TEXT[]       NOT NULL DEFAULT '{}',
  newsletter_opt_in       BOOLEAN      NOT NULL DEFAULT FALSE,
  possivel_interesse      JSONB        NOT NULL DEFAULT '[]'::jsonb,
  nivel_ceticismo         VARCHAR(50),
  comportamento_compra    VARCHAR(100),
  resumo_geral            TEXT,
  sinais_positivos        JSONB        NOT NULL DEFAULT '[]'::jsonb,
  sinais_negativos        JSONB        NOT NULL DEFAULT '[]'::jsonb,
  recomendacoes_followup  JSONB        NOT NULL DEFAULT '[]'::jsonb
);

-- 3) Tabela de eventos: fonte de verdade de cada interação
CREATE TABLE public.lead_events (
  event_id    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id     UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  event_type  TEXT        NOT NULL,    -- 'kanban' | 'ad' | 'rota' | 'call' | 'group' | 'purchase' | 'nps'
  event_key   TEXT        NOT NULL,    -- ex: 'comprou', 'banner_topo', 'curtiu_instagram'
  event_time  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata    JSONB       NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_lead_events_lead_id       ON public.lead_events(lead_id);
CREATE INDEX IF NOT EXISTS idx_lead_events_type_time     ON public.lead_events(event_type, event_time);

-- 4) Tabela de NPS para pós-venda
CREATE TABLE public.lead_nps (
  nps_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id      UUID        NOT NULL REFERENCES public.leads(id) ON DELETE CASCADE,
  score        INTEGER     NOT NULL CHECK (score BETWEEN 0 AND 10),
  feedback     TEXT,
  responded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lead_nps_lead_id ON public.lead_nps(lead_id);

-- 5) Funções e triggers para sincronizar eventos e notificar
-- 5.1) Função de sincronização em JSONB e métricas
CREATE OR REPLACE FUNCTION public.sync_lead_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  target_col TEXT;
  key_field  TEXT;
BEGIN
  CASE NEW.event_type
    WHEN 'kanban'   THEN target_col := 'kanban';      key_field := 'kanban';
    WHEN 'ad'       THEN target_col := 'ads';         key_field := 'anuncio';
    WHEN 'rota'     THEN target_col := 'rotas';       key_field := 'anuncio';
    WHEN 'call'     THEN target_col := 'calls';       key_field := 'call_name';
    WHEN 'group'    THEN target_col := 'grupos';      key_field := 'group_name';
    WHEN 'purchase' THEN
      UPDATE public.leads
         SET purchase_count = purchase_count + 1,
             total_spent    = total_spent + COALESCE((NEW.metadata->>'value')::NUMERIC, 0)
       WHERE id = NEW.lead_id;
      RETURN NEW;
    WHEN 'nps'      THEN
      INSERT INTO public.lead_nps(lead_id, score, feedback, responded_at)
      VALUES (
        NEW.lead_id,
        (NEW.metadata->>'score')::INTEGER,
        NEW.metadata->>'feedback',
        NEW.event_time
      );
      RETURN NEW;
    ELSE
      RETURN NEW;
  END CASE;

  EXECUTE format(
    'UPDATE public.leads
       SET %I = %I || jsonb_build_array(
         jsonb_build_object(
           ''data'', NEW.event_time::TEXT,
           ''%s'', NEW.event_key
         )
       )
     WHERE id = $1',
    target_col, target_col, key_field
  )
  USING NEW.lead_id;

  UPDATE public.leads
    SET last_contacted_at = NEW.event_time
    WHERE id = NEW.lead_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_lead_event ON public.lead_events;
CREATE TRIGGER trg_sync_lead_event
  AFTER INSERT ON public.lead_events
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_lead_event();

-- 5.2) Função de notificação via LISTEN/NOTIFY
CREATE OR REPLACE FUNCTION public.notify_lead_event()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  PERFORM pg_notify(
    'lead_event_channel',
    row_to_json(NEW)::text
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_lead_event ON public.lead_events;
CREATE TRIGGER trg_notify_lead_event
  AFTER INSERT ON public.lead_events
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_lead_event();
