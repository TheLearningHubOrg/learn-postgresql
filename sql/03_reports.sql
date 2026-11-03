-- 03_reports.sql
-- Views and SQL functions that exercise Stage 3: recursive CTEs, window
-- functions, LATERAL joins and ROLLUP.
SET ROLE shop_owner;

-- Full path of every category, e.g. 'Books > Programming > Databases'.
-- CYCLE (PostgreSQL 14+) stops the recursion if bad data ever forms a loop.
CREATE VIEW shop.category_paths AS
WITH RECURSIVE tree AS (
  SELECT category_id, parent_id, name, 1 AS depth, name AS path
  FROM shop.categories
  WHERE parent_id IS NULL
  UNION ALL
  SELECT c.category_id, c.parent_id, c.name, t.depth + 1, t.path || ' > ' || c.name
  FROM shop.categories c
  JOIN tree t ON c.parent_id = t.category_id
) CYCLE category_id SET is_cycle USING visited
SELECT category_id, parent_id, name, depth, path
FROM tree
WHERE NOT is_cycle;

-- One row per order with its total. GROUP BY the primary key lets the
-- other orders columns appear in the select list (functional dependency).
CREATE VIEW shop.order_totals AS
SELECT o.order_id, o.customer_id, o.status, o.ordered_at,
       sum(oi.line_total)::numeric(12,2) AS order_total
FROM shop.orders o
JOIN shop.order_items oi USING (order_id)
GROUP BY o.order_id;

-- Revenue (paid + shipped) per category, including all descendant categories.
CREATE VIEW shop.category_revenue AS
WITH RECURSIVE ancestry AS (
  -- every category is its own ancestor ...
  SELECT category_id AS leaf_id, category_id AS ancestor_id
  FROM shop.categories
  UNION ALL
  -- ... and so is every category above it
  SELECT a.leaf_id, c.parent_id
  FROM ancestry a
  JOIN shop.categories c ON c.category_id = a.ancestor_id
  WHERE c.parent_id IS NOT NULL
),
sales AS (
  SELECT p.category_id, sum(oi.line_total) AS revenue
  FROM shop.order_items oi
  JOIN shop.orders o   USING (order_id)
  JOIN shop.products p USING (product_id)
  WHERE o.status IN ('paid', 'shipped')
  GROUP BY p.category_id
)
SELECT cp.category_id, cp.path, coalesce(sum(s.revenue), 0)::numeric(12,2) AS revenue
FROM shop.category_paths cp
LEFT JOIN ancestry a ON a.ancestor_id = cp.category_id
LEFT JOIN sales s    ON s.category_id = a.leaf_id
GROUP BY cp.category_id, cp.path;

-- Per-customer order history with window functions. Cancelled orders are out.
CREATE VIEW shop.customer_order_history AS
SELECT t.customer_id,
       t.order_id,
       t.ordered_at,
       t.order_total,
       row_number()       OVER w AS order_seq,
       sum(t.order_total) OVER (w ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_total,
       lag(t.order_total) OVER w AS previous_total,
       dense_rank()       OVER (ORDER BY t.order_total DESC) AS overall_rank
FROM shop.order_totals t
WHERE t.status <> 'cancelled'
WINDOW w AS (PARTITION BY t.customer_id ORDER BY t.ordered_at);

-- Revenue by country and month with subtotals. grouping_level is a bitmask:
-- 0 = detail row, 1 = country subtotal, 3 = grand total.
CREATE VIEW shop.revenue_rollup AS
WITH paid AS (
  SELECT c.country,
         date_trunc('month', t.ordered_at AT TIME ZONE 'UTC')::date AS month,
         t.order_total
  FROM shop.order_totals t
  JOIN shop.customers c USING (customer_id)
  WHERE t.status IN ('paid', 'shipped')
)
SELECT country, month,
       GROUPING(country, month) AS grouping_level,
       sum(order_total)::numeric(12,2) AS revenue
FROM paid
GROUP BY ROLLUP (country, month);

-- Top N products per category by units sold: the LATERAL subquery runs once
-- per category row and may reference c.category_id.
CREATE FUNCTION shop.top_products(per_category integer)
RETURNS TABLE (category_name text, product_sku text, units_sold bigint)
LANGUAGE sql STABLE
BEGIN ATOMIC
  SELECT c.name, top.sku, top.qty
  FROM shop.categories c
  CROSS JOIN LATERAL (
    SELECT p.sku, sum(oi.quantity) AS qty
    FROM shop.products p
    JOIN shop.order_items oi ON oi.product_id = p.product_id
    JOIN shop.orders o       ON o.order_id = oi.order_id
    WHERE p.category_id = c.category_id
      AND o.status IN ('paid', 'shipped')
    GROUP BY p.sku
    ORDER BY qty DESC, p.sku
    LIMIT per_category
  ) AS top
  ORDER BY c.name, top.qty DESC, top.sku;
END;

-- Price of a product at a point in time, after any active promotion.
-- tstzrange @> timestamptz is true for lower <= t < upper (half-open).
CREATE FUNCTION shop.price_at(p_product_id integer, p_at timestamptz)
RETURNS numeric
LANGUAGE sql STABLE
RETURN (
  SELECT round(p.price * (1 - coalesce(pr.percent_off, 0) / 100), 2)
  FROM shop.products p
  LEFT JOIN shop.promotions pr
         ON pr.product_id = p.product_id
        AND pr.active_during @> p_at
  WHERE p.product_id = p_product_id
);

RESET ROLE;
