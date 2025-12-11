# Import order: Independents first (brands, categories, customers, stores) -> products, staff -> stocks, orders -> order_items

-- Initial scan of data 

SELECT *
FROM brands;

SELECT *
FROM categories;

SELECT *
FROM customers; # NULL phone numbers, 

SELECT *
FROM order_items; 

SELECT *
FROM orders; # NULL shipped_dates

SELECT *
FROM products;

SELECT *
FROM staff; # NULL manager_id for Fabiola Jackson, is he the manager?

SELECT *
FROM stocks; # 0 for quantity, probably not an error 

SELECT *
FROM stores; 

-- Look for duplicate values

SELECT # As Primary Keys are used, highly unlikely for duplicates. Another way to check is by checking duplicate emails
    email, 
    COUNT(email) as count
FROM customers
GROUP BY email
HAVING count > 1;

SELECT shipped_date, order_date # Logical test to see if any orders are stated to be shipped before they were ordered
FROM orders
WHERE shipped_date < order_date;

SELECT o.product_id, o.order_id # Check if there is any missing items from product_id that doesn't exist that was ordered 
FROM order_items o
LEFT JOIN products p # Products is used as a left reference to see if there's anything missing
	ON o.product_id = p.product_id
WHERE p.product_id IS NULL; # If orders had been used instead, it would not show the nulls

-- Exploratory Data Analysis (EDA)

# To identify best selling items

SELECT # Needs to be joined with products and categories to identify the top selling categories and products
    c.category_name, 
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name
ORDER BY total_revenue DESC; # Mountain Bikes are the top selling item

# To identify percentage of sales

WITH Category_Stats AS (
SELECT 
    c.category_name, 
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
    
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_name
ORDER BY total_revenue DESC
)
SELECT category_name, total_revenue, (total_revenue/SUM(total_revenue) OVER()) * 100 percentage # OVER() helps to calculate grand total
FROM Category_Stats; # Mountain Bikes produce 35.3% of revenue, with Road Bikes and Cruiser Bikes coming in 2nd and 3rd with 21.6% and 12.9%

-- Find the best selling employee 

# To find the revenue by staff, we'll need to combine staff table and order_items table. But they don't have a direct link.
# Thus, join staff on orders by staff_id, then join order_items on orders by order_id

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
FROM Staff_Revenue
ORDER BY total_revenue DESC; # Marcelene Boyer is the top sales staff, raking in more than 34% of total sales, with Venita Daniel coming in 2nd at 33.7% of revenue.
# Bike store should keep them and promote them to further incentivise loyalty. Layla Terrell hs the lowest sales at only 5.24% of revenue. Store should focus on training her.
# Possible improvements: Create a time-adjusted revenue for the staff to see who performed best with time/experience equalised.


-- Time Series Analysis of revenue to track M-o-M growth 

SELECT *
FROM orders; # Needs orders for order_date

SELECT *
FROM order_items; # Needs order_items for the sales

SELECT # Main query for monthly revenue ordered by year and month in chronological order
	YEAR(o.order_date),
    MONTH(o.order_date),
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM 
	order_items oi
JOIN orders o
	ON oi.order_id = o.order_id 
GROUP BY 
	YEAR(o.order_date),
    MONTH(o.order_date)
ORDER BY
	YEAR(o.order_date) ASC,
    MONTH(o.order_date) ASC;
    
WITH Monthly_Growth AS
(SELECT
	YEAR(o.order_date) order_year,
    MONTH(o.order_date) order_month,
    SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_revenue
FROM 
	order_items oi
JOIN orders o
	ON oi.order_id = o.order_id 
GROUP BY 
	YEAR(o.order_date),
    MONTH(o.order_date)
ORDER BY
	YEAR(o.order_date) ASC,
    MONTH(o.order_date) ASC)
SELECT 
	order_year,
    order_month,
    total_revenue,
    (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year, order_month)) / LAG(total_revenue) OVER (ORDER BY order_year, order_month) * 100 AS growth_percentage  
# Similar to SUM() OVER() but LAG() peeks at previous row instead of over entire table
FROM Monthly_Growth; # 2018 July had the best MoM growth, with 5899%, which is an anomaly. Either 2018 June sales were very bad, or they did something very well.