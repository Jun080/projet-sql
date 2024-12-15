CREATE OR REPLACE FUNCTION add_transport_type(
    code VARCHAR(3), 
    name VARCHAR(32), 
    capacity INT, 
    avg_interval INT
) RETURNS BOOLEAN AS $$
BEGIN
  
    IF EXISTS (SELECT 1 FROM transport_type WHERE id = code OR line_name = name) THEN
        RETURN FALSE;
    END IF;

   
    INSERT INTO transport_type (id, line_name, max_capacity, average_duration)
    VALUES (code, name, capacity, avg_interval);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--TESTS
SELECT add_transport_type('Bus', 'Bus', 100, 15);
SELECT add_transport_type('Trm', 'Tramway', 200, 20);
SELECT add_transport_type('Sub', 'Subway', 300, 10);


SELECT add_transport_type('Mtr', 'Metro', 500, 5);

SELECT add_transport_type('Bus', 'Bus', 150, 10);  -- Doit échouer







CREATE OR REPLACE FUNCTION add_zone(name VARCHAR(32), price DECIMAL)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO zone (name, price) VALUES (name, price);
    RETURN TRUE;
EXCEPTION
    WHEN others THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


--TESTS
SELECT add_zone('Centre', 2.50);
SELECT add_zone('Nord', 1.80);
SELECT add_zone('Sud', 1.20);

SELECT add_zone('Est', 1.50);

SELECT add_zone('Ouest', -5);  -- Doit échouer







CREATE OR REPLACE FUNCTION add_station(
    name VARCHAR(64), 
    town VARCHAR(32), 
    zone_name VARCHAR(32),  
    type VARCHAR(3)
) RETURNS BOOLEAN AS $$
DECLARE
    zone_number INT;
BEGIN
   
    IF NOT EXISTS (SELECT 1 FROM transport_type WHERE id = type) THEN
        RETURN FALSE;
    END IF;

    SELECT number INTO zone_number 
    FROM zone 
    WHERE name = zone_name; 

    IF zone_number IS NULL THEN
        RETURN FALSE; 
    END IF;

    INSERT INTO station (name, city, zone_number) 
    VALUES (name, town, zone_number);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

--CA MARCHE PASSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS



--TESTS
SELECT add_station(1, "Château d'Eau", 'Paris', 1, 'Bus');
SELECT add_station(2, 'République', 'Paris', 1, 'Bus');
SELECT add_station(3, 'Gare du Nord', 'Paris', 2, 'Trm');
SELECT add_station(4, "Place d'Italie", 'Paris', 3, 'Sub');
SELECT add_station(5, "Château d'Eau", 'Paris', 1, 'Sub');
SELECT add_station('Cergy-le-Haut', 'Cergy', 'Centre', 'M01');


SELECT add_station('Cergy-le-Haut', 'Cergy', 'Centre', 'M01');

SELECT add_station(6, 'Montparnasse', 'Paris', 1, 'Bus');

SELECT add_station(7, 'InvalidStation', 'Paris', 999, 'Bus');  -- Doit échouer