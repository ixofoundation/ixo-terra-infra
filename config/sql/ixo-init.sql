\c blocksync-core
GRANT CREATE ON SCHEMA "public" TO "blocksync-core";

\c blocksync-core_alt
GRANT CREATE ON SCHEMA "public" to "blocksync-core";

\c cellnode
GRANT CREATE ON SCHEMA "public" TO "cellnode";

\c blocksync
GRANT CREATE ON SCHEMA "public" to "blocksync";

\c blocksync_alt
GRANT CREATE ON SCHEMA "public" to "blocksync";

\c deeplink
GRANT CREATE ON SCHEMA "public" to "deeplink";

\c 'coin-server'
GRANT CREATE ON SCHEMA "public" to "coin-server";

\c faq-assistant
GRANT CREATE ON SCHEMA "public" to "faq-assistant";

\c whizz
GRANT CREATE ON SCHEMA "public" to "whizz";

\c kyc
GRANT CREATE ON SCHEMA "public" to "kyc";

\c 'iot-data'
GRANT CREATE ON SCHEMA "public" to "iot-data";

\c 'notification-server'
GRANT CREATE ON SCHEMA "public" to "notification-server";

\c 'trading-bot-server'
GRANT CREATE ON SCHEMA "public" to "trading-bot-server";

\c 'payments-nest'
GRANT CREATE ON SCHEMA "public" to "payments-nest";

\c 'message-relayer'
GRANT CREATE ON SCHEMA "public" to "message-relayer";

\c 'subscriptions-oracle-bot'
GRANT CREATE ON SCHEMA "public" to "subscriptions-oracle-bot";

\c 'observable-framework-builder'
GRANT CREATE ON SCHEMA "public" to "observable-framework-builder";

\c 'pathgen-oracle'
GRANT CREATE ON SCHEMA "public" to "pathgen-oracle";

\c 'jokes-oracle'
GRANT CREATE ON SCHEMA "public" to "jokes-oracle";

\c 'supamoto-bot'
GRANT CREATE ON SCHEMA "public" to "supamoto-bot";

\c 'supamoto-claims-bot'
GRANT CREATE ON SCHEMA "public" to "supamoto-claims-bot";

\c firecrawl
GRANT CREATE ON SCHEMA "public" to "firecrawl";
-- NUQ Queue System: For existing databases, run config/sql/firecrawl-nuq.sql manually:
-- kubectl exec -n ixo-postgres <pod-name> -c database -- psql -U firecrawl -d firecrawl -f /path/to/firecrawl-nuq.sql

\c 'ussd-supamoto'
GRANT CREATE ON SCHEMA "public" TO "ussd-supamoto";

\c 'feegrant-nest'
GRANT CREATE ON SCHEMA "public" TO "feegrant-nest";

-- Read-only role for ixo-blocksync-api's optional "core" pg service (the
-- `coreEventCores` connection) and other raw-chain-event consumers
-- (domain-indexer, billing engine, email-notifier). Codified here so a
-- cluster rebuild restores it — it previously existed only as a manually
-- created role (grants applied to all three live clusters on 2026-08-27).
--
-- The LOGIN password is managed outside terraform: after a rebuild, set it
-- to match the CORE_DATABASE_URL entries in the Vault `ixo-blocksync` secret:
--   ALTER ROLE blocksync_core_read WITH PASSWORD '<from Vault>';
--
-- The ALTER DEFAULT PRIVILEGES lines are the load-bearing part: tables are
-- created later by ixo-blocksync-core's migrations (as "blocksync-core"),
-- and without them every migration-created table would be invisible to the
-- read role — PostGraphile (ignoreRBAC: false) then silently omits such
-- tables from the GraphQL schema.
\c blocksync-core
DO $$ BEGIN CREATE ROLE blocksync_core_read LOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
GRANT SELECT ON ALL TABLES IN SCHEMA "public" TO blocksync_core_read;
ALTER DEFAULT PRIVILEGES FOR ROLE "blocksync-core" IN SCHEMA "public" GRANT SELECT ON TABLES TO blocksync_core_read;

\c blocksync-core_alt
GRANT SELECT ON ALL TABLES IN SCHEMA "public" TO blocksync_core_read;
ALTER DEFAULT PRIVILEGES FOR ROLE "blocksync-core" IN SCHEMA "public" GRANT SELECT ON TABLES TO blocksync_core_read;