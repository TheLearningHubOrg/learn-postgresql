-- 02_seed.sql
-- Small, fixed data set. The tests in tests/ assert exact numbers against it,
-- so change both together.
SET ROLE shop_owner;

-- Category tree:
--   Books > Programming > Databases
--   Books > Fiction
--   Electronics > Audio
INSERT INTO shop.categories (name) VALUES ('Books'), ('Electronics');

INSERT INTO shop.categories (parent_id, name)
SELECT category_id, child
FROM shop.categories
JOIN (VALUES ('Books', 'Programming'), ('Books', 'Fiction'), ('Electronics', 'Audio'))
  AS v(parent, child) ON v.parent = name;

INSERT INTO shop.categories (parent_id, name)
SELECT category_id, 'Databases' FROM shop.categories WHERE name = 'Programming';

INSERT INTO shop.products (category_id, sku, title, price, tags, attributes)
SELECT c.category_id, v.sku, v.title, v.price, v.tags, v.attributes
FROM (VALUES
  ('Databases',   'BK-PG-001',  'PostgreSQL Internals',      49.00, '{book,databases}'::text[],
     '{"format": "hardcover", "pages": 420}'::jsonb),
  ('Databases',   'BK-SQL-002', 'SQL Window Functions',      35.00, '{book,sql}',
     '{"format": "ebook", "pages": 210}'),
  ('Programming', 'BK-GO-003',  'Systems Programming in Go', 42.00, '{book,go}',
     '{"format": "paperback", "pages": 380}'),
  ('Fiction',     'BK-FIC-004', 'The Quiet Replica',         18.50, '{book,novel}',
     '{"format": "paperback", "pages": 300}'),
  ('Audio',       'EL-HP-005',  'Studio Headphones',        129.00, '{audio,wired}',
     '{"color": "black", "wireless": false}'),
  ('Audio',       'EL-SP-006',  'Bluetooth Speaker',         89.00, '{audio,wireless}',
     '{"color": "blue", "wireless": true}')
) AS v(category, sku, title, price, tags, attributes)
JOIN shop.categories c ON c.name = v.category;

INSERT INTO shop.customers (email, full_name, country) VALUES
  ('ada@example.com',     'Ada Lovelace',   'GB'),
  ('grace@example.com',   'Grace Hopper',   'US'),
  ('edgar@example.com',   'Edgar Codd',     'US'),
  ('barbara@example.com', 'Barbara Liskov', 'US');   -- has no orders on purpose

INSERT INTO shop.orders (customer_id, status, ordered_at, shipped_at)
SELECT c.customer_id, v.status::shop.order_status, v.ordered_at, v.shipped_at
FROM (VALUES
  ('ada@example.com',   'shipped',   timestamptz '2026-01-10 10:00+00', timestamptz '2026-01-12 09:00+00'),
  ('ada@example.com',   'paid',      '2026-02-03 15:30+00', NULL),
  ('grace@example.com', 'shipped',   '2026-01-15 08:00+00', '2026-01-16 08:00+00'),
  ('grace@example.com', 'cancelled', '2026-02-20 12:00+00', NULL),
  ('edgar@example.com', 'paid',      '2026-03-01 18:45+00', NULL),
  ('edgar@example.com', 'pending',   '2026-03-05 07:15+00', NULL)
) AS v(email, status, ordered_at, shipped_at)
JOIN shop.customers c ON c.email = v.email;

INSERT INTO shop.order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, v.quantity, v.unit_price
FROM (VALUES
  ('ada@example.com',   timestamptz '2026-01-10 10:00+00', 'BK-PG-001',  1, 49.00),
  ('ada@example.com',   '2026-01-10 10:00+00',             'BK-SQL-002', 2, 35.00),
  ('ada@example.com',   '2026-02-03 15:30+00',             'EL-HP-005',  1, 129.00),
  ('grace@example.com', '2026-01-15 08:00+00',             'BK-GO-003',  1, 42.00),
  ('grace@example.com', '2026-01-15 08:00+00',             'BK-FIC-004', 2, 18.50),
  ('grace@example.com', '2026-02-20 12:00+00',             'EL-SP-006',  1, 89.00),
  ('edgar@example.com', '2026-03-01 18:45+00',             'BK-PG-001',  2, 45.00),
  ('edgar@example.com', '2026-03-01 18:45+00',             'EL-SP-006',  1, 89.00),
  ('edgar@example.com', '2026-03-05 07:15+00',             'BK-SQL-002', 1, 35.00)
) AS v(email, ordered_at, sku, quantity, unit_price)
JOIN shop.customers c ON c.email = v.email
JOIN shop.orders o    ON o.customer_id = c.customer_id AND o.ordered_at = v.ordered_at
JOIN shop.products p  ON p.sku = v.sku;

INSERT INTO shop.promotions (product_id, percent_off, active_during)
SELECT p.product_id, v.percent_off, v.active_during
FROM (VALUES
  ('BK-PG-001', 20.00, tstzrange('2026-03-01 00:00+00', '2026-03-31 00:00+00')),
  ('EL-SP-006', 10.00, tstzrange('2026-02-01 00:00+00', '2026-03-01 00:00+00'))
) AS v(sku, percent_off, active_during)
JOIN shop.products p ON p.sku = v.sku;

RESET ROLE;
