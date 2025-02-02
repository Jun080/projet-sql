CREATE OR REPLACE FUNCTION add_person(
    p_firstname VARCHAR(32),
    p_lastname VARCHAR(32),
    p_email VARCHAR(128),
    p_phone VARCHAR(10),
    p_address TEXT,
    p_town VARCHAR(32),
    p_zipcode VARCHAR(5)
) RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si un utilisateur avec la même adresse e-mail existe déjà
    IF EXISTS (SELECT 1 FROM traveler WHERE traveler.email = p_email) THEN
        RETURN FALSE;
    END IF;

    -- Ajouter le nouvel utilisateur
    INSERT INTO traveler (first_name, last_name, email, phone, address, city, postal_code)
    VALUES (p_firstname, p_lastname, p_email, p_phone, p_address, p_town, p_zipcode);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT add_person('John', 'Doe', 'john.doe@example.com', '0123456789', '123 Main St', 'Paris', '75001');
SELECT add_person('Jane', 'Doe', 'jane.doe@example.com', '0987654321', '456 Elm St', 'Lyon', '69001');
SELECT add_person('Smith', 'Alice', 'alice.smith@example.com', '0123456789', '789 Oak St', 'Paris', '75002');
SELECT add_person('John', 'Doe', 'john.doe@example.com', '0123456789', '123 Main St', 'Paris', '75001'); -- Doit échouer (doublon)
SELECT add_person('Maximoff', 'Wanda', 'wanda.maximoff@example.com', '0123456789', '789 Marvel St', 'Paris', '75003');
SELECT add_contract('pmaximoff', 'pietro.maximoff@example.com', '2023-04-01', 'IT');

CREATE OR REPLACE FUNCTION add_offer(
    p_code VARCHAR(5),
    p_name VARCHAR(32),
    p_price FLOAT,
    p_nb_month INT,
    p_zone_from INT,
    p_zone_to INT
) RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si les zones de départ et d'arrivée existent
    IF NOT EXISTS (SELECT 1 FROM zone WHERE number = p_zone_from) OR
       NOT EXISTS (SELECT 1 FROM zone WHERE number = p_zone_to) THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si le nombre de mois est positif et non nul
    IF p_nb_month <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si le prix est valide
    IF p_price <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Ajouter le nouveau forfait
    INSERT INTO pass (code, name, monthly_price, duration, min_zone, max_zone)
    VALUES (p_code, p_name, p_price, p_nb_month, p_zone_from, p_zone_to);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- Tests
SELECT add_offer('Z1212', 'Zone 1-2', 30.0, 12, 1, 2);
SELECT add_offer('Z1112', 'Zone 1-1', 85.0, 12, 1, 1);
SELECT add_offer('Z1512', 'Zone 1-5', 300.0, 12, 1, 5);
SELECT add_offer('O3', 'Invalid Pass', 50.0, 0, 1, 3); -- Doit échouer (nb_month <= 0)
SELECT add_offer('O4', 'Invalid Pass', 50.0, 1, 1, 10); -- Doit échouer (zone_to n'existe pas)








-- add_subscription
CREATE OR REPLACE FUNCTION add_subscription(
    num INT,
    p_email VARCHAR(128),
    p_code VARCHAR(5),
    date_sub DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    v_traveler_id INT;
    existing_subscription_count INT;
    pass_exists BOOLEAN;
BEGIN
    SELECT id INTO v_traveler_id
    FROM traveler
    WHERE email = p_email;

    IF v_traveler_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO existing_subscription_count
    FROM subscription
    WHERE subscription.traveler_id = v_traveler_id
    AND subscription.status IN ('Pending', 'Incomplete');

    IF existing_subscription_count > 0 THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM subscription WHERE id = num) THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (SELECT 1 FROM pass WHERE code = p_code) INTO pass_exists;
    IF NOT pass_exists THEN
        RETURN FALSE;
    END IF;

    INSERT INTO subscription (id, traveler_id, pass_code, subscription_date, status)
    VALUES (num, v_traveler_id, p_code, date_sub, 'Incomplete');

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;





-- Tests
SELECT add_subscription(1, 'john.doe@example.com', 'Z1312', '2025-01-10');

SELECT add_subscription(101, 'john.doe@example.com', 'Z1312', '2025-01-10');  -- Doit échouer
SELECT add_subscription(102, 'user@example.com', 'O8', '2025-01-10');  -- Doit échouer
SELECT add_subscription(2, 'wanda.maximoff@example.com', 'Z1512', '2026-01-10');





CREATE OR REPLACE FUNCTION update_status(
    p_num INT,
    p_new_status VARCHAR(32)
) RETURNS BOOLEAN AS $$
BEGIN
    IF p_new_status NOT IN ('Registered', 'Pending', 'Incomplete') THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM subscription WHERE id = p_num) THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM subscription WHERE id = p_num AND status = p_new_status) THEN
        RETURN TRUE;
    END IF;

    UPDATE subscription
    SET status = p_new_status
    WHERE id = p_num;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT update_status(2, 'Registered');
SELECT update_status(1, 'Pending');
SELECT update_status(3, 'Incomplete');
SELECT update_status(4, 'InvalidStatus'); -- Doit échouer (statut invalide)
SELECT update_status(999, 'Registered'); -- Doit échouer (abonnement n'existe pas)







CREATE OR REPLACE FUNCTION update_offer_price(
    offer_code VARCHAR(5),
    price FLOAT
) RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier si le prix est positif et non nul
    IF price <= 0 THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si le forfait existe
    IF NOT EXISTS (SELECT 1 FROM pass WHERE code = offer_code) THEN
        RETURN FALSE;
    END IF;

    -- Mettre à jour le prix du forfait
    UPDATE pass
    SET monthly_price = price
    WHERE code = offer_code;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;



-- Tests
SELECT update_offer_price('Z1312', 35.0);
SELECT update_offer_price('Z1412', 90.0);
SELECT update_offer_price('C9101', 0); -- Doit échouer
SELECT update_offer_price('D1112', 50.0); -- Doit échouer









-- ========================================
-- VUES
CREATE OR REPLACE VIEW view_user_small_name AS
    SELECT last_name AS lastname, first_name AS firstname
    FROM traveler
    WHERE LENGTH(last_name) <= 4
    ORDER BY last_name ASC, first_name ASC;

-- Tests
SELECT * FROM view_user_small_name;






-- view_user_subscription
CREATE OR REPLACE VIEW view_user_subscription AS
    SELECT 
        CONCAT(t.last_name, ' ', t.first_name) AS user,
        p.name AS offer
    FROM 
        traveler t
    JOIN 
        subscription s ON t.id = s.traveler_id
    JOIN 
        pass p ON s.pass_code = p.code
    ORDER BY 
        user ASC, offer ASC;

-- Tests
SELECT * FROM view_user_subscription;







-- view_unloved_offers
CREATE OR REPLACE VIEW view_unloved_offers AS
    SELECT p.name AS offer
    FROM pass p
    LEFT JOIN subscription s ON p.code = s.pass_code
    WHERE s.pass_code IS NULL
    ORDER BY p.name ASC;

-- Tests
SELECT * FROM view_unloved_offers;





-- view_pending_subscriptions
CREATE OR REPLACE VIEW view_pending_subscriptions AS
    SELECT t.last_name AS lastname, t.first_name AS firstname
    FROM traveler t
    JOIN subscription s ON t.id = s.traveler_id
    WHERE s.status = 'Pending'
    ORDER BY s.subscription_date ASC;


-- Tests
SELECT * FROM view_pending_subscriptions;





-- view_old_subscription
CREATE OR REPLACE VIEW view_old_subscription AS
    SELECT t.last_name AS lastname, t.first_name AS firstname, p.name AS subscription, s.status
    FROM traveler t
    JOIN subscription s ON t.id = s.traveler_id
    JOIN pass p ON s.pass_code = p.code
    WHERE s.status IN ('Incomplete', 'Pending') AND s.subscription_date <= CURRENT_DATE - INTERVAL '1 year'
    ORDER BY t.last_name ASC, t.first_name ASC, p.name ASC;


-- Tests
SELECT * FROM view_old_subscription;





-- list_station_near_user
CREATE OR REPLACE FUNCTION list_station_near_user(user_email VARCHAR(128))
RETURNS SETOF VARCHAR(64) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT LOWER(s.name)::VARCHAR(64)
    FROM station s
    JOIN traveler t ON s.city = t.city
    WHERE t.email = user_email
    ORDER BY LOWER(s.name)::VARCHAR(64);
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT * FROM list_station_near_user('john.doe@example.com');
SELECT * FROM list_station_near_user('jane.doe@example.com');
SELECT * FROM list_station_near_user('alice.smith@example.com');







CREATE OR REPLACE FUNCTION list_subscribers(code_offer VARCHAR(5))
RETURNS SETOF VARCHAR(65) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CONCAT(t.last_name, ' ', t.first_name)::VARCHAR(65) AS full_name
    FROM traveler t
    JOIN subscription s ON t.id = s.traveler_id
    WHERE s.pass_code = code_offer
    ORDER BY full_name;
END;
$$ LANGUAGE plpgsql;


-- Tests
SELECT * FROM list_subscribers('Z1312');
SELECT * FROM list_subscribers('Z1412');
SELECT * FROM list_subscribers('Z1512');







-- list_subscription
CREATE OR REPLACE FUNCTION list_subscription(
    user_email VARCHAR(128),
    sub_date DATE
)
RETURNS SETOF VARCHAR(5) AS $$
BEGIN
    RETURN QUERY
    SELECT s.pass_code::VARCHAR(5)
    FROM subscription s
    JOIN traveler t ON s.traveler_id = t.id
    WHERE t.email = user_email
    AND s.status = 'Registered'
    AND s.subscription_date = sub_date
    ORDER BY s.pass_code;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT * FROM list_subscription('john.doe@example.com', '2025-01-10');
SELECT * FROM list_subscription('jane.doe@example.com', '2025-01-10');
SELECT * FROM list_subscription('alice.smith@example.com', '2025-01-10');
