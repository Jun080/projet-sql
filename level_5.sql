DROP TRIGGER IF EXISTS trigger_store_offer_updates ON pass;
DROP TRIGGER IF EXISTS trigger_store_status_updates ON subscription;
DROP VIEW IF EXISTS view_offer_updates CASCADE;
DROP VIEW IF EXISTS view_status_updates CASCADE;
DROP TABLE IF EXISTS offer_updates CASCADE;
DROP TABLE IF EXISTS status_updates CASCADE;

--store-offer-updates
CREATE OR REPLACE FUNCTION store_offer_updates()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO offer_updates (pass_code, modification_time, old_price, new_price)
    VALUES (OLD.code, NOW(), OLD.monthly_price, NEW.monthly_price);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trigger store-offer-updates
CREATE TRIGGER trigger_store_offer_updates
AFTER UPDATE OF monthly_price ON pass
FOR EACH ROW
WHEN (OLD.monthly_price IS DISTINCT FROM NEW.monthly_price)
EXECUTE FUNCTION store_offer_updates();


--store-status-updates
CREATE OR REPLACE FUNCTION store_status_updates()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO status_updates (email, pass_code, modification_time, old_status, new_status)
    VALUES (
        (SELECT email FROM traveler WHERE id = OLD.traveler_id),
        OLD.pass_code,
        NOW(),
        OLD.status,
        NEW.status
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trigger store status-updates
CREATE TRIGGER trigger_store_status_updates
AFTER UPDATE OF status ON subscription
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION store_status_updates();

--table store-offer-updates
CREATE TABLE IF NOT EXISTS offer_updates (
    pass_code CHAR(5),
    modification_time TIMESTAMP,
    old_price DECIMAL(10, 2),
    new_price DECIMAL(10, 2)
);

--table status update
CREATE TABLE IF NOT EXISTS status_updates (
    email VARCHAR(128),
    pass_code CHAR(5),
    modification_time TIMESTAMP,
    old_status VARCHAR(32),
    new_status VARCHAR(32)
);

--view offer updates 
CREATE OR REPLACE VIEW view_offer_updates AS
    SELECT pass_code AS subscription, modification_time AS modification, old_price, new_price
    FROM offer_updates
    ORDER BY modification_time;

-- view statsu updates
CREATE OR REPLACE VIEW view_status_updates AS
    SELECT email, pass_code AS sub, modification_time AS modification, old_status, new_status
    FROM status_updates
    ORDER BY modification_time;

-- Tests
DELETE FROM subscription;
DELETE FROM traveler;
DELETE FROM pass;
DELETE FROM offer_updates;
DELETE FROM status_updates;


INSERT INTO traveler (id, last_name, first_name, email, phone, address, postal_code, city) 
VALUES (1, 'Doe', 'John', 'john.doe@example.com', '1234567890', '123 Main St', '75001', 'Paris');

INSERT INTO traveler (id, last_name, first_name, email, phone, address, postal_code, city) 
VALUES (2, 'Smith', 'Jane', 'jane.smith@example.com', '0987654321', '456 Elm St', '75002', 'Paris');

INSERT INTO pass (code, name, monthly_price, duration) 
VALUES ('P1234', 'Basic Plan', 30.00, 1);

INSERT INTO pass (code, name, monthly_price, duration) 
VALUES ('P5678', 'Premium Plan', 50.00, 1);

INSERT INTO subscription (id, traveler_id, pass_code, subscription_date, status) 
VALUES (1, 1, 'P1234', '2023-01-01', 'Registered');

INSERT INTO subscription (id, traveler_id, pass_code, subscription_date, status) 
VALUES (2, 2, 'P5678', '2023-01-01', 'Pending');

--update price to check le déclencheur store offer updates
UPDATE pass SET monthly_price = 35.00 WHERE code = 'P1234';
UPDATE pass SET monthly_price = 55.00 WHERE code = 'P5678';

--update status to check le déclencheur store status updates 
UPDATE subscription SET status = 'Incomplete' WHERE id = 1;
UPDATE subscription SET status = 'Registered' WHERE id = 2;

--display views
SELECT * FROM view_offer_updates;
SELECT * FROM view_status_updates;

--more tests
UPDATE pass SET monthly_price = 40.00 WHERE code = 'P1234';
UPDATE subscription SET status = 'Pending' WHERE id = 1;

--display views
SELECT * FROM view_offer_updates;
SELECT * FROM view_status_updates;