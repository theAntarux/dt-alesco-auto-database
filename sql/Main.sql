USE WAREHOUSE KOALA_WH;
CREATE OR REPLACE DATABASE DASAUTO;
USE DATABASE DASAUTO;

CREATE OR REPLACE SCHEMA DASAUTO;
USE SCHEMA DASAUTO;
------------------------------------------------------

--> CREATING STAGE AREA <--

CREATE OR REPLACE TABLE alesco_auto_staging AS 
SELECT * FROM ALESCO_AUTO_DATABASE_SAMPLE.PUBLIC.AUTO_DATA_SAMPLE_VIEW;

--> Review
SELECT * FROM alesco_auto_staging LIMIT 10;
DESCRIBE TABLE alesco_auto_staging;
------------------------------------------------------

--> DIMENSION TABLES (STAR SCHEMATIC) <--

/* 
Household dimension table
Household information (estimated income, home value, ownership/rental status, number of vehicles, and presence of children).
*/
CREATE OR REPLACE TABLE dim_household AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY HOUSEHOLD_ID) AS HOUSEHOLD_KEY,
        HOUSEHOLD_ID,
        HOME_OWNER_RENTER,
        HOME_MARKET_VALUE,
        INCOME_ESTIMATED_HOUSEHOLD,
        NUMBER_OF_VEHICLES_PER_HOUSEHOLD,
        PRESENCE_OF_CHILDREN
    FROM alesco_auto_staging
    WHERE HOUSEHOLD_ID IS NOT NULL
);

--> Review
SELECT * FROM dim_household LIMIT 10;
DESCRIBE TABLE dim_household;
------------------------------------------------------

/* 
Person dimension table
Owner's personal data (first name, last name, title, gender, and persistent ID).
*/
CREATE OR REPLACE TABLE dim_person AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY PERSISTENT_ID) AS PERSON_KEY,
        PERSISTENT_ID,
        PREFIX,
        FIRST,
        MI,
        LAST,
        GENDER
    FROM alesco_auto_staging
    WHERE PERSISTENT_ID IS NOT NULL
);

--> Review
SELECT * FROM dim_person LIMIT 10;
DESCRIBE TABLE dim_person;
------------------------------------------------------

/*
Address dimension table
Detailed address (street, city, state, ZIP code, coordinates, length of residence, and delivery codes).
*/
CREATE OR REPLACE TABLE dim_address AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY ADDRESS_ID) AS ADDRESS_KEY,
        ADDRESS_ID,
        FULL_ADDRESS,
        
        /*
        Splitting FULL_ADDRESS into STREET_NUMBER and STREET_NAME, took us a while to figure this one out lol
        https://docs.snowflake.com/en/sql-reference/functions/charindex
        https://docs.snowflake.com/en/sql-reference/functions/substr
        https://stackoverflow.com/questions/55502441/how-to-split-the-address-string-house-number-and-street-name-using-sql
        */
        LEFT(FULL_ADDRESS, CHARINDEX(' ', FULL_ADDRESS) - 1) AS STREET_NUMBER,
        SUBSTR(FULL_ADDRESS, CHARINDEX(' ', FULL_ADDRESS) + 1) AS STREET_NAME,
        
        ADDRESS_LINE,
        CITY,
        STATE,
        ZIP5,
        ZIP4,
        COUNTY_NAME,
        LATITUDE,
        LONGITUDE,
        ADDRESS_TYPE_INDICATOR,
        CARRIER_ROUTE,
        SCF_CODE,
        DELIVERY_POINT_BAR_CODE,
        DPV_INDICATOR,
        LENGTH_OF_RESIDENCE
        
    FROM alesco_auto_staging
    WHERE ADDRESS_ID IS NOT NULL AND CHARINDEX(' ', FULL_ADDRESS) > 0
);

--> Review
SELECT * FROM dim_address LIMIT 10;
DESCRIBE TABLE dim_address;
------------------------------------------------------

/*
Vehicle dimension table
Vehicle information (VIN, year of manufacture, manufacturer, make, model, class, fuel type, and estimated mileage).
*/
CREATE OR REPLACE TABLE dim_vehicle AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY VIN) AS VEHICLE_KEY,
        VIN,
        AUTO_YEAR::INT AS AUTO_YEAR,
        AUTO_MANUFACTURER_CODE,
        AUTO_MAKE_CODE,
        AUTO_MODEL_CODE,
        AUTO_MAKE_MODEL_CODE,
        VEHICLE_CLASS_DESCRIPTION,
        VEHICLE_STYLE_CODE,
        VEHICLE_FUEL_CODE,
        MILEAGE_CODE
        
    FROM alesco_auto_staging
    WHERE VIN IS NOT NULL
);

--> Review
SELECT * FROM dim_vehicle LIMIT 10;
DESCRIBE TABLE dim_vehicle;
------------------------------------------------------

/*
Contact dimension table
Contact details (persistent ID, email, phone, email types, and DNC status).
*/
CREATE OR REPLACE TABLE dim_contact AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY PERSISTENT_ID, EMAIL) AS CONTACT_KEY,
        PERSISTENT_ID,
        EMAIL,
        EMAIL_PRESENT,
        EMAIL_MATCH_TYPE,
        EMAIL_USE_CASE,
        PHONE,
        DNC
        
    FROM alesco_auto_staging
    WHERE PERSISTENT_ID IS NOT NULL
);

--> Review
SELECT * FROM dim_contact LIMIT 10;
DESCRIBE TABLE dim_contact;
------------------------------------------------------

/*
Geography dimension table
Geographic context (FIPS codes, CBSA/MSA, census tract/block, and time zone).
*/
CREATE OR REPLACE TABLE dim_geography AS (
    SELECT DISTINCT
        ROW_NUMBER() OVER (ORDER BY FIPS_STATE_COUNTY_CODE, CENSUS_BLOCK) AS GEOGRAPHY_KEY,
        FIPS_STATE_COUNTY_CODE,
        CBSA_CODE,
        CBSA_NAME,
        MSA_CODE,
        MSA_NAME,
        CENSUS_TRACT,
        CENSUS_BLOCK_GROUP,
        CENSUS_BLOCK,
        TIME_ZONE
        
    FROM alesco_auto_staging
    WHERE FIPS_STATE_COUNTY_CODE IS NOT NULL
);

--> Review
SELECT * FROM dim_geography LIMIT 10;
DESCRIBE TABLE dim_geography;
------------------------------------------------------

/*
Date dimension table
Date hierarchy (year, quarter, month, day). Used for the date of first and last registration.
*/
CREATE OR REPLACE TABLE dim_date AS (
    WITH all_date AS (
        SELECT DATE(FIRST_SEEN_DATE) AS date_text FROM alesco_auto_staging
        UNION 
        SELECT TRY_TO_DATE(LAST_SEEN_DATE) AS date_text FROM alesco_auto_staging
    )
    SELECT 
        TO_CHAR(DATE(date_text), 'YYYYMMDD'):: INT AS DATE_KEY,
        date_text AS FULL_DATE,
        YEAR(DATE(date_text)) AS YEAR,
        MONTH(date_text) AS MONTH,
        DAY(date_text) AS DAY,
        QUARTER(date_text) AS QUARTER,
    CASE
        DAYNAME(date_text)
        WHEN 'Mon' THEN 'Monday'
        WHEN 'Tue' THEN 'Tuesday'
        WHEN 'Wed' THEN 'Wednesday'
        WHEN 'Thu' THEN 'Thursday'
        WHEN 'Fri' THEN 'Friday'
        WHEN 'Sat' THEN 'Saturday'
        WHEN 'Sun' THEN 'Sunday'
    END AS WEEKDAY
    FROM all_date
    WHERE date_text IS NOT NULL
);

--> Review
SELECT * FROM dim_date LIMIT 10;
DESCRIBE TABLE dim_date;
------------------------------------------------------

--> CENTRAL TABLE FACTS a.k.a. joining all the dim tables into one lmao <--

CREATE OR REPLACE TABLE fact_vehicle_ownership AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY s.PERSISTENT_ID, s.VIN) AS FACT_KEY,

        g.GEOGRAPHY_KEY AS DIM_GEOGRAPHY_KEY,
        c.CONTACT_KEY AS DIM_CONTACT_KEY,
        v.VEHICLE_KEY AS DIM_VEHICLE_KEY,
        p.PERSON_KEY AS DIM_PERSON_KEY,
        a.ADDRESS_KEY AS DIM_ADDRESS_KEY,
        h.HOUSEHOLD_KEY AS DIM_HOUSEHOLD_KEY,
        d_first.DATE_KEY AS DIM_DATE_FIRST_KEY,
        d_last.DATE_KEY AS DIM_DATE_LAST_KEY,

        --> Rank of the vehicles in households
        RANK() OVER ( 
            PARTITION BY s.HOUSEHOLD_ID
            ORDER BY v.AUTO_YEAR DESC
        ) AS VEHICLE_RANK_IN_HOUSEHOLD,

        --> Total Number of vehicles
        COUNT(*) OVER () AS TOTAL_VEHICLES_GLOBAL,

        --> Average age of manufactured vehicles in a given ZIP5 (ZIP code)
        AVG(v.AUTO_YEAR::INT) OVER (
            PARTITION BY a.ZIP5
        ) AS REGIONAL_AVG_YEAR

    FROM alesco_auto_staging s

    JOIN dim_geography g
        ON s.FIPS_STATE_COUNTY_CODE = g.FIPS_STATE_COUNTY_CODE
    JOIN dim_contact c
        ON s.PERSISTENT_ID = c.PERSISTENT_ID
    JOIN dim_vehicle v
        ON s.VIN = v.VIN
    JOIN dim_person p
        ON s.PERSISTENT_ID = p.PERSISTENT_ID
    JOIN dim_address a
        ON s.ADDRESS_ID = a.ADDRESS_ID
    JOIN dim_household h
        ON s.HOUSEHOLD_ID = h.HOUSEHOLD_ID
    JOIN dim_date d_first
        ON TO_CHAR(DATE(s.FIRST_SEEN_DATE), 'YYYYMMDD')::INT = d_first.DATE_KEY
    LEFT JOIN dim_date d_last
        ON TO_CHAR(TRY_TO_DATE(s.LAST_SEEN_DATE), 'YYYYMMDD')::INT = d_last.DATE_KEY

    WHERE s.PERSISTENT_ID IS NOT NULL
        AND s.VIN IS NOT NULL
        AND s.HOUSEHOLD_ID IS NOT NULL
);

--> Review
SELECT * FROM fact_vehicle_ownership;
DESCRIBE TABLE fact_vehicle_ownership;
------------------------------------------------------

--> DROPPING ALL THE STAGING TABLES <--

DROP TABLE IF EXISTS alesco_auto_staging;
------------------------------------------------------
