-- Lilies Pastries: relational schema (PostgreSQL)

DROP TABLE IF EXISTS stock_audit, deliveries, payments, order_items, orders,
                     customers, inventory, products, expenses CASCADE;
DROP FUNCTION IF EXISTS log_stock_change();

CREATE TABLE products (
    product_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    category    VARCHAR(50)  NOT NULL,
    description TEXT,
    price       NUMERIC(10,2) NOT NULL CHECK (price > 0),
    sku         VARCHAR(50)  NOT NULL UNIQUE
);

CREATE TABLE inventory (
    inventory_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id        INT NOT NULL UNIQUE REFERENCES products(product_id),
    quantity_in_stock INT NOT NULL DEFAULT 0 CHECK (quantity_in_stock >= 0),
    reorder_level     INT NOT NULL DEFAULT 10,
    last_restocked    DATE
);

CREATE TABLE customers (
    customer_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(120) UNIQUE,
    phone          VARCHAR(20),
    joined_on      DATE NOT NULL DEFAULT CURRENT_DATE,
    loyalty_points INT NOT NULL DEFAULT 0 CHECK (loyalty_points >= 0)
);

CREATE TABLE orders (
    order_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(customer_id),
    order_date   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    channel      VARCHAR(10) NOT NULL DEFAULT 'walk-in'
                 CHECK (channel IN ('walk-in','online','phone')),
    status       VARCHAR(20) NOT NULL DEFAULT 'Pending'
                 CHECK (status IN ('Pending','Completed','Cancelled')),
    total_amount NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (total_amount >= 0)
);

-- unit_price is copied at sale time so later price changes do not rewrite history
CREATE TABLE order_items (
    order_item_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      INT NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id    INT NOT NULL REFERENCES products(product_id),
    quantity      INT NOT NULL CHECK (quantity > 0),
    unit_price    NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    UNIQUE (order_id, product_id)
);

CREATE TABLE payments (
    payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id   INT NOT NULL REFERENCES orders(order_id),
    method     VARCHAR(10) NOT NULL CHECK (method IN ('cash','card','transfer','pos')),
    amount     NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    status     VARCHAR(10) NOT NULL DEFAULT 'success'
               CHECK (status IN ('success','failed','refunded')),
    paid_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE deliveries (
    delivery_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      INT NOT NULL UNIQUE REFERENCES orders(order_id),
    address       VARCHAR(160) NOT NULL,
    area          VARCHAR(40) NOT NULL,
    rider_name    VARCHAR(80),
    status        VARCHAR(10) NOT NULL DEFAULT 'queued'
                  CHECK (status IN ('queued','on_route','delivered','failed')),
    dispatched_at TIMESTAMP,
    delivered_at  TIMESTAMP
);

CREATE TABLE expenses (
    expense_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category     VARCHAR(50) NOT NULL,
    description  TEXT,
    amount       NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    expense_date DATE NOT NULL
);

CREATE TABLE stock_audit (
    audit_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT NOT NULL,
    old_qty    INT NOT NULL,
    new_qty    INT NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE FUNCTION log_stock_change() RETURNS trigger AS $$
BEGIN
    INSERT INTO stock_audit(product_id, old_qty, new_qty)
    VALUES (NEW.product_id, OLD.quantity_in_stock, NEW.quantity_in_stock);
    RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_stock_audit
AFTER UPDATE OF quantity_in_stock ON inventory
FOR EACH ROW EXECUTE FUNCTION log_stock_change();