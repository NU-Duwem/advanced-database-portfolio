"""Portfolio 4: copy Lilies Pastries data from PostgreSQL into MongoDB documents.
Run:    python export_to_mongodb.py
Needs:  pip install pymongo psycopg2-binary
Set your PostgreSQL login with environment variables PGHOST, PGDATABASE, PGUSER, PGPASSWORD."""
import os, random, psycopg2
from collections import defaultdict
from pymongo import MongoClient

random.seed(7)
ORDERS_TO_COPY = 20000                      # most recent orders only

client = MongoClient("mongodb://localhost:27017")
mongo = client["lilies_pastries"]

pg = psycopg2.connect(host=os.environ.get("PGHOST", "localhost"), dbname=os.environ.get("PGDATABASE", "lilies_pastries"),
                      user=os.environ.get("PGUSER", "postgres"), password=os.environ.get("PGPASSWORD", "")).cursor()

# Catalogue details differ by category. This variety is why a document model suits the catalogue.
def attributes(category):
    if category == "Cakes":
        return {"layers": random.choice([1, 2, 3, 4]), "flavour": random.choice(["vanilla", "chocolate", "red velvet"]),
                "sizes_inches": [6, 8, 10], "custom_message": True}
    if category == "Pastries": return {"filling": random.choice(["chicken", "beef", "cream"]), "weight_g": random.choice([90, 120, 150])}
    if category == "Bread":    return {"weight_g": random.choice([400, 600, 800]), "sliced": random.choice([True, False])}
    if category == "Cookies":  return {"pack_size": random.choice([6, 12, 24]), "flavour": random.choice(["oat", "choc chip"])}
    if category == "Snacks":   return {"pack_size": random.choice([1, 4, 10]), "spice": random.choice(["none", "mild", "hot"])}
    return {"volume_ml": random.choice([250, 330, 500]), "serve": random.choice(["hot", "cold"])}

# 1. products collection
pg.execute("SELECT product_id, sku, name, category, price FROM products ORDER BY product_id")
products, names = [], {}
for pid, sku, name, category, price in pg.fetchall():
    names[pid] = name
    products.append({"_id": pid, "sku": sku, "name": name, "category": category, "price": float(price),
                     "allergens": random.sample(["gluten", "milk", "eggs", "nuts", "soy"], k=random.randint(1, 3)),
                     "attributes": attributes(category)})
mongo.products.drop(); mongo.products.insert_many(products)

# 2. orders collection: one document per order, with items, payment and delivery embedded
pg.execute("SELECT customer_id, full_name FROM customers"); customers = dict(pg.fetchall())
pg.execute("SELECT order_id, customer_id, order_date, channel, status, total_amount FROM orders ORDER BY order_id DESC LIMIT %s", (ORDERS_TO_COPY,))
orders = pg.fetchall(); ids = [o[0] for o in orders]

items = defaultdict(list)
pg.execute("SELECT order_id, product_id, quantity, unit_price FROM order_items WHERE order_id = ANY(%s)", (ids,))
for oid, pid, qty, price in pg.fetchall():
    items[oid].append({"product_id": pid, "name": names[pid], "qty": qty, "unit_price": float(price)})

payments = {}
pg.execute("SELECT order_id, method, amount, status FROM payments WHERE order_id = ANY(%s)", (ids,))
for oid, method, amount, status in pg.fetchall(): payments[oid] = {"method": method, "amount": float(amount), "status": status}

deliveries = {}
pg.execute("SELECT order_id, area, rider_name, status FROM deliveries WHERE order_id = ANY(%s)", (ids,))
for oid, area, rider, status in pg.fetchall(): deliveries[oid] = {"area": area, "rider": rider, "status": status}

docs = [{"_id": oid, "customer": {"id": cid, "name": customers[cid]}, "order_date": date, "channel": channel,
         "status": status, "total": float(total), "items": items[oid],
         "payment": payments.get(oid), "delivery": deliveries.get(oid)}
        for oid, cid, date, channel, status, total in orders]
mongo.orders.drop(); mongo.orders.insert_many(docs)
print("products:", mongo.products.count_documents({}), "orders:", mongo.orders.count_documents({}))