-- 03_queries_test.sql
-- Exact answers for the Stage 3 views and functions over the seed data.

-- Recursive CTE ----------------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT path FROM shop.category_paths WHERE name = 'Databases'),
  'Books > Programming > Databases', 'category path is built root to leaf');

SELECT pg_temp.assert_eq(
  (SELECT max(depth) FROM shop.category_paths), 3, 'deepest category is level 3');

SELECT pg_temp.assert_eq(
  (SELECT string_agg(path || '=' || revenue, '; ' ORDER BY path) FROM shop.category_revenue),
  'Books=288.00; Books > Fiction=37.00; Books > Programming=251.00; '
  || 'Books > Programming > Databases=209.00; Electronics=218.00; Electronics > Audio=218.00',
  'revenue rolls up through the category tree');

-- Joins and aggregates ---------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT sum(order_total) FROM shop.order_totals WHERE status IN ('paid', 'shipped')),
  506.00, 'paid and shipped revenue');

SELECT pg_temp.assert_eq(
  (SELECT string_agg(c.full_name, ',')
     FROM shop.customers c
    WHERE NOT EXISTS (SELECT FROM shop.orders o WHERE o.customer_id = c.customer_id)),
  'Barbara Liskov', 'anti-join finds customers without orders');

SELECT pg_temp.assert_eq(
  (SELECT count(*) FILTER (WHERE status = 'cancelled') FROM shop.orders),
  1::bigint, 'FILTER counts one cancelled order');

-- Window functions -------------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT array_agg(h.running_total ORDER BY h.order_seq)
     FROM shop.customer_order_history h
     JOIN shop.customers c USING (customer_id)
    WHERE c.email = 'edgar@example.com'),
  ARRAY[179.00, 214.00]::numeric[], 'running total per customer');

SELECT pg_temp.assert_eq(
  (SELECT h.previous_total
     FROM shop.customer_order_history h
     JOIN shop.customers c USING (customer_id)
    WHERE c.email = 'ada@example.com' AND h.order_seq = 2),
  119.00, 'lag() returns the previous order total');

SELECT pg_temp.assert_eq(
  (SELECT array_agg(order_total ORDER BY overall_rank) FROM shop.customer_order_history),
  ARRAY[179.00, 129.00, 119.00, 79.00, 35.00]::numeric[], 'dense_rank() orders all totals');

-- ROLLUP -----------------------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT revenue FROM shop.revenue_rollup WHERE grouping_level = 3),
  506.00, 'ROLLUP grand total');

SELECT pg_temp.assert_eq(
  (SELECT string_agg(country || '=' || revenue, ',' ORDER BY country)
     FROM shop.revenue_rollup WHERE grouping_level = 1),
  'GB=248.00,US=258.00', 'ROLLUP country subtotals');

SELECT pg_temp.assert_eq(
  (SELECT revenue FROM shop.revenue_rollup
    WHERE country = 'US' AND month = date '2026-01-01'),
  79.00, 'ROLLUP detail row for US, January');

-- LATERAL top-N ----------------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT string_agg(category_name || ':' || product_sku || ':' || units_sold, ','
                     ORDER BY category_name)
     FROM shop.top_products(1)),
  'Audio:EL-HP-005:1,Databases:BK-PG-001:3,Fiction:BK-FIC-004:2,Programming:BK-GO-003:1',
  'LATERAL returns the best seller per category');

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM shop.top_products(5) WHERE category_name = 'Databases'),
  2::bigint, 'LATERAL LIMIT is applied per category');

-- Ranges -----------------------------------------------------------------
SELECT pg_temp.assert_eq(
  shop.price_at((SELECT product_id FROM shop.products WHERE sku = 'BK-PG-001'),
                '2026-03-15 12:00+00'),
  39.20, 'promotion price inside the range');

SELECT pg_temp.assert_eq(
  shop.price_at((SELECT product_id FROM shop.products WHERE sku = 'BK-PG-001'),
                '2026-03-31 00:00+00'),
  49.00, 'upper bound of a half-open range is excluded');

-- JSONB and arrays -------------------------------------------------------
SELECT pg_temp.assert_eq(
  (SELECT sku FROM shop.products WHERE attributes @> '{"wireless": true}'),
  'EL-SP-006', 'jsonb containment @>');

SELECT pg_temp.assert_eq(
  (SELECT sku FROM shop.products WHERE attributes ->> 'format' = 'ebook'),
  'BK-SQL-002', 'jsonb ->> extracts text');

SELECT pg_temp.assert_eq(
  (SELECT sku FROM shop.products WHERE attributes @? '$.pages ? (@ > 400)'),
  'BK-PG-001', 'jsonpath filter on a number');

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM shop.products WHERE tags && ARRAY['audio']),
  2::bigint, 'array overlap &&');

-- Upsert -----------------------------------------------------------------
BEGIN;
INSERT INTO shop.products (category_id, sku, title, price)
SELECT category_id, 'BK-PG-001', 'PostgreSQL Internals, 2nd ed.', 55.00
FROM shop.products WHERE sku = 'BK-PG-001'
ON CONFLICT (sku) DO UPDATE SET title = EXCLUDED.title, price = EXCLUDED.price;

SELECT pg_temp.assert_eq(
  (SELECT price FROM shop.products WHERE sku = 'BK-PG-001'),
  55.00, 'ON CONFLICT DO UPDATE changed the existing row');
SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM shop.products), 6::bigint, 'upsert did not add a row');
ROLLBACK;
