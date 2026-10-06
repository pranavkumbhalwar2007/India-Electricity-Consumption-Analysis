-- ============================================================
-- India Electricity Consumption Analysis
-- SQL: table setup, cleaning, and reusable views for Power BI
-- ============================================================

-- --------------------------------------------------------------
-- 1. TABLE SETUP
-- --------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS electricity_project;
USE electricity_project;

CREATE TABLE electricity_wide (
    Dates VARCHAR(10),
    Punjab DECIMAL(8,1), Haryana DECIMAL(8,1), Rajasthan DECIMAL(8,1),
    DD DECIMAL(8,1), DNH DECIMAL(8,1), Delhi DECIMAL(8,1), Chandigarh DECIMAL(8,1),
    UP DECIMAL(8,1), Uttarakhand DECIMAL(8,1), HP DECIMAL(8,1), `J&K` DECIMAL(8,1),
    Ladakh DECIMAL(8,1), Chhattisgarh DECIMAL(8,1), Gujarat DECIMAL(8,1),
    `MP` DECIMAL(8,1), Maharashtra DECIMAL(8,1), Goa DECIMAL(8,1),
    `DVC` DECIMAL(8,1), Bihar DECIMAL(8,1), Jharkhand DECIMAL(8,1),
    Odisha DECIMAL(8,1), `West Bengal` DECIMAL(8,1), Sikkim DECIMAL(8,1),
    `Andhra Pradesh` DECIMAL(8,1), Telangana DECIMAL(8,1), Karnataka DECIMAL(8,1),
    Kerala DECIMAL(8,1), `Tamil Nadu` DECIMAL(8,1), Pondy DECIMAL(8,1),
    `Essar steel` DECIMAL(8,1), Assam DECIMAL(8,1), Meghalaya DECIMAL(8,1),
    Manipur DECIMAL(8,1), Mizoram DECIMAL(8,1), Nagaland DECIMAL(8,1),
    Tripura DECIMAL(8,1), `Arunachal Pradesh` DECIMAL(8,1),
    `Total Consumption` DECIMAL(8,1)
);

-- Load raw CSV (local_infile must be enabled server-side and client-side)
LOAD DATA LOCAL INFILE 'Indias_Electricity_Consumption_Dataset.csv'
INTO TABLE electricity_wide
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- --------------------------------------------------------------
-- 2. DATA CLEANING
-- --------------------------------------------------------------

-- Fix: LOAD DATA silently converted NULL/empty values to 0 for several
-- structural-zero columns (DD, DNH, Pondy, Tripura, Essar steel) and,
-- separately, for Total Consumption itself (6 rows in April 2023)
UPDATE electricity_wide SET DD = NULL WHERE DD = 0;
UPDATE electricity_wide SET DNH = NULL WHERE DNH = 0;
UPDATE electricity_wide SET Pondy = NULL WHERE Pondy = 0;
UPDATE electricity_wide SET Tripura = NULL WHERE Tripura = 0;
UPDATE electricity_wide SET `Essar steel` = NULL WHERE `Essar steel` = 0;
UPDATE electricity_wide SET `Total Consumption` = NULL WHERE `Total Consumption` = 0;

-- Fix: Dates was imported as text (format mismatch on load); convert to a real DATE
ALTER TABLE electricity_wide ADD COLUMN date_fixed DATE;
UPDATE electricity_wide SET date_fixed = STR_TO_DATE(Dates, '%d-%m-%Y');
ALTER TABLE electricity_wide DROP COLUMN Dates;
ALTER TABLE electricity_wide CHANGE date_fixed Dates DATE;

-- --------------------------------------------------------------
-- 3. RESHAPE: wide -> long (one row per date per state)
-- --------------------------------------------------------------

CREATE TABLE electricity_long (
    date DATE,
    state VARCHAR(30),
    consumption DECIMAL(8,1)
);

INSERT INTO electricity_long (date, state, consumption)
SELECT Dates, 'Punjab', Punjab FROM electricity_wide
UNION ALL SELECT Dates, 'Haryana', Haryana FROM electricity_wide
UNION ALL SELECT Dates, 'Rajasthan', Rajasthan FROM electricity_wide
UNION ALL SELECT Dates, 'DD', DD FROM electricity_wide
UNION ALL SELECT Dates, 'DNH', DNH FROM electricity_wide
UNION ALL SELECT Dates, 'Delhi', Delhi FROM electricity_wide
UNION ALL SELECT Dates, 'Chandigarh', Chandigarh FROM electricity_wide
UNION ALL SELECT Dates, 'UP', UP FROM electricity_wide
UNION ALL SELECT Dates, 'Uttarakhand', Uttarakhand FROM electricity_wide
UNION ALL SELECT Dates, 'HP', HP FROM electricity_wide
UNION ALL SELECT Dates, 'J&K', `J&K` FROM electricity_wide
UNION ALL SELECT Dates, 'Ladakh', Ladakh FROM electricity_wide
UNION ALL SELECT Dates, 'Chhattisgarh', Chhattisgarh FROM electricity_wide
UNION ALL SELECT Dates, 'Gujarat', Gujarat FROM electricity_wide
UNION ALL SELECT Dates, 'MP', `MP` FROM electricity_wide
UNION ALL SELECT Dates, 'Maharashtra', Maharashtra FROM electricity_wide
UNION ALL SELECT Dates, 'Goa', Goa FROM electricity_wide
UNION ALL SELECT Dates, 'DVC', `DVC` FROM electricity_wide
UNION ALL SELECT Dates, 'Bihar', Bihar FROM electricity_wide
UNION ALL SELECT Dates, 'Jharkhand', Jharkhand FROM electricity_wide
UNION ALL SELECT Dates, 'Odisha', Odisha FROM electricity_wide
UNION ALL SELECT Dates, 'West Bengal', `West Bengal` FROM electricity_wide
UNION ALL SELECT Dates, 'Sikkim', Sikkim FROM electricity_wide
UNION ALL SELECT Dates, 'Andhra Pradesh', `Andhra Pradesh` FROM electricity_wide
UNION ALL SELECT Dates, 'Telangana', Telangana FROM electricity_wide
UNION ALL SELECT Dates, 'Karnataka', Karnataka FROM electricity_wide
UNION ALL SELECT Dates, 'Kerala', Kerala FROM electricity_wide
UNION ALL SELECT Dates, 'Tamil Nadu', `Tamil Nadu` FROM electricity_wide
UNION ALL SELECT Dates, 'Pondy', Pondy FROM electricity_wide
UNION ALL SELECT Dates, 'Essar steel', `Essar steel` FROM electricity_wide
UNION ALL SELECT Dates, 'Assam', Assam FROM electricity_wide
UNION ALL SELECT Dates, 'Meghalaya', Meghalaya FROM electricity_wide
UNION ALL SELECT Dates, 'Manipur', Manipur FROM electricity_wide
UNION ALL SELECT Dates, 'Mizoram', Mizoram FROM electricity_wide
UNION ALL SELECT Dates, 'Nagaland', Nagaland FROM electricity_wide
UNION ALL SELECT Dates, 'Tripura', Tripura FROM electricity_wide
UNION ALL SELECT Dates, 'Arunachal Pradesh', `Arunachal Pradesh` FROM electricity_wide;

-- --------------------------------------------------------------
-- 4. ANALYSIS VIEWS (every Power BI visual reads from one of these)
-- --------------------------------------------------------------

-- Month-wise average consumption, national and Maharashtra (seasonality)
CREATE VIEW monthly_seasonality AS
SELECT MONTH(Dates) AS months,
       AVG(`Total Consumption`) AS avg_total,
       AVG(Maharashtra) AS avg_maharashtra
FROM electricity_wide
GROUP BY MONTH(Dates)
ORDER BY months;

-- Average consumption by state (DVC and Essar steel excluded - not states)
CREATE VIEW state_ranking AS
SELECT state, AVG(consumption) AS avg_consumption
FROM electricity_long
WHERE state NOT IN ('DVC', 'Essar steel')
GROUP BY state
ORDER BY avg_consumption DESC;

-- Month-wise 2019 vs 2020 comparison, with % change (COVID impact)
CREATE VIEW covid_comparison AS
SELECT
    MONTH(Dates) AS months,
    AVG(CASE WHEN YEAR(Dates) = 2019 THEN `Total Consumption` END) AS avg_2019,
    AVG(CASE WHEN YEAR(Dates) = 2020 THEN `Total Consumption` END) AS avg_2020,
    ROUND(
      (AVG(CASE WHEN YEAR(Dates) = 2020 THEN `Total Consumption` END)
       - AVG(CASE WHEN YEAR(Dates) = 2019 THEN `Total Consumption` END))
      / AVG(CASE WHEN YEAR(Dates) = 2019 THEN `Total Consumption` END) * 100
    , 1) AS pct_change
FROM electricity_wide
WHERE YEAR(Dates) IN (2019, 2020)
GROUP BY MONTH(Dates)
ORDER BY months;

-- Year-over-year average consumption and % growth
CREATE VIEW yoy_growth AS
SELECT y AS year, avg_total,
    LAG(avg_total) OVER (ORDER BY y) AS prev_year_avg,
    ROUND((avg_total - LAG(avg_total) OVER (ORDER BY y))
          / LAG(avg_total) OVER (ORDER BY y) * 100, 1) AS yoy_pct_change
FROM (
    SELECT YEAR(Dates) AS y, AVG(`Total Consumption`) AS avg_total
    FROM electricity_wide
    GROUP BY YEAR(Dates)
) AS yearly;

-- Year x month grid of average consumption (for the heatmap / matrix visual)
CREATE VIEW monthly_yearly_grid AS
SELECT YEAR(Dates) AS yr, MONTH(Dates) AS mn, AVG(`Total Consumption`) AS avg_consumption
FROM electricity_wide
GROUP BY YEAR(Dates), MONTH(Dates)
ORDER BY yr, mn;

-- Yearly trend for the top 4 consuming states
CREATE VIEW state_yearly_trend AS
SELECT YEAR(date) AS yr, state, AVG(consumption) AS avg_consumption
FROM electricity_long
WHERE state IN ('Maharashtra', 'UP', 'Gujarat', 'Tamil Nadu')
GROUP BY YEAR(date), state
ORDER BY yr, state;

-- Top 5 states vs. all remaining states (share of total consumption)
CREATE VIEW top5_vs_rest AS
SELECT
    CASE WHEN state IN ('Maharashtra','UP','Gujarat','Tamil Nadu','Rajasthan')
         THEN 'Top 5 States' ELSE 'Remaining States' END AS grp,
    SUM(consumption) AS total_consumption
FROM electricity_long
WHERE state NOT IN ('DVC','Essar steel')
GROUP BY grp;

-- States vs. non-state entities (DVC, Essar steel) share of total consumption
CREATE VIEW states_vs_others AS
SELECT
    CASE WHEN state IN ('DVC', 'Essar steel') THEN 'Non-State Entities' ELSE 'States' END AS category,
    SUM(consumption) AS total
FROM electricity_long
GROUP BY category;
