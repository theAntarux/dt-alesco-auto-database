USE WAREHOUSE KOALA_WH;
USE DATABASE DASAUTO;
USE SCHEMA DASAUTO;
------------------------------------------------------

--> Visualization 1: TOP 10 states by number of vehicles
SELECT 
    a.STATE,
    COUNT(*) AS VEHICLE_COUNT,
    ROUND((COUNT(*) / MAX(f.TOTAL_VEHICLES_GLOBAL)) * 100, 2) AS MARKET_SHARE_PCT
FROM fact_vehicle_ownership f
JOIN dim_address a ON f.DIM_ADDRESS_KEY = a.ADDRESS_KEY
GROUP BY a.STATE 
ORDER BY VEHICLE_COUNT DESC LIMIT 10;
------------------------------------------------------

--> Visualization 2: TOP 5 manufacturers
SELECT 
    v.AUTO_MANUFACTURER_CODE,
    COUNT(*) AS VEHICLE_COUNT
FROM fact_vehicle_ownership f
JOIN dim_vehicle v ON f.DIM_VEHICLE_KEY = v.VEHICLE_KEY
GROUP BY v.AUTO_MANUFACTURER_CODE LIMIT 5;
------------------------------------------------------

--> Visualization 3: Fuel type distribution
SELECT 
    v.VEHICLE_FUEL_CODE,
    COUNT(*) AS VEHICLE_COUNT
FROM fact_vehicle_ownership f
JOIN dim_vehicle v ON f.DIM_VEHICLE_KEY = v.VEHICLE_KEY
GROUP BY v.VEHICLE_FUEL_CODE;
------------------------------------------------------

--> Visualization 4: Vehicle ownership by gender
SELECT 
    p.GENDER,
    COUNT(*) AS VEHICLE_COUNT
FROM fact_vehicle_ownership f 
JOIN dim_person p ON f.DIM_PERSON_KEY = p.PERSON_KEY
GROUP BY p.GENDER;
------------------------------------------------------

--> Visualization 5: Distribution of vehicles by year of manufacture
SELECT
    v.AUTO_YEAR,
    COUNT(*) AS VEHICLE_COUNT
FROM fact_vehicle_ownership f
JOIN dim_vehicle v ON f.DIM_VEHICLE_KEY = v.VEHICLE_KEY 
WHERE v.AUTO_YEAR IS NOT NULL
GROUP BY v.AUTO_YEAR ORDER BY v.AUTO_YEAR;
------------------------------------------------------

--> Visualization 6: Concentration of vehicles by home market value
SELECT 
    h.HOME_MARKET_VALUE,
    AVG(f.VEHICLE_RANK_IN_HOUSEHOLD) AS AVG_CARS_PER_HOUSEHOLD
FROM fact_vehicle_ownership f
JOIN dim_household h ON f.DIM_HOUSEHOLD_KEY = h.HOUSEHOLD_KEY 
WHERE h.HOME_MARKET_VALUE IS NOT NULL
GROUP BY h.HOME_MARKET_VALUE
ORDER BY h.HOME_MARKET_VALUE;
------------------------------------------------------
