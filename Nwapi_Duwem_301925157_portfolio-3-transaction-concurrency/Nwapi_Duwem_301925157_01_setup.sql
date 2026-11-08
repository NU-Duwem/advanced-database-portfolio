-- Audit trigger: every stock change is logged automatically
CREATE OR REPLACE FUNCTION log_stock_change() RETURNS trigger AS $$
BEGIN
    INSERT INTO stock_audit(product_id, old_qty, new_qty)
    VALUES (NEW.product_id, OLD.quantity_in_stock, NEW.quantity_in_stock);
    RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_audit ON inventory;
CREATE TRIGGER trg_stock_audit AFTER UPDATE OF quantity_in_stock ON inventory
FOR EACH ROW EXECUTE FUNCTION log_stock_change();

-- place_order: all-or-nothing. Items look like [{"product_id":5,"qty":2}, ...]
CREATE OR REPLACE FUNCTION place_order(p_customer INT, p_items JSONB) RETURNS INT AS $$
DECLARE v_order INT; it JSONB; v_price NUMERIC;
BEGIN
    INSERT INTO orders (customer_id, channel, status) VALUES (p_customer, 'online', 'Pending')
    RETURNING order_id INTO v_order;

    FOR it IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        -- the WHERE clause is the oversell guard
        UPDATE inventory SET quantity_in_stock = quantity_in_stock - (it->>'qty')::INT
        WHERE product_id = (it->>'product_id')::INT
          AND quantity_in_stock >= (it->>'qty')::INT;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Insufficient stock for product %', it->>'product_id';
        END IF;

        SELECT price INTO v_price FROM products WHERE product_id = (it->>'product_id')::INT;
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        VALUES (v_order, (it->>'product_id')::INT, (it->>'qty')::INT, v_price);
    END LOOP;

    UPDATE orders SET total_amount =
        (SELECT SUM(quantity * unit_price) FROM order_items WHERE order_id = v_order)
    WHERE order_id = v_order;
    RETURN v_order;
END $$ LANGUAGE plpgsql;