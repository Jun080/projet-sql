-- add_journey
CREATE OR REPLACE FUNCTION add_journey(
    p_email VARCHAR(128),
    p_time_start TIMESTAMP,
    p_time_end TIMESTAMP,
    p_station_start INT,
    p_station_end INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_traveler_id INT;
BEGIN
    IF p_time_end - p_time_start > INTERVAL '24 hours' THEN
        RETURN FALSE;
    END IF;

    SELECT t.id INTO v_traveler_id FROM traveler t WHERE t.email = p_email;
    IF v_traveler_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM trip tr
        WHERE tr.traveler_id = v_traveler_id 
        AND (
            (p_time_start BETWEEN tr.entry_timestamp AND tr.exit_timestamp) OR
            (p_time_end BETWEEN tr.entry_timestamp AND tr.exit_timestamp) OR
            (tr.entry_timestamp BETWEEN p_time_start AND p_time_end) OR
            (tr.exit_timestamp BETWEEN p_time_start AND p_time_end)
        )
    ) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO trip (traveler_id, entry_timestamp, exit_timestamp, entry_station_id, exit_station_id)
    VALUES (v_traveler_id, p_time_start, p_time_end, p_station_start, p_station_end);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT add_journey('john.doe@newdomain.com', '2023-04-01 08:00:00', '2023-04-01 10:00:00', 1, 2);
SELECT add_journey('alice.smith@newdomain.com', '2023-04-01 09:00:00', '2023-04-01 11:00:00', 3, 4);
SELECT add_journey('pietro.maximoff@example.com', '2023-04-01 09:00:00', '2023-04-01 11:00:00', 1, 4);
SELECT add_journey('pietro.maximoff@example.com', '2025-04-01 09:00:00', '2025-04-01 11:00:00', 1, 4);
SELECT add_journey('wanda.maximoff@example.com', '2023-04-01 10:00:00', '2023-04-01 13:00:00', 1, 4);
SELECT add_journey('wanda.maximoff@example.com', '2025-04-03 10:00:00', '2025-04-03 13:00:00', 1, 4);
SELECT add_journey('john.doe@example.com', '2023-04-01 09:30:00', '2023-04-01 10:30:00', 1, 3); -- Doit échouer (chevauchement de temps)
SELECT add_journey('john.doe@example.com', '2023-04-01 08:00:00', '2023-04-02 09:00:00', 1, 2); -- Doit échouer (durée > 24 heures)

SELECT add_journey('wanda.maximoff@example.com', '2025-04-01 00:00:00', '2025-04-01 00:00:00', 1, 2);
SELECT add_journey('pietro.maximoff@example.com', '2025-04-01 00:00:00', '2025-04-01 00:00:00', 1, 2);






-- add_bill
CREATE OR REPLACE FUNCTION add_bill(
    p_email VARCHAR(128),
    p_year INT,
    p_month INT
) RETURNS NUMERIC(10, 2) AS $$
DECLARE
    v_traveler_id INT;
    v_total NUMERIC(10, 2) := 0;
    v_is_employee BOOLEAN;
BEGIN
    IF CURRENT_DATE < TO_DATE(p_year || '-' || p_month || '-01', 'YYYY-MM-DD') + INTERVAL '1 month' THEN
        RETURN 0;
    END IF;

    SELECT id INTO v_traveler_id FROM traveler WHERE email = p_email;
    IF v_traveler_id IS NULL THEN
        RETURN 0;
    END IF;

    SELECT COALESCE(SUM(z1.price + z2.price), 0) INTO v_total
    FROM trip t
    JOIN station s1 ON t.entry_station_id = s1.id
    JOIN station s2 ON t.exit_station_id = s2.id
    JOIN zone z1 ON s1.zone_number = z1.number
    JOIN zone z2 ON s2.zone_number = z2.number
    WHERE t.traveler_id = v_traveler_id
    AND t.entry_timestamp BETWEEN TO_DATE(p_year || '-' || p_month || '-01', 'YYYY-MM-DD') AND (TO_DATE(p_year || '-' || p_month || '-01', 'YYYY-MM-DD') + INTERVAL '1 month' - INTERVAL '1 day');

    SELECT v_total + COALESCE(SUM(p.monthly_price), 0) INTO v_total
    FROM subscription s
    JOIN pass p ON s.pass_code = p.code
    WHERE s.traveler_id = v_traveler_id
    AND s.subscription_date <= (TO_DATE(p_year || '-' || p_month || '-01', 'YYYY-MM-DD') + INTERVAL '1 month' - INTERVAL '1 day');

    SELECT EXISTS (
        SELECT 1 
        FROM employee 
        WHERE id = v_traveler_id
    ) INTO v_is_employee;

    IF v_is_employee THEN
        v_total := v_total * 0.9;
    END IF;

    SELECT ROUND(v_total, 2) INTO v_total;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT add_bill('john.doe@newdomain.com', 2023, 4);
SELECT add_bill('alice.smith@newdomain.com', 2023, 4);
SELECT add_bill('pietro.maximoff@example.com', 2023, 4);
SELECT add_bill('pietro.maximoff@example.com', 2025, 4);
SELECT add_bill('wanda.maximoff@example.com', 2023, 4);
SELECT add_bill('wanda.maximoff@example.com', 2025, 4);




-- pay_bill
CREATE OR REPLACE FUNCTION pay_bill(
    p_email VARCHAR(128),
    p_year INT,
    p_month INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_traveler_id INT;
    v_total NUMERIC(10, 2);
    v_is_paid BOOLEAN;
BEGIN
    SELECT id INTO v_traveler_id FROM traveler WHERE email = p_email;
    IF v_traveler_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT add_bill(p_email, p_year, p_month) INTO v_total;

    IF v_total = 0 THEN
        RETURN FALSE;
    END IF;

    SELECT EXISTS (
        SELECT 1 
        FROM trip 
        WHERE traveler_id = v_traveler_id 
        AND EXTRACT(YEAR FROM entry_timestamp) = p_year 
        AND EXTRACT(MONTH FROM entry_timestamp) = p_month
    ) INTO v_is_paid;

    IF v_is_paid THEN
        RETURN TRUE;
    ELSE
        INSERT INTO trip (traveler_id, entry_timestamp, exit_timestamp, entry_station_id, exit_station_id)
        VALUES (v_traveler_id, NOW(), NOW(), 0, 0);

        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT pay_bill('john.doe@newdomain.com', 2023, 4);
SELECT pay_bill('alice.smith@newdomain.com', 2023, 4);





-- generate_bill
CREATE OR REPLACE FUNCTION generate_bill(
    p_year INT,
    p_month INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_traveler RECORD;
    v_total NUMERIC(10, 2);
    v_entry_station_id INT;
    v_exit_station_id INT;
BEGIN
    IF CURRENT_DATE < TO_DATE(p_year || '-' || p_month || '-01', 'YYYY-MM-DD') + INTERVAL '1 month' THEN
        RETURN FALSE;
    END IF;

    SELECT id INTO v_entry_station_id FROM station LIMIT 1;
    SELECT id INTO v_exit_station_id FROM station ORDER BY id DESC LIMIT 1;

    FOR v_traveler IN SELECT * FROM traveler LOOP
        SELECT add_bill(v_traveler.email, p_year, p_month) INTO v_total;

        IF v_total = 0 THEN
            CONTINUE;
        END IF;

        INSERT INTO trip (traveler_id, entry_timestamp, exit_timestamp, entry_station_id, exit_station_id)
        VALUES (v_traveler.id, NOW(), NOW(), v_entry_station_id, v_exit_station_id);
    END LOOP;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT generate_bill(2023, 4);






-- view_all_bills
CREATE OR REPLACE VIEW view_all_bills AS
    SELECT
        t.last_name AS lastname,
        t.first_name AS firstname,
        ROW_NUMBER() OVER (ORDER BY t.id) AS bill_number,
        add_bill(t.email, EXTRACT(YEAR FROM CURRENT_DATE)::INT, EXTRACT(MONTH FROM CURRENT_DATE)::INT) AS bill_amount
    FROM
        traveler t
    ORDER BY
        bill_number;

-- Tests
SELECT * FROM view_all_bills;




-- view_bill_per_month
CREATE OR REPLACE VIEW view_bill_per_month AS
    SELECT
        EXTRACT(YEAR FROM t.entry_timestamp) AS year,
        EXTRACT(MONTH FROM t.entry_timestamp) AS month,
        COUNT(*) AS bills,
        SUM(add_bill(tr.email, EXTRACT(YEAR FROM t.entry_timestamp)::INT, EXTRACT(MONTH FROM t.entry_timestamp)::INT)) AS total
    FROM
        trip t
    JOIN
        traveler tr ON t.traveler_id = tr.id
    GROUP BY
        EXTRACT(YEAR FROM t.entry_timestamp),
        EXTRACT(MONTH FROM t.entry_timestamp)
    HAVING
        COUNT(*) > 0
    ORDER BY
        year, month;

-- Tests
SELECT * FROM view_bill_per_month;




-- view_average_entries_station
CREATE OR REPLACE VIEW view_average_entries_station AS
    SELECT 
        s.type AS type,
        s.name AS station,
        ROUND(AVG(COUNT(t.id)) OVER (PARTITION BY s.id), 2) AS entries
    FROM 
        station s
    JOIN 
        trip t ON s.id = t.entry_station_id
    GROUP BY 
        s.type, s.name, s.id
    HAVING 
        COUNT(t.id) > 0
    ORDER BY 
        s.type, s.name;

-- Tests
SELECT * FROM view_average_entries_station;






-- view_current_non_paid_bills
CREATE OR REPLACE VIEW view_current_non_paid_bills AS
    SELECT 
        t.last_name AS lastname,
        t.first_name AS firstname,
        tr.id AS bill_number,
        add_bill(t.email, EXTRACT(YEAR FROM tr.entry_timestamp)::INT, EXTRACT(MONTH FROM tr.entry_timestamp)::INT) AS bill_amount
    FROM 
        trip tr
    JOIN 
        traveler t ON tr.traveler_id = t.id
    WHERE 
        tr.entry_station_id = 1 AND tr.exit_station_id = 2
    ORDER BY 
        t.last_name, t.first_name, tr.id;

-- Tests
SELECT * FROM view_current_non_paid_bills;