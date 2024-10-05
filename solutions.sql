-- Digital Analysis
-- 1 
SELECT COUNT(DISTINCT user_id) AS total_users
  FROM users

-- 2 
SELECT ROUND(COUNT(DISTINCT cookie_id))/COUNT(DISTINCT user_id), 1) AS avg_cookies_per_user
  FROM users

-- 3 

SELECT MONTH(event_time) as 'month',
       COUNT(DISTINCT visit_id) as total_visits
  FROM events
 GROUP BY MONTH(event_time);    

-- 4

SELECT i.event_name,
       COUNT(e.visit_id) AS total_visits
  FROM events AS e 
  JOIN event_identifier AS i ON i.event_type = e.event_type
 GROUP BY i.event_name
 ORDER BY total_visits DESC

-- 5 

SELECT ROUND(SUM(CASE WHEN ei.event_name = 'Purchase' THEN 1 ELSE 0 END)*100/COUNT(DISTINCT e.visit_id), 1) AS purchase_perc
  FROM events AS e
  JOIN event_identifier AS ei ON e.event_type = ei.event_type

-- 6 

WITH cte AS (
	SELECT e.visit_id,
		   MAX(CASE WHEN ei.event_name = 'Page view' AND ph.page_name = 'checkout' THEN 1 ELSE 0 END) AS viewed_checkout,
		   MAX(CASE WHEN ei.event_name = 'Purchase' THEN 1 ELSE 0 END) AS purchased
	  FROM events AS e 
      JOIN event_identifier AS ei ON e.event_type = ei.event_type 
      JOIN page_hierarchy AS ph ON e.page_id = ph.page_id 
	 GROUP BY e.visit_id
     ORDER BY 3
)
SELECT ROUND((SUM(viewed_checkout)-SUM(purchased))*100/SUM(viewed_checkout), 2) AS viewed_without_purchase_perc
  FROM cte;

-- 7 
SELECT ph.page_name, 
       COUNT(visit_id) AS total_views 
  FROM events AS e 
  JOIN page_hierarchy AS ph ON e.page_id = ph.page_id
 GROUP BY ph.page_name 
 ORDER BY total_views DESC
 LIMIT 3;

-- 8 
SELECT ph.product_category, 
	   SUM(CASE WHEN event_name = 'Page View' THEN 1 ELSE 0 END) AS total_views,
       SUM(CASE WHEN event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS total_cart_ad
  FROM events AS e 
  JOIN event_identifier AS ei ON e.event_type = ei.event_type 
  JOIN page_hierarchy AS ph ON e.page_id = ph.page_id
 WHERE product_category IS NOT NULL
 GROUP BY product_category;

-- 9 
WITH cte1 AS (
  SELECT DISTINCT visit_id AS purchase_id
    FROM events AS e 
    JOIN event_identifier AS ei ON e.event_type = ei.event_type
   WHERE ei.event_name = 'Purchase'
),
cte2 AS (
  SELECT ph.page_name,
         ph.page_id,
         e.visit_id 
    FROM events AS e
    LEFT JOIN page_hierarchy AS ph ON ph.page_id = e.page_id
	JOIN event_identifier AS ei ON e.event_type = ei.event_type
   WHERE ph.product_id IS NOT NULL AND ei.event_name = 'Add to Cart'
)
SELECT page_name AS Product,
       COUNT(*) AS Quantity_purchased
  FROM cte1 
  LEFT JOIN cte2 ON visit_id = purchase_id 
 GROUP BY page_name
 ORDER BY COUNT(*) DESC 
 LIMIT 3;



-- Product Funnel Analysis
-- 1 
CREATE TABLE product_summary AS (
WITH views_and_cart AS (
	SELECT e.visit_id, 
		   ph.page_name,
           SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) AS views,
           sSUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS add_to_cart
	  FROM events AS e 
      JOIN page_hierarchy AS ph ON e.page_id = ph.page_id 
	  JOIN event_identifier AS ei ON e.event_type = ei.event_type
	 WHERE ph.product_id IS NOT NULL
	 GROUP BY e.visit_id, ph.page_name
),
purchase_events AS (
	SELECT DISTINCT visit_id
      FROM events AS e 
      JOIN event_identifier AS ei ON e.event_type = ei.event_type
     WHERE ei.event_name = 'Purchase'
),
combined_table AS (
	SELECT vc.*, 
	       CASE WHEN pe.visit_id IS NOT NULL THEN 1 ELSE 0 END AS purchased
	  FROM views_and_cart AS vc 
      LEFT JOIN purchase_events AS pe ON vc.visit_id = pe.visit_id
)
SELECT page_name,
	   SUM(views) AS total_views,
       SUM(add_to_cart) AS total_cart_add,
       SUM(CASE WHEN add_to_cart = 1 AND purchased = 0 THEN 1 ELSE 0 END) AS total_add_no_purchase,
       SUM(CASE WHEN add_to_cart = 1 AND purchased = 1 THEN 1 ELSE 0 END) AS total_purchases
  FROM combined_table
  GROUP BY page_name
)
SELECT *
  FROM product_summary;

-- 2 
CREATE TABLE category_summary AS (
WITH views_and_cart AS (
	SELECT e.visit_id, 
		   ph.product_category,
           ph.page_name,
           SUM(CASE WHEN ei.event_name = 'Page View' THEN 1 ELSE 0 END) AS views,
           SUM(CASE WHEN ei.event_name = 'Add to Cart' THEN 1 ELSE 0 END) AS add_to_cart
	  FROM events AS e 
      JOIN page_hierarchy AS ph ON e.page_id = ph.page_id 
      JOIN event_identifier AS ei ON e.event_type = ei.event_type
	 WHERE ph.product_id IS NOT NULL
	 GROUP BY e.visit_id, ph.product_category, ph.page_name
),
purchase_events AS (
	SELECT DISTINCT visit_id
      FROM events AS e 
      JOIN event_identifier AS ei ON e.event_type = ei.event_type
     WHERE ei.event_name = 'Purchase'
),
combined_table AS (
	SELECT vc.*, 
	       CASE WHEN pe.visit_id IS NOT NULL THEN 1 ELSE 0 END AS purchased
	  FROM views_and_cart AS vc 
      LEFT JOIN purchase_events AS pe ON vc.visit_id = pe.visit_id
)
SELECT product_category,
	   SUM(views) AS total_views,
       SUM(add_to_cart) AS total_cart_add,
       SUM(CASE WHEN add_to_cart = 1 AND purchased = 0 THEN 1 ELSE 0 END) AS total_add_no_purchase,
       SUM(CASE WHEN add_to_cart = 1 AND purchased = 1 THEN 1 ELSE 0 END) AS total_purchases
  FROM combined_table
 GROUP BY product_category
);

SELECT page_name AS product_with_most_views
  FROM product_summary
 WHERE total_views = (SELECT MAX(total_views) FROM product_summary);

SELECT page_name AS product_with_most_cart_adds
  FROM product_summary
 WHERE total_cart_add = (SELECT MAX(total_cart_add) FROM product_summary);

SELECT page_name AS product_with_most_pruchases
  FROM product_summary
 WHERE total_purchases = (SELECT MAX(total_purchases) FROM product_summary);

SELECT page_name AS product_most_abonded
  FROM product_summary
 WHERE total_add_no_purchase = (SELECT MAX(total_add_no_purchase) FROM product_summary);

SELECT page_name AS product_most_abonded
  FROM product_summary
 WHERE total_purchases/total_views = (SELECT MAX(total_purchases/total_views) FROM product_summary);

SELECT ROUND(AVG(total_cart_add*100/total_views), 2) AS avg_add_to_cart_conversion_rate
  FROM product_summary;

SELECT ROUND(AVG(total_purchases*100/total_cart_add), 2) AS avg_purchase_conversion_rate
  FROM product_summary;



-- Campaign Analysis

SELECT MAX(u.user_id) AS user_id, 
       e.visit_id, 
       MIN(e.event_time) AS visit_start_time,
       SUM(IF(ei.event_name = 'Page View', 1, 0)) AS page_views,
	   SUM(IF(ei.event_name = 'Add to Cart', 1, 0)) AS cart_adds,
       MAX(IF(ei.event_name = 'Purchase', 1, 0)) AS purchase,
       MAX(ci.campaign_name) AS campaing, 
       SUM(IF(ei.event_name = 'Ad Impression', 1, 0)) AS impression, 
       SUM(IF(ei.event_name = 'Ad Click', 1, 0)) AS click,
       GROUP_CONCAT(CASE WHEN ei.event_name = 'Add to Cart' AND ph.product_id IS NOT NULL THEN ph.page_name ELSE NULL END ORDER BY e.event_time SEPARATOR ', ') AS cart_products
  FROM users AS u  
  JOIN events AS e ON e.cookie_id = u.cookie_id 
  JOIN event_identifier ei ON e.event_type = ei.event_type 
  JOIN campaign_identifier AS ci ON e.event_time BETWEEN ci.start_date AND ci.end_date
  JOIN page_hierarchy AS ph ON e.page_id = ph.page_id
 GROUP BY e.visit_id
 ORDER BY 1;