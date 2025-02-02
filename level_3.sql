-- add_service
CREATE OR REPLACE FUNCTION add_service(
    name VARCHAR(32),
    discount INT
) RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM department WHERE department.name = add_service.name) THEN
        RETURN FALSE;
    END IF;

    IF discount < 0 OR discount > 100 THEN
        RETURN FALSE;
    END IF;

    -- Ajouter le service
    INSERT INTO department (name, discount)
    VALUES (add_service.name, discount);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT add_service('IT', 15);
SELECT add_service('HR', 20);
SELECT add_service('IT', 25); -- Doit échouer
SELECT add_service('Finance', 105); -- Doit échouer



-- add_contract
CREATE OR REPLACE FUNCTION add_contract(
    login VARCHAR(20),
    email VARCHAR(128),
    date_beginning DATE,
    service VARCHAR(32)
) RETURNS BOOLEAN AS $$
DECLARE
    emp_id INT;
    last_contract_end DATE;
BEGIN
    SELECT id INTO emp_id FROM traveler WHERE traveler.email = add_contract.email;
    IF emp_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM employee WHERE employee.login = add_contract.login) THEN
        RETURN FALSE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM department WHERE department.name = add_contract.service) THEN
        RETURN FALSE;
    END IF;

    SELECT MAX(departure_date) INTO last_contract_end FROM contract WHERE contract.employee_id = emp_id;

    IF last_contract_end IS NOT NULL AND date_beginning <= last_contract_end THEN
        RETURN FALSE;
    END IF;

    INSERT INTO employee (id, login) VALUES (emp_id, add_contract.login);

    INSERT INTO contract (employee_id, hire_date, department_name) 
    VALUES (emp_id, date_beginning, add_contract.service);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT add_contract('jdoe', 'john.doe@example.com', '2023-01-01', 'IT');
SELECT add_contract('asmith', 'alice.smith@example.com', '2023-02-01', 'HR');
SELECT add_contract('jdoe', 'john.doe@example.com', '2023-03-01', 'Finance'); -- Doit échouer
SELECT add_contract('bwayne', 'bruce.wayne@example.com', '2023-01-01', 'InvalidService'); -- Doit échouer




-- end_contract
CREATE OR REPLACE FUNCTION end_contract(
    email VARCHAR(128),
    date_end DATE
) RETURNS BOOLEAN AS $$
DECLARE
    emp_id INT;
    current_contract_start DATE;
BEGIN
    SELECT id INTO emp_id FROM traveler WHERE traveler.email = end_contract.email;
    IF emp_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT hire_date INTO current_contract_start 
    FROM contract 
    WHERE employee_id = emp_id AND departure_date IS NULL;

    IF current_contract_start IS NULL THEN
        RETURN FALSE;
    END IF;

    IF date_end < current_contract_start THEN
        RETURN FALSE;
    END IF;

    UPDATE contract
    SET departure_date = date_end
    WHERE employee_id = emp_id AND hire_date = current_contract_start;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT end_contract('john.doe@example.com', '2023-12-31');
SELECT end_contract('alice.smith@example.com', '2023-12-31');
SELECT end_contract('john.doe@example.com', '2023-01-01'); -- Doit échouer
SELECT end_contract('bruce.wayne@example.com', '2023-12-31'); -- Doit échouer



-- update_service
CREATE OR REPLACE FUNCTION update_service(
    name VARCHAR(32),
    discount INT
) RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM department WHERE department.name = update_service.name) THEN
        RETURN FALSE;
    END IF;

    IF discount < 0 OR discount > 100 THEN
        RETURN FALSE;
    END IF;

    UPDATE department
    SET discount = update_service.discount
    WHERE department.name = update_service.name;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT update_service('IT', 20);
SELECT update_service('HR', 25);
SELECT update_service('Finance', 105); -- Doit échouer
SELECT update_service('InvalidService', 15); -- Doit échouer



-- update_employee_mail
CREATE OR REPLACE FUNCTION update_employee_email(
    login VARCHAR(20),
    email VARCHAR(128)
) RETURNS BOOLEAN AS $$
DECLARE
    current_email VARCHAR(128);
BEGIN
    SELECT traveler.email INTO current_email
    FROM traveler
    JOIN employee ON traveler.id = employee.id
    WHERE employee.login = update_employee_email.login;

    IF current_email IS NULL THEN
        RETURN FALSE;
    END IF;

    IF current_email = update_employee_email.email THEN
        RETURN TRUE;
    END IF;

    IF EXISTS (SELECT 1 FROM traveler WHERE traveler.email = update_employee_email.email) THEN
        RETURN FALSE;
    END IF;

    UPDATE traveler
    SET email = update_employee_email.email
    WHERE id = (SELECT id FROM employee WHERE employee.login = update_employee_email.login);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Tests
SELECT update_employee_email('jdoe', 'john.doe@newdomain.com');
SELECT update_employee_email('asmith', 'alice.smith@newdomain.com');
SELECT update_employee_email('jdoe', 'john.doe@example.com'); -- Doit renvoyer true
SELECT update_employee_email('bwayne', 'bruce.wayne@example.com'); -- Doit échouer
SELECT update_employee_email('jdoe', 'alice.smith@example.com'); -- Doit échouer





-- view_employees
CREATE OR REPLACE VIEW view_employees AS
    SELECT 
        traveler.last_name AS lastname,
        traveler.first_name AS firstname,
        employee.login,
        contract.department_name AS service
    FROM 
        traveler
    JOIN 
        employee ON traveler.id = employee.id
    JOIN 
        contract ON employee.id = contract.employee_id
    WHERE 
        contract.departure_date IS NULL
    ORDER BY 
        traveler.last_name, traveler.first_name, employee.login;

-- Test
SELECT * FROM view_employees;




-- view_nb_employees_per_service
CREATE OR REPLACE VIEW view_nb_employees_per_service AS
    SELECT 
        d.name AS service,
        COUNT(e.id) AS nb
    FROM 
        department d
    LEFT JOIN 
        contract c ON d.name = c.department_name AND c.departure_date IS NULL
    LEFT JOIN 
        employee e ON c.employee_id = e.id
    GROUP BY 
        d.name
    ORDER BY 
        d.name ASC;

-- Test
SELECT * FROM view_nb_employees_per_service;





-- list_login_employee
CREATE OR REPLACE FUNCTION list_login_employee(date_service DATE) 
RETURNS SETOF VARCHAR(20) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.login
    FROM 
        employee e
    JOIN 
        contract c ON e.id = c.employee_id
    WHERE 
        c.hire_date <= date_service AND (c.departure_date IS NULL OR c.departure_date >= date_service)
    ORDER BY 
        e.login;
END;
$$ LANGUAGE plpgsql;

-- Test
SELECT * FROM list_login_employee('2023-04-01');
SELECT * FROM list_login_employee('2024-04-01');





-- list_employee_service
CREATE OR REPLACE FUNCTION list_not_employee(date_service DATE)
RETURNS TABLE(
    lastname VARCHAR(32),
    firstname VARCHAR(32),
    has_worked TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.last_name AS lastname,
        t.first_name AS firstname,
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM contract c 
                WHERE c.employee_id = t.id
            ) THEN 'YES'
            ELSE 'NO'
        END AS has_worked
    FROM 
        traveler t
    WHERE 
        NOT EXISTS (
            SELECT 1 
            FROM contract c 
            WHERE c.employee_id = t.id 
            AND c.hire_date <= date_service 
            AND (c.departure_date IS NULL OR c.departure_date >= date_service)
        )
    ORDER BY 
        has_worked DESC, t.last_name, t.first_name;
END;
$$ LANGUAGE plpgsql;

-- Test
SELECT * FROM list_not_employee('2023-04-01');
SELECT * FROM list_not_employee('2024-04-01');
SELECT * FROM list_not_employee('2025-04-01');





-- list_subscription_history
CREATE OR REPLACE FUNCTION list_subscription_history(
    email VARCHAR(128)
) RETURNS TABLE(
    type TEXT,
    name VARCHAR,
    start_date DATE,
    duration INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'sub' AS type,
        s.pass_code::VARCHAR AS name,
        s.subscription_date AS start_date,
        (s.subscription_date + (p.duration || ' month')::INTERVAL) - s.subscription_date AS duration
    FROM 
        subscription s
    JOIN 
        traveler t ON s.traveler_id = t.id
    JOIN 
        pass p ON s.pass_code = p.code
    WHERE 
        t.email = list_subscription_history.email

    UNION ALL

    SELECT 
        'ctr' AS type,
        c.department_name AS name,
        c.hire_date AS start_date,
        CASE 
            WHEN c.departure_date IS NOT NULL THEN AGE(c.departure_date, c.hire_date)
            ELSE NULL
        END AS duration
    FROM 
        contract c
    JOIN 
        traveler t ON c.employee_id = t.id
    WHERE 
        t.email = list_subscription_history.email

    ORDER BY 
        start_date;
END;
$$ LANGUAGE plpgsql;

-- Test
SELECT * FROM list_subscription_history('alice.smith@example.com');