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
SELECT add_transport_type('REA', 'RER A', 700, 50);

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
    id INT, 
    name VARCHAR(64), 
    town VARCHAR(32), 
    zone INT, 
    type VARCHAR(64)
) RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM station WHERE station.id = $1) THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM zone WHERE zone.number = $4) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO station (id, name, city, zone_number, type) 
    VALUES ($1, $2, $3, $4, $5);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;





--TESTS
SELECT add_station(11, 'République', 'Paris', 1, 'Bus');
SELECT add_station(12, 'Gare du Nord', 'Paris', 2, 'Trm');
SELECT add_station(13, 'Cergy-le-Haut', 'Cergy', 6, 'Mtr');
SELECT add_station(14, 'Montparnasse', 'Paris', 1, 'Bus');
SELECT add_station(17, 'Château d''eau', 'Paris', 1, 'Mtr');

SELECT add_station(15, 'Chatelet', 'Paris', 999, 'Bus');  -- Zone invalide







CREATE OR REPLACE FUNCTION add_line(
    code VARCHAR(3), 
    type VARCHAR(3)
) RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM line WHERE line.code = $1) THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM transport_type WHERE transport_type.id = $2) THEN
        RETURN FALSE;
    END IF;

    -- Ajouter la ligne
    INSERT INTO line (code, transport_type_id) 
    VALUES ($1, $2);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;





--TESTS
SELECT add_line('L1', 'Bus');
SELECT add_line('L7', 'Trm');

SELECT add_line('L2', 'InvalidType');  -- Doit échouer







CREATE OR REPLACE FUNCTION add_station_to_line(station_id INT, line_code CHAR(3)) 
RETURNS BOOLEAN AS $$
DECLARE
    station_type VARCHAR(64);
    line_type VARCHAR(64);
BEGIN
    -- Récupérer le type de la station
    SELECT type INTO station_type FROM station WHERE id = station_id;
    
    -- Récupérer le type de la ligne
    SELECT tt.line_name INTO line_type 
    FROM line l
    JOIN transport_type tt ON l.transport_type_id = tt.id
    WHERE l.code = line_code;
    
    -- Vérifier si les types sont compatibles
    IF station_type = line_type THEN
        RETURN TRUE;
    ELSE
        RAISE NOTICE 'Le type de la station n''est pas compatible avec le type de la ligne.';
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;






-- Test
SELECT add_station_to_line(1, 'RA', 1);
SELECT add_station_to_line(3, 'RA', 2);
SELECT add_station_to_line(4, 'RA', 3);

SELECT add_station_to_line(2, 'RA', 2); 

SELECT add_station_to_line(999, 'RA', 3); -- Doit échouer





-- VIEW
-- view_transport_50_300_users
CREATE OR REPLACE VIEW view_transport_50_300_users AS
    SELECT line_name AS transport
    FROM transport_type
    WHERE max_capacity BETWEEN 50 AND 300
    ORDER BY line_name;

-- Test
SELECT * FROM view_transport_50_300_users;







-- view_stations_from_paris
CREATE OR REPLACE VIEW view_stations_from_paris AS
    SELECT name AS station
    FROM station
    WHERE LOWER(city) = 'paris'
    ORDER BY name;

SELECT * FROM view_stations_from_paris;






-- view_stations_zones
CREATE OR REPLACE VIEW view_stations_zones AS
    SELECT 
        s.name AS station,
        z.name AS zone
    FROM 
        station s
    JOIN 
        zone z
    ON 
        s.zone_number = z.number
    ORDER BY 
        z.number ASC, 
        s.name ASC;


SELECT * FROM view_stations_zones;






-- view_nb_station_type
CREATE OR REPLACE VIEW view_nb_station_type AS
    SELECT 
        s.type AS type,
        COUNT(*) AS stations
    FROM 
        station s
    GROUP BY 
        s.type
    ORDER BY 
        stations DESC, 
        s.type ASC;



SELECT * FROM view_nb_station_type;






-- view_line_duration
CREATE OR REPLACE VIEW view_line_duration AS
    SELECT 
        tt.line_name AS type,
        l.code AS line,
        (tt.average_duration * COUNT(ls.station_id)) AS minutes
    FROM 
        line AS l
    JOIN 
        transport_type AS tt ON l.transport_type_id = tt.id
    JOIN 
        line_station AS ls ON l.code = ls.line_code
    GROUP BY 
        tt.line_name, l.code, tt.average_duration
    ORDER BY 
        tt.line_name ASC, 
        l.code ASC;



SELECT * FROM view_line_duration;







-- view_station_capacity
CREATE OR REPLACE VIEW view_station_capacity AS
    SELECT 
        s.name AS station,
        tt.max_capacity AS capacity
    FROM 
        station s
    JOIN 
        line_station ls ON s.id = ls.station_id
    JOIN 
        line l ON ls.line_code = l.code
    JOIN 
        transport_type tt ON l.transport_type_id = tt.id
    WHERE 
        s.name ILIKE 'A%'
    ORDER BY 
        s.name ASC, 
        tt.max_capacity;



SELECT * FROM view_station_capacity;






-- PROCEDURES
-- list_station_in_line
CREATE OR REPLACE FUNCTION list_station_in_line(p_line_code VARCHAR(3))
RETURNS SETOF VARCHAR(64) AS $$
BEGIN
    RETURN QUERY
    SELECT s.name
    FROM station s
    JOIN line_station ls ON s.id = ls.station_id
    WHERE ls.line_code = p_line_code
    ORDER BY ls.position ASC;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM list_station_in_line('RA');


-- list types in zone 
CREATE OR REPLACE FUNCTION list_types_in_zone(zone INT)
RETURNS SETOF VARCHAR(32) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT tt.line_name
    FROM station s
    JOIN transport_type tt ON s.type = tt.id
    WHERE s.zone_number = zone
    ORDER BY tt.line_name ASC;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM list_types_in_zone(1);







CREATE OR REPLACE FUNCTION get_cost_travel(station_start INT, station_end INT)
RETURNS FLOAT AS $$
DECLARE
    start_zone INT;
    end_zone INT;
    total_cost FLOAT := 0;
BEGIN
    -- Vérifier si les stations existent
    IF NOT EXISTS (SELECT 1 FROM station WHERE id = station_start) OR
       NOT EXISTS (SELECT 1 FROM station WHERE id = station_end) THEN
        RETURN 0;
    END IF;

    -- Récupérer les zones des stations
    SELECT zone_number INTO start_zone FROM station WHERE id = station_start;
    SELECT zone_number INTO end_zone FROM station WHERE id = station_end;

    -- Calculer le coût total du voyage
    IF start_zone <= end_zone THEN
        FOR i IN start_zone..end_zone LOOP
            SELECT price INTO total_cost FROM zone WHERE number = i;
        END LOOP;
    ELSE
        FOR i IN end_zone..start_zone LOOP
            SELECT price INTO total_cost FROM zone WHERE number = i;
        END LOOP;
    END IF;

    RETURN total_cost;
END;
$$ LANGUAGE plpgsql;


SELECT get_cost_travel(1, 3);
