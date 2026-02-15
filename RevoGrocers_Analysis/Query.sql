
--1. Highest Revenue Category (After Discount)
SELECT
    categoryName
    ,CAST(ROUND(SUM(t2.quantity * t3.price * (1 - t2.discount)), 0) AS INT64) AS total_revenue_after_discount
FROM `fsda-sql-01.grocery_dataset.categories` AS t1
INNER JOIN  `fsda-sql-01.grocery_dataset.products` AS t3
    ON t1.categoryid = t3.categoryid
INNER JOIN
    `fsda-sql-01.grocery_dataset.sales` AS t2
    ON t3.productid = t2.productid
GROUP BY
    t1.categoryName
ORDER BY
    total_revenue_after_discount DESC
LIMIT 5;


--2. Assessing the relationship between revenue after discount and total units sold per category:
SELECT
    t1.categoryName
    ,CAST(ROUND(SUM(t2.quantity * t3.price * (1 - t2.discount)), 0) AS INT64) AS total_revenue_after_discount
    ,SUM(t2.quantity) AS total_units_sold
FROM
    `fsda-sql-01.grocery_dataset.categories` AS t1
INNER JOIN
    `fsda-sql-01.grocery_dataset.products` AS t3
    ON t1.categoryid = t3.categoryid
INNER JOIN
    `fsda-sql-01.grocery_dataset.sales` AS t2
    ON t3.productid = t2.productid
-- Based on the inspection results
WHERE
    t2.quantity > 0
    AND t3.price > 0
    AND t2.discount BETWEEN 0 AND 1
    AND t2.SalesDate IS NOT NULL
GROUP BY
    t1.categoryName
ORDER BY
    total_revenue_after_discount DESC;


--3. Relationship Between Revenue After Discount and The Number of Unique Customers
SELECT
    t1.categoryName
    ,CAST(ROUND(SUM(t2.quantity * t3.price * (1 - t2.discount)), 0) AS INT64) AS total_revenue_after_discount
    ,COUNT(DISTINCT t2.customerid) AS number_of_unique_customers
FROM
    `fsda-sql-01.grocery_dataset.categories` AS t1
INNER JOIN
    `fsda-sql-01.grocery_dataset.products` AS t3
    ON t1.categoryid = t3.categoryid
INNER JOIN
    `fsda-sql-01.grocery_dataset.sales` AS t2
    ON t3.productid = t2.productid
-- -- Based on the inspection data cleaning results
WHERE
    t2.quantity > 0
    AND t3.price > 0
    AND t2.discount BETWEEN 0 AND 1
    AND t2.SalesDate IS NOT NULL
GROUP BY
    t1.categoryName
ORDER BY
    total_revenue_after_discount DESC;


--4.Calculate the average unit price for each product category
SELECT
    t1.categoryName
    ,ROUND(AVG(t3.price), 2) AS average_price_per_unit
FROM
    `fsda-sql-01.grocery_dataset.categories` AS t1
INNER JOIN
    `fsda-sql-01.grocery_dataset.products` AS t3
    ON t1.categoryid = t3.categoryid
WHERE
    t3.price > 0
GROUP BY
    t1.categoryName
ORDER BY
    average_price_per_unit DESC;

--5.Relationship between Average Unit Price and Unique Customer
WITH AvgPrice AS (
    SELECT
        t1.categoryid,
        t1.categoryName,
        ROUND(AVG(t2.price), 2) AS average_price_per_unit
    FROM
        `fsda-sql-01.grocery_dataset.categories` AS t1
    INNER JOIN
        `fsda-sql-01.grocery_dataset.products` AS t2
        ON t1.categoryid = t2.categoryid
    WHERE
        t2.price > 0
    GROUP BY
        t1.categoryid, t1.categoryName
),
UniqueCustomers AS (
    SELECT
        t2.categoryid,
        COUNT(DISTINCT t1.customerid) AS number_of_unique_customers
    FROM
        `fsda-sql-01.grocery_dataset.sales` AS t1
    INNER JOIN
        `fsda-sql-01.grocery_dataset.products` AS t2
        ON t1.productid = t2.productid
    WHERE
        t1.SalesDate IS NOT NULL AND t1.quantity > 0 AND t1.discount BETWEEN 0 AND 1
    GROUP BY
        t2.categoryid
)
SELECT
    t1.categoryName,
    t1.average_price_per_unit,
    t2.number_of_unique_customers
FROM
    AvgPrice AS t1
INNER JOIN
    UniqueCustomers AS t2
    ON t1.categoryid = t2.categoryid
ORDER BY
    t1.average_price_per_unit DESC
limit 5;


--6 categories contribute the most to overall revenue after discount
SELECT
    categoryName
    ,CAST(ROUND(SUM(t2.quantity * t3.price * (1 - t2.discount)), 0) AS INT64) AS total_revenue_after_discount    
    ,CONCAT(CAST(ROUND(SUM(t2.quantity * t3.price * (1 - t2.discount)) / SUM(SUM(t2.quantity * t3.price * (1 - t2.discount))) OVER () * 100, 2) AS STRING), '%') AS revenue_contribution_percentage
FROM `fsda-sql-01.grocery_dataset.categories` AS t1
INNER JOIN `fsda-sql-01.grocery_dataset.products` AS t3
    ON t1.categoryid = t3.categoryid
INNER JOIN `fsda-sql-01.grocery_dataset.sales` AS t2
    ON t3.productid = t2.productid
WHERE
    t2.quantity > 0 
    AND t3.price > 0 
    AND t2.discount BETWEEN 0 AND 1 
    AND t2.SalesDate IS NOT NULL
GROUP BY categoryName
ORDER BY total_revenue_after_discount DESC
LIMIT 5;

--7.
WITH CustomerRepeatIdentifier AS (
    SELECT
        categoryName,
        customerid,
        COUNT(t1.salesid) AS transaction_count 
    FROM `fsda-sql-01.grocery_dataset.sales` AS t1
    INNER JOIN `fsda-sql-01.grocery_dataset.products` AS t2 ON t1.productid = t2.productid
    INNER JOIN `fsda-sql-01.grocery_dataset.categories` AS t3 ON t2.categoryid = t3.categoryid
    GROUP BY 1, 2
),

CategoryRPRMetrics AS (
    SELECT
        cri.categoryName,
        COUNT(DISTINCT cri.customerid) AS total_unique_customers, 
        COUNTIF(cri.transaction_count >= 2) AS repeat_buyers_count 
    FROM
        CustomerRepeatIdentifier AS cri
    GROUP BY
        cri.categoryName
)
    SELECT
        categoryName,
        total_unique_customers,
        repeat_buyers_count,
        CONCAT(CAST(ROUND((CAST(repeat_buyers_count AS FLOAT64) / total_unique_customers) * 100 , 2) AS STRING), '%') AS                
        repeat_purchase_rate_percentage
    FROM CategoryRPRMetrics
ORDER BY CAST(REPLACE(repeat_purchase_rate_percentage, '%', '') AS FLOAT64) DESC
limit 5;

--9. Cumulative Transaction Amount Top User
WITH CustomerRevenue AS (
    SELECT
        customerid,
        SUM(price * quantity * (1 - discount)) AS total_customer_revenue
    FROM
        `fsda-sql-01.grocery_dataset.sales` AS t1
    INNER JOIN
        `fsda-sql-01.grocery_dataset.products` AS t2 ON t1.productid = t2.productid
    GROUP BY
        customerid
),
RankedCustomerRevenue AS (
    SELECT
        customerid,
        total_customer_revenue,
        RANK() OVER (ORDER BY total_customer_revenue DESC) AS revenue_rank,
        SUM(total_customer_revenue) OVER (ORDER BY total_customer_revenue DESC) AS cumulative_revenue
    FROM
        CustomerRevenue
)
SELECT
    customerid,
    total_customer_revenue,
    revenue_rank,
    cumulative_revenue
FROM
    RankedCustomerRevenue
WHERE
    revenue_rank = 1
ORDER BY
    revenue_rank;








