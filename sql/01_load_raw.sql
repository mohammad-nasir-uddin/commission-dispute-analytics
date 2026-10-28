/* =========================================================
   01_load_raw.sql
   Loads the 9 source CSVs into the raw schema exactly as received.
   Every column is NVARCHAR. Types are enforced later in staging.
   Safe to rerun.
   ========================================================= */

IF DB_ID('CommissionRecon') IS NULL
    CREATE DATABASE CommissionRecon;
GO
USE CommissionRecon;
GO
IF SCHEMA_ID('raw') IS NULL
    EXEC('CREATE SCHEMA raw');
GO

/* ---------- dealers ---------- */
DROP TABLE IF EXISTS raw.dealers;
CREATE TABLE raw.dealers (
    dealer_id          NVARCHAR(50),
    dealer_name        NVARCHAR(200),
    region             NVARCHAR(50),
    tier               NVARCHAR(20),
    tier_multiplier    NVARCHAR(20)
);
BULK INSERT raw.dealers
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\dealers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT LEN(tier_multiplier) AS len, COUNT(*) AS rows      -- expect lengths 3 or 4 only
FROM raw.dealers GROUP BY LEN(tier_multiplier);

/* ---------- comp_plan ---------- */
DROP TABLE IF EXISTS raw.comp_plan;
CREATE TABLE raw.comp_plan (
    plan_version       NVARCHAR(50),
    product_type       NVARCHAR(200),
    rate_plan          NVARCHAR(50),
    base_rate          NVARCHAR(20),
    effective_from     NVARCHAR(20),
    effective_to       NVARCHAR(20)
);
BULK INSERT raw.comp_plan
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\comp_plan.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT LEN(effective_to) AS len, COUNT(*) AS rows         -- expect 10 only
FROM raw.comp_plan GROUP BY LEN(effective_to);

/* ---------- deactivations ---------- */
DROP TABLE IF EXISTS raw.deactivations;
CREATE TABLE raw.deactivations (
    line_number        NVARCHAR(50),
    deactivation_date  NVARCHAR(20),
    reason             NVARCHAR(50)
);
BULK INSERT raw.deactivations
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\deactivations.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT reason, LEN(reason) AS len, COUNT(*) AS rows      -- expect lengths 8, 11, 16
FROM raw.deactivations GROUP BY reason;

/* ---------- map_dealer_code ---------- */
DROP TABLE IF EXISTS raw.map_dealer_code;
CREATE TABLE raw.map_dealer_code (
    dealer_code        NVARCHAR(50),
    dealer_id          NVARCHAR(50)
);
BULK INSERT raw.map_dealer_code
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\map_dealer_code.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT LEN(dealer_id) AS len, COUNT(*) AS rows            -- expect 4 only
FROM raw.map_dealer_code GROUP BY LEN(dealer_id);

/* ---------- map_plan_code ---------- */
DROP TABLE IF EXISTS raw.map_plan_code;
CREATE TABLE raw.map_plan_code (
    carrier_plan_code  NVARCHAR(20),
    rate_plan          NVARCHAR(50)
);
BULK INSERT raw.map_plan_code
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\map_plan_code.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT rate_plan, LEN(rate_plan) AS len                   -- expect ESSENTIAL 9, PLUS 4, PREMIUM 7, ALL 3
FROM raw.map_plan_code;

/* ---------- map_product_code ---------- */
DROP TABLE IF EXISTS raw.map_product_code;
CREATE TABLE raw.map_product_code (
    carrier_product_code NVARCHAR(20),
    product_type         NVARCHAR(50)
);
BULK INSERT raw.map_product_code
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\map_product_code.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT product_type, LEN(product_type) AS len             -- compare each length to the word
FROM raw.map_product_code;

/* ---------- protection_feed ---------- */
DROP TABLE IF EXISTS raw.protection_feed;
CREATE TABLE raw.protection_feed (
    enrolment_id       NVARCHAR(50),
    line_number        NVARCHAR(50),
    enrol_date         NVARCHAR(20),
    status             NVARCHAR(20),
    cancel_date        NVARCHAR(20)
);
BULK INSERT raw.protection_feed
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\protection_feed.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT CASE WHEN cancel_date IS NULL THEN 'NULL' ELSE 'has a value' END AS what_is_stored,
       MIN(LEN(cancel_date)) AS min_len, MAX(LEN(cancel_date)) AS max_len, COUNT(*) AS rows
FROM raw.protection_feed                                  -- expect NULL 7375, value 1048 at len 10
GROUP BY CASE WHEN cancel_date IS NULL THEN 'NULL' ELSE 'has a value' END;

/* ---------- carrier_statement ---------- */
DROP TABLE IF EXISTS raw.carrier_statement;
CREATE TABLE raw.carrier_statement (
    statement_line_id     NVARCHAR(50),
    statement_month       NVARCHAR(20),
    dealer_code           NVARCHAR(50),
    line_ref              NVARCHAR(50),
    carrier_product_code  NVARCHAR(20),
    carrier_plan_code     NVARCHAR(20),
    reported_txn_date     NVARCHAR(20),
    amount                NVARCHAR(50)
);
BULK INSERT raw.carrier_statement
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\carrier_statement.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT
    SUM(CASE WHEN amount LIKE '%' + CHAR(13) THEN 1 ELSE 0 END)                AS ends_with_cr,  -- expect 0
    SUM(CASE WHEN TRY_CAST(amount AS DECIMAL(10,2)) IS NULL THEN 1 ELSE 0 END) AS not_a_number,  -- expect 0
    MIN(TRY_CAST(amount AS DECIMAL(10,2))) AS min_amount,
    MAX(TRY_CAST(amount AS DECIMAL(10,2))) AS max_amount
FROM raw.carrier_statement;

/* ---------- pos_transactions ---------- */
DROP TABLE IF EXISTS raw.pos_transactions;
CREATE TABLE raw.pos_transactions (
    pos_txn_id         NVARCHAR(50),
    dealer_id          NVARCHAR(50),
    store_id           NVARCHAR(50),
    txn_date           NVARCHAR(20),
    line_number        NVARCHAR(50),
    product_type       NVARCHAR(50),
    rate_plan          NVARCHAR(50),
    sales_rep_id       NVARCHAR(50)
);
BULK INSERT raw.pos_transactions
FROM 'E:\da_projects\commission-dispute-analytics\commission-dispute-analytics\data\raw\pos_transactions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, ROWTERMINATOR = '0x0a', CODEPAGE = '65001');

SELECT LEN(sales_rep_id) AS len, COUNT(*) AS rows         -- expect 8 only
FROM raw.pos_transactions GROUP BY LEN(sales_rep_id);

/* ---------- final tie-out: every table vs its file ---------- */
SELECT table_name, row_count, expected,
       CASE WHEN row_count = expected THEN 'OK' ELSE 'MISMATCH' END AS status
FROM (
    SELECT 'dealers' AS table_name, COUNT(*) AS row_count, 40 AS expected FROM raw.dealers
    UNION ALL SELECT 'comp_plan',          COUNT(*), 20    FROM raw.comp_plan
    UNION ALL SELECT 'deactivations',      COUNT(*), 1310  FROM raw.deactivations
    UNION ALL SELECT 'map_dealer_code',    COUNT(*), 41    FROM raw.map_dealer_code
    UNION ALL SELECT 'map_plan_code',      COUNT(*), 4     FROM raw.map_plan_code
    UNION ALL SELECT 'map_product_code',   COUNT(*), 5     FROM raw.map_product_code
    UNION ALL SELECT 'protection_feed',    COUNT(*), 8423  FROM raw.protection_feed
    UNION ALL SELECT 'carrier_statement',  COUNT(*), 45188 FROM raw.carrier_statement
    UNION ALL SELECT 'pos_transactions',   COUNT(*), 47994 FROM raw.pos_transactions
) AS counts;