-- 02_constraints_test.sql
-- Each bad write must fail with the SQLSTATE a client would branch on.
-- The whole file runs in one transaction that is rolled back at the end.
BEGIN;

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.products (category_id, sku, title, price)
    SELECT category_id, 'BK-NEG-100', 'Negative', -1 FROM shop.categories LIMIT 1$$,
  '23514', 'CHECK rejects a negative price');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.products (category_id, sku, title, price)
    SELECT category_id, 'BK-PG-001', 'Duplicate', 1 FROM shop.categories LIMIT 1$$,
  '23505', 'UNIQUE rejects a duplicate SKU');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.products (category_id, sku, title, price)
    SELECT category_id, 'bad sku', 'Lowercase', 1 FROM shop.categories LIMIT 1$$,
  '23514', 'CHECK rejects a SKU that fails the pattern');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.products (category_id, sku, title, price, attributes)
    SELECT category_id, 'BK-ARR-101', 'Array', 1, '[1, 2]' FROM shop.categories LIMIT 1$$,
  '23514', 'CHECK requires attributes to be a JSON object');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.customers (email, full_name, country)
    VALUES ('ADA@example.com', 'Ada Again', 'GB')$$,
  '23505', 'expression index makes email unique ignoring case');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.customers (email, full_name, country)
    VALUES ('not-an-email', 'Nobody', 'US')$$,
  '23514', 'the email DOMAIN rejects a malformed address');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.customers (email, full_name, country)
    VALUES ('x@example.com', NULL, 'US')$$,
  '23502', 'NOT NULL rejects a missing name');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.customers (email, full_name, country)
    VALUES ('y@example.com', 'Lower Country', 'us')$$,
  '23514', 'CHECK requires an upper-case ISO country code');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.orders (customer_id) VALUES (999999)$$,
  '23503', 'FOREIGN KEY rejects an unknown customer');

SELECT pg_temp.expect_error(
  $$DELETE FROM shop.customers WHERE email = 'ada@example.com'$$,
  '23001', 'ON DELETE RESTRICT keeps customers that have orders');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.orders (customer_id, status)
    SELECT customer_id, 'shipped' FROM shop.customers LIMIT 1$$,
  '23514', 'a shipped order needs shipped_at');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.orders (customer_id, status)
    SELECT customer_id, 'refunded' FROM shop.customers LIMIT 1$$,
  '22P02', 'ENUM rejects an unknown status label');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.orders (order_id, customer_id)
    SELECT 1, customer_id FROM shop.customers LIMIT 1$$,
  '428C9', 'GENERATED ALWAYS identity rejects an explicit id');

SELECT pg_temp.expect_error(
  $$UPDATE shop.order_items SET line_total = 0$$,
  '428C9', 'a generated column cannot be written');

SELECT pg_temp.expect_error(
  $$UPDATE shop.order_items SET quantity = 0$$,
  '23514', 'CHECK rejects a zero quantity');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.categories (name) VALUES ('Books')$$,
  '23505', 'UNIQUE NULLS NOT DISTINCT blocks a second top-level Books');

SELECT pg_temp.expect_error(
  $$INSERT INTO shop.promotions (product_id, percent_off, active_during)
    SELECT product_id, 5, tstzrange('2026-03-15 00:00+00', '2026-04-15 00:00+00')
    FROM shop.products WHERE sku = 'BK-PG-001'$$,
  '23P01', 'EXCLUDE rejects an overlapping promotion');

-- Half-open ranges: a promotion starting exactly when the last one ends is fine.
INSERT INTO shop.promotions (product_id, percent_off, active_during)
SELECT product_id, 5, tstzrange('2026-03-31 00:00+00', '2026-04-30 00:00+00')
FROM shop.products WHERE sku = 'BK-PG-001';

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM shop.promotions p JOIN shop.products USING (product_id)
    WHERE sku = 'BK-PG-001'),
  2::bigint, 'adjacent promotions do not overlap');

-- ON DELETE CASCADE removes the items with their order.
DELETE FROM shop.orders
WHERE order_id = (SELECT min(order_id) FROM shop.orders);

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM shop.order_items
    WHERE order_id NOT IN (SELECT order_id FROM shop.orders)),
  0::bigint, 'ON DELETE CASCADE removed the order items');

ROLLBACK;
