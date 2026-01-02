-- placeholder for the actual project queries, it exists because of the linting action checkup

CREATE OR REPLACE TABLE sql_test_db.analytics.customer_summary AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name  AS full_name,
    COUNT(o.order_id)                   AS total_orders,
    SUM(o.order_total)                  AS total_spent,
    AVG(o.order_total)                  AS avg_order_value,
    MAX(o.order_date)                   AS last_order_date
FROM
    sql_test_db.raw.customers AS c
LEFT JOIN
    sql_test_db.raw.orders AS o
    ON c.customer_id = o.customer_id
WHERE
    c.signup_date >= '2024-01-01'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
HAVING
    total_orders > 5
ORDER BY
    total_spent DESC
LIMIT 100;