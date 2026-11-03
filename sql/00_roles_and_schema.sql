-- 00_roles_and_schema.sql
-- Cluster-level roles, the extension the schema needs, and the "shop" schema.
-- Run as a superuser (the official image's POSTGRES_USER, or "postgres").

-- Roles live in the cluster, not in a database, so creation must be idempotent:
-- running the starter against a second database must not fail.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shop_owner') THEN
    CREATE ROLE shop_owner NOLOGIN;      -- owns every object; nobody logs in as it
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shop_app') THEN
    CREATE ROLE shop_app NOLOGIN;        -- read/write group role for the application
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'shop_readonly') THEN
    CREATE ROLE shop_readonly NOLOGIN;   -- reporting and support access
  END IF;
END
$$;

-- btree_gist adds GiST operator classes for scalar types, so an EXCLUDE
-- constraint can combine "product_id WITH =" and "active_during WITH &&".
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS shop AUTHORIZATION shop_owner;
COMMENT ON SCHEMA shop IS 'Starter project for the learn-postgresql guide (Stages 1-3)';

-- Nobody but the owner creates objects in shop.
REVOKE ALL ON SCHEMA shop FROM PUBLIC;
GRANT USAGE ON SCHEMA shop TO shop_app, shop_readonly;

-- Default privileges apply to objects shop_owner creates later in this schema.
ALTER DEFAULT PRIVILEGES FOR ROLE shop_owner IN SCHEMA shop
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO shop_app;
ALTER DEFAULT PRIVILEGES FOR ROLE shop_owner IN SCHEMA shop
  GRANT SELECT ON TABLES TO shop_readonly;
