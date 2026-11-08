-- Q1: a customer's 10 most recent orders (account page)
SELECT order_id, order_date, status, total_amount
FROM orders WHERE customer_id = 123
ORDER BY order_date DESC LIMIT 10;

-- Q2: monthly revenue by channel for 2025 (management report)
SELECT date_trunc('month', order_date)::date AS month, channel, SUM(total_amount) AS revenue
FROM orders
WHERE status = 'Completed' AND order_date >= '2025-01-01' AND order_date < '2026-01-01'
GROUP BY month, channel ORDER BY month, channel;

-- Q3: top 10 products by revenue in the last 2 weeks
SELECT p.name, SUM(oi.quantity * oi.unit_price) AS revenue
FROM order_items oi
JOIN orders o   ON o.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'Completed' AND o.order_date >= '2026-10-11'
GROUP BY p.name ORDER BY revenue DESC LIMIT 10;

-- Q4: payments for one order (cashier reconciliation)
SELECT * FROM payments WHERE order_id = 129825;   

-- Q5: units sold of one product (product detail page)
SELECT SUM(quantity) AS units_sold FROM order_items WHERE product_id = 17;

-- Q6: top 3 customers by spend within each channel (window function)
SELECT * FROM (
  SELECT channel, customer_id, SUM(total_amount) AS spend,
         RANK() OVER (PARTITION BY channel ORDER BY SUM(total_amount) DESC) AS rnk
  FROM orders WHERE status = 'Completed'
  GROUP BY channel, customer_id) t
WHERE rnk <= 3 ORDER BY channel, rnk;