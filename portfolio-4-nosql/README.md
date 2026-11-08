# Portfolio 4: NoSQL and Advanced Data Models (MongoDB)

## Goal
Model the Lilies Pastries data as MongoDB documents, load it from PostgreSQL, query it, and show index evidence.

## Design
- `products`: one document per product; category-specific details are nested in `attributes`, plus an `allergens` array.
- `orders`: one document per order, with `items`, `payment` and `delivery` embedded.
- Embedded: items, payment, delivery (small, always read with the order, no independent life).
- Copied as a snapshot: customer id and name only (customer details change on their own schedule).
- Cost: duplicated data, so a product rename does not update old orders (correct for history, like `unit_price` in SQL).

## Files
- `01_export_to_mongo.py`: copies PostgreSQL data into MongoDB
- `02_queries.js`: indexes, queries and explain commands
- screenshots: see below

## How to run
1. Start MongoDB and PostgreSQL. 2. Set PGDATABASE, PGUSER, PGPASSWORD. 3. `python 01_export_to_mongo.py`. 4. Run `02_queries.js` block by block in mongosh.

## What I observed
(results and figures go here)

## Suitability
(about 200 words, see step 8)