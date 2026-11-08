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


## Suitability

The Lilies Pastries data splits naturally into two parts, and they suit the two databases differently.

| Topic | Document model (MongoDB) | Relational model (PostgreSQL) |

| Catalogue with varied attributes | A natural fit: each product holds only the details that apply to it | Needs many nullable columns or a side table |
| Showing an order page | One read returns the order, items, payment and delivery | Joins across four tables |
| Stock decrements and "never oversell" | A weak fit: the rule must be enforced in application code or with multi-document transactions, which need a replica set (my local MongoDB is a single instance) | A strong fit: `CHECK (quantity_in_stock >= 0)`, row locks and transactions, as shown in Portfolio 3 |
| Renaming a product | Product names copied into old orders go stale, and every copy must be updated if a rename should show everywhere | One row updated |

I embedded items, payment and delivery inside the order because there are only a few per order, they are always read together, and they have no independent life. I kept only the customer's id and name as a snapshot rather than the full record, because customer details change on their own schedule. The cost is duplicated data. The copied product names in old orders are correct for history, in the same way `unit_price` is copied in the SQL design.

**Recommendation:** a hybrid design. Keep stock, orders and payments in PostgreSQL, where integrity rules and transactions matter most. Use MongoDB for the product catalogue and for read-heavy views such as order history and menus, where flexible shape and fast single-document reads are the advantage, and where slightly stale data is acceptable. For a business of Lilies Pastries' size, a single PostgreSQL database would also work, so MongoDB would be justified mainly by catalogue flexibility, not by volume.