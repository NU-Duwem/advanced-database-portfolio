-- CHECK 1: the partitions and their ranges
SELECT inhrelid::regclass AS partition,
       pg_get_expr(c.relpartbound, c.oid) AS bounds
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
WHERE i.inhparent = 'orders_p'::regclass
ORDER BY 1;

-- CHECK 2: rows per partition
SELECT tableoid::regclass AS partition, count(*) AS orders
FROM orders_p GROUP BY 1 ORDER BY 1;

-- CHECK 3: the copy matches the original (both columns should be true)
SELECT (SELECT count(*) FROM orders_p) = (SELECT count(*) FROM orders) AS same_count,
       (SELECT sum(total_amount) FROM orders_p) = (SELECT sum(total_amount) FROM orders) AS same_total;

-- DEMO 1: partition pruning. A one-month query scans only one partition.
EXPLAIN (ANALYZE)
SELECT count(*), sum(total_amount) FROM orders_p
WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01';

-- DEMO 2: the same query on the ordinary table, for comparison
EXPLAIN (ANALYZE)
SELECT count(*), sum(total_amount) FROM orders
WHERE order_date >= '2025-03-01' AND order_date < '2025-04-01';

-- DEMO 3: without a date filter, every partition is scanned
EXPLAIN SELECT count(*) FROM orders_p;

-- DEMO 4: a row outside every quarterly range lands in the default partition.
-- order_id must be given explicitly because the copy has no identity column.
INSERT INTO orders_p (order_id, customer_id, order_date, channel, status, total_amount)
VALUES (900000001, 1, '2030-05-05', 'online', 'Pending', 1000);

SELECT tableoid::regclass AS partition, order_id, order_date
FROM orders_p WHERE order_id = 900000001;

DELETE FROM orders_p WHERE order_id = 900000001;   -- clean up the test row

-- DEMO 5: one index on the partitioned table creates an index on every partition
CREATE INDEX idx_orders_p_customer ON orders_p (customer_id);

SELECT count(*) AS partition_indexes
FROM pg_indexes
WHERE tablename LIKE 'orders_p_%' AND indexdef LIKE '%customer_id%';

EXPLAIN (ANALYZE, COSTS OFF)
SELECT count(*) FROM orders_p
WHERE customer_id = 123 AND order_date >= '2025-03-01' AND order_date < '2025-04-01';

-- DEMO 6: archiving. Detaching a quarter is instant; it becomes a standalone table.
ALTER TABLE orders_p DETACH PARTITION orders_p_2024q4;
SELECT count(*) AS after_detach FROM orders_p;

ALTER TABLE orders_p ATTACH PARTITION orders_p_2024q4
  FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');
SELECT count(*) AS after_attach FROM orders_p;