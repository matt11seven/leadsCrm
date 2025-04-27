-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create leads table
CREATE TABLE IF NOT EXISTS leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    source VARCHAR(100),
    status VARCHAR(50) DEFAULT 'new',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create lead_events table
CREATE TABLE IF NOT EXISTS lead_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create lead_nps table
CREATE TABLE IF NOT EXISTS lead_nps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score >= 0 AND score <= 10),
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger function to track lead events
CREATE OR REPLACE FUNCTION sync_lead_event()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO lead_events (lead_id, event_type, payload)
        VALUES (NEW.id, 'created', row_to_json(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO lead_events (lead_id, event_type, payload)
        VALUES (NEW.id, 'updated', json_build_object(
            'old', row_to_json(OLD),
            'new', row_to_json(NEW)
        ));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO lead_events (lead_id, event_type, payload)
        VALUES (OLD.id, 'deleted', row_to_json(OLD));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to notify about lead events
CREATE OR REPLACE FUNCTION notify_lead_event()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('lead_events', row_to_json(NEW)::text);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER lead_event_sync_trigger
AFTER INSERT OR UPDATE OR DELETE ON leads
FOR EACH ROW EXECUTE FUNCTION sync_lead_event();

CREATE TRIGGER lead_event_notify_trigger
AFTER INSERT ON lead_events
FOR EACH ROW EXECUTE FUNCTION notify_lead_event();
