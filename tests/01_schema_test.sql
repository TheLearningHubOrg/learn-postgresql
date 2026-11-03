-- 01_schema_test.sql
-- The catalog is queryable SQL: check what 00 and 01 created.

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM information_schema.tables
    WHERE table_schema = 'shop' AND table_type = 'BASE TABLE'),
  6::bigint, 'six base tables in schema shop');

SELECT pg_temp.assert_eq(
  (SELECT count(*) FROM pg_tables WHERE schemaname = 'shop' AND tableowner <> 'shop_owner'),
  0::bigint, 'shop_owner owns every table');

SELECT pg_temp.assert_eq(
  (SELECT string_agg(column_name, ',' ORDER BY column_name)
     FROM information_schema.columns
    WHERE table_schema = 'shop' AND is_identity = 'YES'),
  'category_id,customer_id,order_id,product_id,promotion_id',
  'surrogate keys are identity columns');

SELECT pg_temp.assert_eq(
  (SELECT generation_expression FROM information_schema.columns
    WHERE table_schema = 'shop' AND table_name = 'order_items' AND column_name = 'line_total'),
  '((quantity)::numeric * unit_price)',
  'line_total is a generated column');

SELECT pg_temp.assert_eq(
  (SELECT extname FROM pg_extension WHERE extname = 'btree_gist'),
  'btree_gist'::name, 'btree_gist extension installed');

SELECT pg_temp.assert_eq(
  (SELECT array_agg(enumlabel ORDER BY enumsortorder) FROM pg_enum
    WHERE enumtypid = 'shop.order_status'::regtype),
  ARRAY['pending', 'paid', 'shipped', 'cancelled']::name[],
  'order_status labels are in lifecycle order');

-- Every foreign-key column has an index whose first column is that column.
SELECT pg_temp.assert_eq(
  (SELECT count(*)
     FROM pg_constraint con
    WHERE con.contype = 'f'
      AND con.connamespace = 'shop'::regnamespace
      AND NOT EXISTS (
        SELECT FROM pg_index i
         WHERE i.indrelid = con.conrelid
           AND i.indkey[0] = con.conkey[1])),
  0::bigint, 'every foreign key is backed by an index');

-- Privileges come from ALTER DEFAULT PRIVILEGES in 00_roles_and_schema.sql.
SELECT pg_temp.assert_eq(has_table_privilege('shop_app', 'shop.orders', 'INSERT'),
  true, 'shop_app may insert orders');
SELECT pg_temp.assert_eq(has_table_privilege('shop_readonly', 'shop.orders', 'SELECT'),
  true, 'shop_readonly may read orders');
SELECT pg_temp.assert_eq(has_table_privilege('shop_readonly', 'shop.orders', 'INSERT'),
  false, 'shop_readonly may not insert orders');
SELECT pg_temp.assert_eq(has_schema_privilege('shop_app', 'shop', 'CREATE'),
  false, 'shop_app may not create objects in shop');
