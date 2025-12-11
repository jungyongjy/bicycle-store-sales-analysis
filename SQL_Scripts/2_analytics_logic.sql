# Category of sales view
CREATE OR REPLACE VIEW v_sales_by_category AS
SELECT 
    c.category_name, 
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name;

# Staff sales view
CREATE OR REPLACE VIEW v_staff_performance AS
WITH Staff_Revenue AS (
    SELECT 
        s.staff_id,
        s.first_name,
        s.last_name,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN staff s ON s.staff_id = o.staff_id
    GROUP BY s.staff_id, s.first_name, s.last_name
)
SELECT 
    first_name, 
    last_name, 
    total_revenue, 
    (total_revenue / SUM(total_revenue) OVER()) * 100 AS percentage
FROM Staff_Revenue;

# MoM revenue view
CREATE OR REPLACE VIEW v_monthly_sales_growth AS
WITH Monthly_Stats AS (
    SELECT 
        YEAR(o.order_date) AS order_year,
        MONTH(o.order_date) AS order_month,
        SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id 
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT 
    order_year,
    order_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_year, order_month) AS previous_revenue,
    -- Handling the "Divide by Zero" risk for the first month
    IFNULL(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year, order_month)) 
        / LAG(total_revenue) OVER (ORDER BY order_year, order_month) * 100, 
    0) AS growth_percentage
FROM Monthly_Stats;