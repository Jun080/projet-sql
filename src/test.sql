DROP TABLE IF EXISTS subscription CASCADE;
DROP TABLE IF EXISTS pass CASCADE;
DROP TABLE IF EXISTS trip CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS traveler CASCADE;
DROP TABLE IF EXISTS line_station CASCADE;
DROP TABLE IF EXISTS station CASCADE;
DROP TABLE IF EXISTS line CASCADE;
DROP TABLE IF EXISTS zone CASCADE;
DROP TABLE IF EXISTS transport_type CASCADE;
DROP TABLE IF EXISTS contract CASCADE;
DROP TABLE IF EXISTS department CASCADE;

CREATE TABLE transport_type (
    id CHAR(3),
    line_name VARCHAR(32) NOT NULL,
    max_capacity INTEGER NOT NULL,
    average_duration INTEGER NOT NULL CHECK (average_duration > 0),
    PRIMARY KEY (id)
);

CREATE TABLE zone (
    number INTEGER,
    name VARCHAR(32) NOT NULL,
    price DECIMAL(5,2) NOT NULL CHECK (price >= 0),
    PRIMARY KEY (number)
);

CREATE TABLE line (
    code CHAR(3),
    transport_type_id CHAR(3) NOT NULL,
    PRIMARY KEY (code),
    FOREIGN KEY (transport_type_id) REFERENCES transport_type(id)
);

CREATE TABLE station (
    id SERIAL,
    name VARCHAR(64) NOT NULL,
    city VARCHAR(32) NOT NULL,
    zone_number INTEGER,
    PRIMARY KEY (id),
    FOREIGN KEY (zone_number) REFERENCES zone(number)
);

CREATE TABLE line_station (
    line_code CHAR(3),
    station_id INTEGER,
    position INTEGER NOT NULL CHECK (position > 0),
    PRIMARY KEY (line_code, station_id, position),
    FOREIGN KEY (line_code) REFERENCES line(code),
    FOREIGN KEY (station_id) REFERENCES station(id)
);

CREATE TABLE traveler (
    id SERIAL,
    last_name VARCHAR(32) NOT NULL,
    first_name VARCHAR(32) NOT NULL,
    email VARCHAR(128) NOT NULL,
    phone CHAR(10) NOT NULL,
    address TEXT NOT NULL,
    postal_code CHAR(5) NOT NULL,
    city VARCHAR(32) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE employee (
    id INTEGER,
    login VARCHAR(20) NOT NULL,
    PRIMARY KEY (id),
    FOREIGN KEY (id) REFERENCES traveler(id)
);

CREATE TABLE department (
    name VARCHAR(32),
    discount DECIMAL(5,2) NOT NULL CHECK (discount >= 0 AND discount <= 100),
    PRIMARY KEY (name)
);

CREATE TABLE contract (
    employee_id INTEGER,
    hire_date DATE NOT NULL,
    departure_date DATE,
    department_name VARCHAR(32),
    PRIMARY KEY (employee_id, hire_date),
    FOREIGN KEY (employee_id) REFERENCES employee(id),
    FOREIGN KEY (department_name) REFERENCES department(name)
);

CREATE TABLE trip (
    id SERIAL,
    traveler_id INTEGER,
    entry_timestamp TIMESTAMP NOT NULL,
    entry_station_id INTEGER,
    exit_timestamp TIMESTAMP,
    exit_station_id INTEGER,
    PRIMARY KEY (id),
    FOREIGN KEY (traveler_id) REFERENCES traveler(id),
    FOREIGN KEY (entry_station_id) REFERENCES station(id),
    FOREIGN KEY (exit_station_id) REFERENCES station(id)
);

CREATE TABLE pass (
    code CHAR(5),
    name VARCHAR(32) NOT NULL,
    monthly_price DECIMAL(10,2) NOT NULL CHECK (monthly_price >= 0),
    duration INTEGER NOT NULL CHECK (duration >= 1),
    min_zone INTEGER,
    max_zone INTEGER,
    PRIMARY KEY (code),
    FOREIGN KEY (min_zone) REFERENCES zone(number),
    FOREIGN KEY (max_zone) REFERENCES zone(number)
);

CREATE TABLE subscription (
    id SERIAL,
    traveler_id INTEGER,
    pass_code CHAR(5),
    subscription_date DATE NOT NULL,
    status VARCHAR(10) CHECK (status IN ('Registered', 'Pending', 'Incomplete')) NOT NULL,
    iban VARCHAR(34),
    proof_of_residence TEXT,
    PRIMARY KEY (id),
    FOREIGN KEY (traveler_id) REFERENCES traveler(id),
    FOREIGN KEY (pass_code) REFERENCES pass(code)
);



INSERT INTO zone (number, name, price) VALUES
(1, 'Zone 1', 0.50),
(2, 'Zone 2', 0.70),
(3, 'Zone 3', 0.90),
(4, 'Zone 4', 1.10),
(5, 'Zone 5', 1.30);

INSERT INTO transport_type (id, line_name, max_capacity, average_duration) VALUES
('M01', 'Line 1', 600, 2),
('T01', 'Line 3', 300, 3),
('B01', 'Line 131', 80, 10);

INSERT INTO line (code, transport_type_id) VALUES
('M1', 'M01'),
('T3', 'T01'),
('131', 'B01');

INSERT INTO station (name, city, zone_number) VALUES
('Cergy-le-Haut', 'Cergy', 5),
('Marne-la-Vallée-Chessy', 'Marne-la-Vallée', 5),
('Argenteuil', 'Argenteuil', 4),
('Paris', 'Paris', 1);

INSERT INTO line_station (line_code, station_id, position) VALUES
('M1', 1, 1),
('M1', 2, 2),
('T3', 3, 1),
('T3', 4, 2),
('131', 3, 1),
('131', 4, 2);

INSERT INTO department (name, discount) VALUES
('Accounting', 10.0),
('Inspectors', 100.0);