# Advanced Database Systems Portfolio

Case study: **Lilies Pastries**, a simulated bakery chain.

## Case study statement

- **Organisation / scenario:** Lilies Pastries is a simulated bakery in Abuja, Nigeria, selling cakes, pastries, bread, cookies, snacks and drinks through walk-in, phone and online orders. It is a realistic business scenario, not a real company, and all data in this repository is generated.
- **Nature of the system:** an order-management database covering the product catalogue, stock, customers, orders, payments and deliveries, plus business expenses for profit reporting.
- **Users of the database:** customers, cashiers, bakers, managers and delivery riders.
- **Major data stored:** products and their stock levels, customers, orders and order lines, payments, deliveries, expenses and a stock audit trail.
- **Key operations supported:** place an order, deduct stock, take payment, track delivery, search a customer's order history, and report revenue and expenses.

## Repository structure

| Folder | Portfolio activity |
|---|---|
| `portfolio-1-database-design/` | Database design and modelling: ER diagram, schema, constraints, normalisation |
| `portfolio-2-query-optimisation/` | Query processing and optimisation: queries, execution plans, indexes |
| `portfolio-3-transactions-concurrency/` | Transactions and concurrency: commit, rollback, locking, isolation levels |
| `portfolio-4-nosql/` | NoSQL and advanced data models: MongoDB documents and queries |
| `portfolio-5-distributed-cloud/` | Distributed and cloud database exercise: partitioning, replication, availability |

Each folder has its own `README.md` explaining what was done, how to run it, and what I observed.

## Tools used

- PostgreSQL [18.x] with pgAdmin 4
- MongoDB [version] with MongoDB Compass
- Python [3.14] with `psycopg2` and `pymongo` (used for the PostgreSQL-to-MongoDB export)
- Git and GitHub for version control

## How to reproduce the work

1. Create an empty PostgreSQL database.
2. Run `portfolio-1-database-design/01_schema.sql`, then `02_seed.sql`.
3. Follow each portfolio folder's README in order (2, 3, 4, 5).
4. Portfolio 4 needs MongoDB running locally before you run its export script.

## Data note

All data is synthetic, produced by the seed script with a fixed random seed, so the same rows are generated each time. No real customer data is used.

## AI use declaration

- **Tool used:** Claude (Anthropic).
- **What it was used for:** guidance on the portfolio structure and concepts, and example SQL, Python and MongoDB code and documentation drafts, which I adapted to my own case study and database.
- **My own work:** I chose Lilies Pastries as the case study and started from my own PostgreSQL schema, which I reviewed and improved. I installed and configured PostgreSQL and MongoDB, ran every script myself, diagnosed and fixed the errors that came up, took all screenshots and execution plans from my own machine, and decided what to include in each portfolio.
- **How I verified it:** I tested each script against my own database, checked results against what I expected (row counts, constraint errors, execution plan changes), and kept only what I could run and explain.

I remain responsible for understanding and being able to explain everything submitted.