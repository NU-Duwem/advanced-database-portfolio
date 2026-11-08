-- Lilies Pastries: synthetic seed data (simulated business).

TRUNCATE stock_audit, deliveries, payments, order_items, orders, customers,
         inventory, products, expenses RESTART IDENTITY CASCADE;
SELECT setseed(0.42);   -- same random data every run

-- 1. Products: 6 categories x 10 items, prices 500 - 25,000 NGN
INSERT INTO products (name, category, description, price, sku)
SELECT c || ' item ' || g, c, 'Sample ' || lower(c) || ' product',
       round((500 + random() * 24500)::numeric, -1),
       'LP-' || upper(left(c, 3)) || '-' || lpad(g::text, 3, '0')
FROM unnest(ARRAY['Cakes','Pastries','Bread','Cookies','Snacks','Drinks']) AS c,
     generate_series(1, 10) AS g;

-- 2. Inventory: one row per product
INSERT INTO inventory (product_id, quantity_in_stock, reorder_level, last_restocked)
SELECT product_id, 50 + (random() * 450)::int, 20, CURRENT_DATE - (random() * 30)::int
FROM products;

-- 3. Customers: 5,000
INSERT INTO customers (full_name, email, phone, joined_on, loyalty_points)
SELECT 'Customer ' || g, 'customer' || g || '@example.com',
       '080' || lpad((10000000 + g)::text, 8, '0'),
       DATE '2024-01-01' + (random() * 1000)::int, (random() * 500)::int
FROM generate_series(1, 5000) AS g;

-- 4. Orders: 200,000 over the last 2 years. Only the last 2 days can still be Pending.
INSERT INTO orders (customer_id, order_date, channel, status)
SELECT 1 + (random() * 4999)::int, d,
       (ARRAY['walk-in','walk-in','online','phone'])[1 + (random() * 3)::int],
       CASE WHEN d > TIMESTAMP '2026-10-23' THEN 'Pending'
            WHEN random() < 0.05 THEN 'Cancelled' ELSE 'Completed' END
FROM (SELECT TIMESTAMP '2026-10-25' - random() * INTERVAL '730 days' AS d
      FROM generate_series(1, 200000)) AS t;

-- 5. Order items: 1-4 distinct products per order.
-- The product number depends on order_id, line number k and customer_id; since
-- k*17 never repeats modulo 60 for k <= 4, lines within one order never collide.
INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1 + (random() * 3)::int, p.price
FROM orders o
CROSS JOIN LATERAL generate_series(1, 1 + (o.order_id % 4)) AS k
JOIN products p ON p.product_id = 1 + ((o.order_id * 31 + k * 17 + o.customer_id) % 60);

-- 6. Order totals = sum of the lines
UPDATE orders o SET total_amount = s.t
FROM (SELECT order_id, SUM(quantity * unit_price) AS t FROM order_items GROUP BY order_id) s
WHERE s.order_id = o.order_id;

-- 7. Payments for completed orders
INSERT INTO payments (order_id, method, amount, status, paid_at)
SELECT order_id, (ARRAY['cash','card','transfer','pos'])[1 + (random() * 3)::int],
       total_amount, 'success', order_date + INTERVAL '2 minutes'
FROM orders WHERE status = 'Completed' AND total_amount > 0;

-- 8. Deliveries for online orders that were completed
INSERT INTO deliveries (order_id, address, area, rider_name, status, dispatched_at, delivered_at)
SELECT order_id, 'No. ' || (order_id % 99 + 1) || ' Sample Street',
       (ARRAY['Wuse II','Maitama','Garki','Gwarinpa','Jabi','Lugbe'])[1 + (random() * 5)::int],
       'Rider ' || (1 + order_id % 8), 'delivered',
       order_date + INTERVAL '20 minutes', order_date + INTERVAL '65 minutes'
FROM orders WHERE channel = 'online' AND status = 'Completed';

-- 9. Expenses: monthly costs for 24 months
INSERT INTO expenses (category, description, amount, expense_date)
SELECT c, c || ' for ' || to_char(m, 'Mon YYYY'),
       round((50000 + random() * 450000)::numeric, -2), m::date
FROM unnest(ARRAY['Ingredients','Rent','Salaries','Electricity','Packaging']) AS c,
     generate_series(DATE '2024-11-01', DATE '2026-10-01', INTERVAL '1 month') AS m;

ANALYZE;   -- refresh planner statistics (important before EXPLAIN in Portfolio 2)