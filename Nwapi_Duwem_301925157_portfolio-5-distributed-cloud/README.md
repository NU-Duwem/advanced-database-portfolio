# Portfolio 5: Distributed and Cloud Database Exercise

## Goal

Discuss how the Lilies Pastries database would be distributed and deployed in the cloud as the business grows, and demonstrate one distribution technique, table partitioning, on my own PostgreSQL database.

## Files

- `01_partitioning.sql`: builds a date-partitioned copy of `orders` and loads it
- `02_checks_and_demos.sql`: checks, pruning demonstration, and extra demonstrations

## How to run

1. Load the schema and seed data from Portfolio 1.
2. Check the date range of the orders (`SELECT min(order_date), max(order_date) FROM orders;`) and make sure the partition ranges in `01_partitioning.sql` cover it.
3. Run `01_partitioning.sql` as a whole.
4. Run the statements in `02_checks_and_demos.sql` one at a time.

## Scenario

Lilies Pastries is a bakery with walk-in, phone and online orders. Today one database serves one shop. The scenario for this discussion is growth to several outlets across Abuja and Lagos, an online channel with weekend and December peaks, and customers who expect the system to be available whenever they order.

## What I implemented and what I only discussed

- **Implemented and tested:** range partitioning of `orders` by date in PostgreSQL.
- **Discussed only:** replication, sharding, failover and cloud deployment. I did not set up a replica, a second server or a cloud account, so I make no performance claims about them.

## Part 1: Partitioning demonstration

I created `orders_p`, a copy of `orders` partitioned by `order_date` into nine quarterly partitions plus a default partition, and loaded all [200,000] rows into it. Each full quarter holds roughly [25,000] orders. A check confirmed that the row count and the total of `total_amount` are identical to the original table.

**Partition pruning.** A query for one month of orders (March 2025) scanned only one of the partitions, `orders_p_2025q1`, and none of the others. PostgreSQL works out from the date range that the rows can only be in that partition and skips the rest. The same query on the unpartitioned table used [describe your plan, for example a parallel sequential scan of the whole table, or an index scan on `idx_orders_date`]. The partitioned query took about [ ] ms against [ ] ms for the ordinary table. This timing depends on which indexes exist on the ordinary table and comes from one machine, so the number of partitions scanned (one) is the more reliable result. Without a date filter, a query scans every partition, so pruning only helps queries that filter on the partition column.

**Default partition.** [Optional, delete if not done] A row dated 2030, outside every quarterly range, was stored in the default partition instead of being rejected. A default partition prevents failed inserts when data arrives with an unexpected date, though it has to be monitored so that it does not quietly fill up.

**Indexes on partitions.** [Optional, delete if not done] Creating one index on the partitioned table created an index on each of its [10] partitions. A query for one customer in one month then used the index on a single partition.

**Archiving.** [Optional, delete if not done] Detaching the oldest quarter turned it into a standalone table instantly, and the row count of the partitioned table fell by that quarter's rows, from [200,000] to [181,318]. Reattaching it restored the full count. Removing old data from a partitioned table is a quick metadata operation, whereas deleting the same rows from an ordinary table would be a slow `DELETE` that leaves the table to be cleaned up.

**Why I built a copy.** Converting the live `orders` table in place is awkward. `order_items`, `payments` and `deliveries` reference `orders(order_id)`, and PostgreSQL requires a partitioned table's primary key to include the partition column, so `order_id` alone could no longer be a unique key for those tables to point at. The copy also has no primary key or foreign keys, because it was created with `LIKE ... INCLUDING DEFAULTS`, which copies columns and defaults but not constraints. A real migration would redesign the keys, for example by using `(order_id, order_date)`.

## Part 2: Discussion

### Replication

One primary database takes all writes, and one or more replicas receive a copy of its changes. For Lilies this has two uses: read replicas can serve the nightly revenue report and the order-history pages without slowing the till, and a replica can take over if the primary fails.

Replication can be asynchronous (the primary does not wait, so writes are fast but a replica may be a few seconds behind) or synchronous (the primary waits for the replica, so no committed data is lost but writes are slower). For Lilies I would use asynchronous replication for reporting replicas, accepting small delays, and consider synchronous replication only for a failover replica if losing a few seconds of orders is unacceptable.

### Partitioning and sharding

Partitioning, which I demonstrated, splits one table into pieces on one server. Sharding spreads data across several servers, for example by outlet or region, and is what a business would consider when a single server can no longer cope with the volume. At [200,000] orders, Lilies does not need sharding. Partitioning by date is the sensible first step because most queries and reports are about recent periods and old quarters can be archived. If Lilies grew to many outlets, sharding by outlet would keep each outlet's orders and stock together, at the cost of cross-outlet reports becoming harder.

### Consistency and availability

Stock counts need strong consistency: it is better to refuse a sale than to oversell, which is what the `CHECK` constraint and locking in Portfolio 3 enforce. The menu and order-history views can tolerate being slightly stale in exchange for staying available. A replica may lag behind the primary, so a stock check must go to the primary and not to a replica. This is the usual trade-off between consistency and availability when data is spread across servers: for stock and payments I choose consistency, and for browsing and reports I choose availability.

### Availability, failover and backups

If the primary fails, a replica is promoted to take its place, and the application is pointed at it. The business questions are how much data it can afford to lose and how long it can be offline, and the answers decide whether replication is synchronous and how automatic the failover must be. Backups protect against mistakes that replication copies faithfully, such as an accidental delete, so I would keep regular full backups together with continuous archiving of the transaction log, and test restoring them. Power and network interruptions can be a real problem for a shop in Abuja, so a database hosted in a cloud data centre across more than one availability zone is more dependable than a single machine in the shop. This is like grid redundancy, where a second supply path keeps power on when one path fails.

### Cloud deployment

A managed cloud database (managed PostgreSQL, or MongoDB Atlas for the catalogue from Portfolio 4) would handle replication, backups and failover for Lilies, and would let it add capacity for December peaks. The trade-offs are running costs (often charged in foreign currency), latency to the nearest cloud region, and responsibility for protecting customer data, since customer names, phone numbers and addresses are personal data and where it is hosted and who can read it matter. For a single shop a cloud database may be more than is needed, but it becomes sensible as outlets and online orders grow.

### Deployment sketch

```
Customers / Till / Online app
            |
        Application
            |
   Primary PostgreSQL ----(replication)----> Replica 1 (reports)
            |                                Replica 2 (failover)
        Backups (daily + log archive)
```
