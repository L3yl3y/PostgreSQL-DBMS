-- Question Q1.1: Top 5 Most Popular Genres
CREATE VIEW V_POPULAR_GENRES AS
SELECT genre, COUNT(*) AS total
FROM Works W
JOIN Items I ON W.isbn = I.isbn
JOIN Events E ON I.item_id = E.item_id
WHERE E.event_type IN ('Loan', 'Hold')
GROUP BY genre
ORDER BY total DESC
LIMIT 5;

-- Query to report results
SELECT * FROM V_POPULAR_GENRES;

-- Query plan
EXPLAIN ANALYZE SELECT * FROM V_POPULAR_GENRES;

-- Question Q1.2: Top 5 Patrons Paying Most Charges
CREATE VIEW V_COSTS_INCURRED AS
WITH Child_Losses AS (
    SELECT E.patron_id AS ChildId, E.charge, E.time_stamp
    FROM Events E
    JOIN Patrons P ON E.patron_id = P.patron_id
    WHERE E.event_type = 'Loss'
    AND AGE(P.dob) < INTERVAL '18 years'
    AND E.time_stamp BETWEEN '2024-01-01' AND '2024-06-30'
),
GuardianCharge AS (
    SELECT SUM(C.charge) AS TotalCharges, P.guardian
    FROM Child_Losses C
    JOIN Patrons P ON C.ChildId = P.patron_id
    WHERE P.guardian IS NOT NULL
    GROUP BY P.guardian
)
SELECT GC.guardian, GC.TotalCharges
FROM GuardianCharge GC
ORDER BY GC.TotalCharges DESC
LIMIT 5;

-- Query to report results
SELECT * FROM V_COSTS_INCURRED;

-- Question Q1.3: Materialized View
CREATE MATERIALIZED VIEW MY_COSTS_INCURRED AS
WITH Child_Losses AS (
    SELECT E.patron_id AS ChildId, E.charge, E.time_stamp
    FROM Events E
    JOIN Patrons P ON E.patron_id = P.patron_id
    WHERE E.event_type = 'Loss'
    AND AGE(P.dob) < INTERVAL '18 years'
    AND E.time_stamp BETWEEN '2024-01-01' AND '2024-06-30'
),
GuardianCharge AS (
    SELECT SUM(C.charge) AS TotalCharges, P.guardian
    FROM Child_Losses C
    JOIN Patrons P ON C.ChildId = P.patron_id
    WHERE P.guardian IS NOT NULL
    GROUP BY P.guardian
)
SELECT GC.guardian, GC.TotalCharges
FROM GuardianCharge GC
ORDER BY GC.TotalCharges DESC
LIMIT 5;

-- Question Q2.1: Create Index
CREATE INDEX IDX_EVENT_ITEM ON Events (event_type, item_id);

-- Rerun query
EXPLAIN ANALYZE SELECT * FROM V_POPULAR_GENRES;

-- Question Q2.2: Function-Based Index
-- Step 1: Create regex expression to extract last name
SELECT regexp_substr(author, ' (.*)', 1, 1, 'c') AS surname FROM Works;

-- Step 2: Query plan
EXPLAIN ANALYZE SELECT regexp_substr(author, ' (.*)', 1, 1, 'c') AS surname FROM Works;

-- Step 3: Create index
CREATE INDEX IDX_AUTHOR ON Works (author);

-- Step 4: Query plan after index creation
EXPLAIN ANALYZE SELECT regexp_substr(author, ' (.*)', 1, 1, 'c') AS surname FROM Works;

-- Question Q3: Queries with varying scan types
-- Condition 1: Both Index and Sequential Scans enabled
SET enable_seqscan = ON;
SET enable_indexscan = ON;
SET enable_bitmapscan = ON;
SET enable_indexonlyscan = ON;

-- Condition 2: Index Scans enabled and Sequential Scans suppressed
SET enable_seqscan = OFF;
SET enable_indexscan = ON;
SET enable_bitmapscan = ON;
SET enable_indexonlyscan = ON;

-- Condition 3: Index Scans suppressed and Sequential Scans enabled
SET enable_seqscan = ON;
SET enable_indexscan = OFF;
SET enable_bitmapscan = OFF;
SET enable_indexonlyscan = OFF;

-- Question Q4: Transactions
-- Step 1: Begin Transaction to Identify Returned Item
BEGIN;
SELECT item_id
FROM Events E
WHERE event_type = 'Return'
ORDER BY time_stamp DESC
LIMIT 1;

-- Step 2: Begin Another Transaction to Record Hold on Item
BEGIN;
INSERT INTO EVENTS (event_id, patron_id, item_id, event_type, time_stamp, charge)
VALUES (NEXTVAL('events_event_id_seq'), 1, 'UQ10000119361', 'Hold', NOW() + INTERVAL '14 days', 0);
COMMIT;

-- Step 3: Attempt to Record Loan on Item for Different Patron
BEGIN;
INSERT INTO EVENTS (event_id, patron_id, item_id, event_type, time_stamp, charge)
VALUES (NEXTVAL('events_event_id_seq'), 2, 'UQ10000119361', 'Loan', NOW(), 0);
COMMIT;