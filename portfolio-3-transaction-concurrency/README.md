# Portfolio 3: Transactions and Concurrency

## Goal

Show how PostgreSQL keeps Lilies Pastries data correct when operations fail halfway or when two people work at the same time: commit and rollback, a lost-update problem and its fix, and the effect of isolation levels.

## Files

- `01_setup.sql`: the stock-audit trigger and the `place_order` function
- `02_commit_rollback.sql`: the commit, rollback and savepoint demonstrations
- `evidence/`: screenshots

The concurrency experiments need two separate database sessions, so I ran them interactively in two query windows. The steps are described below.

## How to run

1. Run `01_setup.sql` once.
2. Run the commit and rollback demos in one query window, one statement at a time.
3. For the concurrency experiments, open two query windows (each is its own session, called A and B) and run the steps in the order shown.

## Part 1: Atomic order placement

`place_order(customer, items)` creates an order and its lines and deducts stock inside one transaction. For each item it runs:

```sql
UPDATE inventory SET quantity_in_stock = quantity_in_stock - n
WHERE product_id = ... AND quantity_in_stock >= n;
```

If no row is updated, the stock is insufficient and the function raises an exception, which undoes the whole order. A trigger on `inventory` records every stock change in `stock_audit`.

**Commit.** An order for 3 units of product 5 and 2 units of product 6 succeeded and stock fell from [10 and 10] to [7 and 8] (Figure 1).

**Rollback.** An order whose second item asked for 99 units failed with an "Insufficient stock" error. After `ROLLBACK`, stock was unchanged and no order existed without lines, so the first item's deduction was undone with the rest (Figure 2). Atomicity means all of an order happens or none of it does.

One detail: after a failed attempt, the next order number skips a value, because sequences are not rolled back. This is normal PostgreSQL behaviour and does not affect correctness.

[Optional, delete if not done] **Savepoint.** Inside one transaction I placed a good order, set a savepoint, attempted an impossible one, rolled back to the savepoint and placed another. The good orders were kept and the failed one was discarded (Figure 3).

## Part 2: The lost-update problem

Product 5 had 10 units. Two cashiers each sold 3, so the correct final stock is 4. Each session read the stock, calculated the new value, and wrote it back:

| Step | Session A | Session B |
|---|---|---|
| 1 | begin, read stock (10) | |
| 2 | | begin, read stock (10) |
| 3 | write 7, commit | |
| 4 | | write 7, commit |

**Result: the stock was 7 although 6 units were sold.** B's write replaced A's using a stale reading, so one sale vanished (Figure 4).

**Fix 1: lock the row while reading.** With `SELECT ... FOR UPDATE`, B's read waited until A committed, then returned 7, and B wrote 4. The final stock was correct (Figure 5).

**Fix 2: let the database do the arithmetic.** A single statement, `UPDATE inventory SET quantity_in_stock = quantity_in_stock - 3 WHERE product_id = 5 AND quantity_in_stock >= 3`, is atomic and needs no explicit locking. For simple decrements this is the better choice.

## Part 3: Isolation levels

Session A read a product's price twice inside one transaction while session B changed it in between:

| Isolation level | First read | Second read |
|---|---|---|
| READ COMMITTED (PostgreSQL's default) | [1000] | [1500] |
| REPEATABLE READ | [1000] | [1000] |

Under READ COMMITTED each statement sees the latest committed data, so the same query gave different answers inside one transaction (a non-repeatable read, Figure 6). Under REPEATABLE READ the transaction keeps one snapshot and sees consistent data (Figure 7). The cost is that a transaction that tries to modify a row changed by someone else after its snapshot is rejected and must be retried.

[Optional, delete if not done] **Serialization failure.** Under REPEATABLE READ, session A updated a row that B had changed and committed after A's snapshot. PostgreSQL refused with "could not serialize access due to concurrent update", so the application must be ready to retry.

[Optional, delete if not done] **Deadlock.** A locked product 5 then asked for 6, while B locked 6 then asked for 5. PostgreSQL detected the cycle and aborted one session. The prevention is to always lock products in the same order, for example ascending `product_id`.

## Summary

| Problem | What happened | Mechanism that handles it |
|---|---|---|
| Failure halfway through an order | partial order and stock deduction | transaction with rollback |
| Overselling | stock could go negative | `CHECK` constraint plus guarded `UPDATE` |
| Lost update | one cashier's sale vanished | row lock or atomic update |
| Inconsistent reads inside a transaction | price changed mid-transaction | REPEATABLE READ |

## What I observed

[Write 3 to 4 sentences in your own words: for example, which result surprised you, what went wrong when you first ran the two-window experiments (such as a window stuck waiting because of an open transaction), and what you would do differently, such as using the atomic update everywhere.]

## Limitations

- The concurrency tests interleave two sessions by hand, so they demonstrate the mechanisms but not behaviour under heavy load.
- `place_order` does not take payment, and it does not retry after a deadlock or serialization failure. A real application would need both.

## Evidence

![Figure 1](evidence/place_order_commit.png)
*Figure 1: A successful order commits and stock falls by the ordered quantities.*

![Figure 2](evidence/rollback_stock_unchanged.png)
*Figure 2: An order with insufficient stock fails; after rollback, stock is unchanged and no partial order remains.*
