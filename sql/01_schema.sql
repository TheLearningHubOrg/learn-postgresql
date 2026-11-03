-- 01_schema.sql
-- Tables, types and constraints for a small online shop.
-- Every object is created by shop_owner so that ownership and default
-- privileges from 00_roles_and_schema.sql apply.
SET ROLE shop_owner;

-- An ENUM is a closed, ordered set of labels stored in 4 bytes.
CREATE TYPE shop.order_status AS ENUM ('pending', 'paid', 'shipped', 'cancelled');

-- A DOMAIN is a base type plus constraints, reusable across tables.
CREATE DOMAIN shop.email AS text
  CHECK (VALUE ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

-- Self-referencing tree: parent_id is NULL for top-level categories.
CREATE TABLE shop.categories (
  category_id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_id   integer REFERENCES shop.categories (category_id) ON DELETE RESTRICT,
  name        text    NOT NULL CHECK (name <> ''),
  -- NULLS NOT DISTINCT (PostgreSQL 15+) makes two top-level rows with the
  -- same name collide, which a plain UNIQUE would allow.
  CONSTRAINT categories_parent_name_key UNIQUE NULLS NOT DISTINCT (parent_id, name)
);

CREATE TABLE shop.customers (
  customer_id bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  public_id   uuid        NOT NULL DEFAULT uuidv7() UNIQUE,  -- uuidv7(): PostgreSQL 18+
  email       shop.email  NOT NULL,
  full_name   text        NOT NULL CHECK (btrim(full_name) <> ''),
  country     char(2)     NOT NULL CHECK (country ~ '^[A-Z]{2}$'),
  created_at  timestamptz NOT NULL DEFAULT now()
);
-- Case-insensitive uniqueness through an expression index.
CREATE UNIQUE INDEX customers_email_lower_key ON shop.customers (lower(email));

CREATE TABLE shop.products (
  product_id  integer       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id integer       NOT NULL REFERENCES shop.categories,
  sku         text          NOT NULL UNIQUE CHECK (sku ~ '^[A-Z0-9-]{4,32}$'),
  title       text          NOT NULL,
  price       numeric(10,2) NOT NULL CHECK (price >= 0),
  tags        text[]        NOT NULL DEFAULT '{}',
  attributes  jsonb         NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(attributes) = 'object'),
  created_at  timestamptz   NOT NULL DEFAULT now()
);
CREATE INDEX products_category_id_idx ON shop.products (category_id);
CREATE INDEX products_tags_gin ON shop.products USING gin (tags);
CREATE INDEX products_attributes_gin ON shop.products USING gin (attributes jsonb_path_ops);

CREATE TABLE shop.orders (
  order_id    bigint            GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint            NOT NULL REFERENCES shop.customers ON DELETE RESTRICT,
  status      shop.order_status NOT NULL DEFAULT 'pending',
  ordered_at  timestamptz       NOT NULL DEFAULT now(),
  shipped_at  timestamptz,
  CONSTRAINT orders_shipped_after_ordered CHECK (shipped_at >= ordered_at),
  -- A shipped order has a ship date, and only a shipped order has one.
  CONSTRAINT orders_shipped_has_date CHECK ((status = 'shipped') = (shipped_at IS NOT NULL))
);
-- PostgreSQL does not index foreign-key columns for you.
CREATE INDEX orders_customer_id_idx ON shop.orders (customer_id);

CREATE TABLE shop.order_items (
  order_id   bigint        NOT NULL REFERENCES shop.orders ON DELETE CASCADE,
  product_id integer       NOT NULL REFERENCES shop.products,
  quantity   integer       NOT NULL CHECK (quantity > 0),
  unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0),
  line_total numeric(12,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  PRIMARY KEY (order_id, product_id)
);
CREATE INDEX order_items_product_id_idx ON shop.order_items (product_id);

CREATE TABLE shop.promotions (
  promotion_id  integer      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id    integer      NOT NULL REFERENCES shop.products ON DELETE CASCADE,
  percent_off   numeric(5,2) NOT NULL CHECK (percent_off > 0 AND percent_off < 100),
  active_during tstzrange    NOT NULL CHECK (NOT isempty(active_during)),
  -- Two promotions for the same product may not overlap in time.
  CONSTRAINT promotions_no_overlap
    EXCLUDE USING gist (product_id WITH =, active_during WITH &&)
);

COMMENT ON TABLE shop.order_items IS 'One row per product in an order; line_total is computed';
COMMENT ON CONSTRAINT promotions_no_overlap ON shop.promotions
  IS 'Half-open ranges [start, end) let back-to-back promotions touch without overlapping';

RESET ROLE;
