-- INDEX 1 (Q1): customer order history.
-- Equality on customer_id plus ORDER BY order_date DESC are both served by one index.
CREATE INDEX idx_orders_customer_date ON orders (customer_id, order_date DESC);
-- Then run on its own:  VACUUM ANALYZE orders;

-- INDEX 2 (Q4): payment lookup by order.
-- PostgreSQL does not create indexes on foreign keys automatically.
CREATE INDEX idx_payments_order ON payments (order_id);
-- Then run on its own:  VACUUM ANALYZE payments;

-- INDEX 3 (Q5): units sold per product.
-- INCLUDE stores quantity in the index, so the query can use an Index Only Scan.
CREATE INDEX idx_items_product ON order_items (product_id) INCLUDE (quantity);
-- Then run on its own:  VACUUM ANALYZE order_items;

-- INDEX 4 (Q2): date-range report. Expect only a small gain (the query reads about half the table).
CREATE INDEX idx_orders_date ON orders (order_date) INCLUDE (status, channel, total_amount);
-- Then run on its own:  VACUUM ANALYZE orders;

-- INDEX 5 (Q3): lines for an order, covering the columns the query needs.
CREATE INDEX idx_items_order_cover ON order_items (order_id) INCLUDE (product_id, quantity, unit_price);
-- Then run on its own:  VACUUM ANALYZE order_items;

-- MATERIALIZED VIEW (Q2): pre-aggregated monthly revenue.
-- Only as fresh as the last REFRESH MATERIALIZED VIEW mv_monthly_revenue;
CREATE MATERIALIZED VIEW mv_monthly_revenue AS
SELECT date_trunc('month', order_date)::date AS month, channel, SUM(total_amount) AS revenue
FROM orders
WHERE status = 'Completed'
GROUP BY 1, 2;

ANALYZE mv_monthly_revenue;