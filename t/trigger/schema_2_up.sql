CREATE TABLE product_price_changes (
  id INT GENERATED ALWAYS AS IDENTITY,
  product_id INT NOT NULL,
  old_price NUMERIC(10,2) NOT NULL,
  new_price NUMERIC(10,2) NOT NULL,
  changed_on TIMESTAMP(6) NOT NULL
);

CREATE OR REPLACE FUNCTION log_price_changes()
  RETURNS TRIGGER 
  LANGUAGE PLPGSQL
AS $$
BEGIN
  IF NEW.price <> OLD.price THEN
    INSERT INTO product_price_changes(product_id,old_price,new_price,changed_on)
    VALUES(OLD.id,OLD.price,NEW.price,now());
  END IF;

  RETURN NEW;
END;
$$

CREATE TRIGGER price_changes
  BEFORE UPDATE
  ON products
  FOR EACH ROW
  EXECUTE FUNCTION log_price_changes();
