create table city
(
	city_id	int primary key,
	city_name	varchar(30),
	population	bigint,
	estimated_rent	float,
	city_rank int
);

create table customers
(
	customer_id	int primary key,
	customer_name	varchar(40),
	city_id int,
	constraint fk_city foreign key(city_id) references city(city_id)
);

create table products
(
	product_id	int primary key,
	product_name	varchar(40),
	price float
);

create table sales
(
	sale_id	int primary key,
	sale_date	date,
	product_id	int,
	customer_id	int,
	total	float,
	rating int,
	constraint fk_products foreign key(product_id) references products(product_id),
	constraint fk_customers foreign key(customer_id) references customers(customer_id)
);

-- import rules
-- 1st import to city
-- 2nd import to products
-- 3rd import to customers
-- 4th import to sales

select count(*) from city;
select count(*) from products;
select count(*) from customers;
select count(*) from sales;

select * from city;
select * from products;
select * from customers;
select * from sales;

--1. **Coffee Consumers Count**  
--  How many people in each city are estimated to consume coffee, given that 25% of the population does?

select city_name , (population * 25/100) as pop
from city
order by 2 desc

--2. **Total Revenue from Coffee Sales**  
--  What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select ci.city_name, sum(s.total)

from sales as s
join customers as c
on s.customer_id = c.customer_id
join city as ci
on c.city_id = ci.city_id

where 
	extract (year from s.sale_date)= 2023 
	and
	extract (quarter from s.sale_date)= 4
group by 1
order by 2 desc;

--3. **Sales Count for Each Product**  
-- How many units of each coffee product have been sold?

select product_name, count(s.sale_id) as total_orders
from products as p
join sales as s
on p.product_id = s.product_id
group by 1
order by 2 desc;

--4. **Average Sales Amount per City**  
-- What is the average sales amount per customer in each city?

select city_name, sum(total), count(distinct s.customer_id) as total_cx, 
	round(sum(total):: numeric / 
		count(distinct s.customer_id):: numeric
		  ,2) as avg_sales_customer
from sales as s
join customers as c
on s.customer_id = c.customer_id
join city as ci
on c.city_id = ci.city_id
group by 1
order by 4 desc;

--5. **City Population and Coffee Consumers**  
-- Provide a list of cities along with their populations and estimated coffee consumers. 
-- return city_name, total current cx, estimated coffee consumers(25%)

with city_table as 
(
	select city_name,
	(population * 0.25) as coffee_consumers
from city
),

customers_table
as
(
	select city_name, count(distinct customer_id) as unique_cx
from city as ci
join customers as c
on ci.city_id = c.city_id
group by 1
order by 2 desc
)
select 
	customers_table.city_name,
	city_table.coffee_consumers,
	customers_table.unique_cx
from city_table
join customers_table
on city_table.city_name = customers_table.city_name

--6.**Top Selling Products by City**  
--   What are the top 3 selling products in each city based on sales volume?

select *
from 
(
select ci.city_name, p.product_name, 
	count(s.sale_id),
	dense_rank() over(partition by ci.city_name order by count(s.sale_id) desc) as rank
from sales as s
join products as p
on s.product_id = p.product_id
join customers as c
on c.customer_id = s.customer_id 
join city as ci
on ci.city_id = c.city_id
group by 1,2
order by 1,3 desc
)
where rank <= 3

--7. **Customer Segmentation by City**  
-- How many unique customers are there in each city who have purchased coffee products?

select ci.city_name, count(distinct c.customer_id) as unique_cx
from city as ci
join customers as c
on ci.city_id = c.city_id
join sales as s
on s.customer_id = c.customer_id
where 
	s.product_id in(1,2,3,4,5,6,7,8,9,10,11,12,13,14)
group by 1

--8. **Average Sale vs Rent**  
-- Find each city and their average sale per customer and avg rent per customer

WITH city_table
AS
(
	SELECT 
		ci.city_name,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)::numeric/
					COUNT(DISTINCT s.customer_id)::numeric
				,2) as avg_sale_pr_cx
		
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
city_rent
AS
(SELECT 
	city_name, 
	estimated_rent
FROM city
)
SELECT 
	cr.city_name,
	cr.estimated_rent,
	ct.total_cx,
	ct.avg_sale_pr_cx,
	ROUND(
		cr.estimated_rent::numeric/
									ct.total_cx::numeric
		, 2) as avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
ORDER BY 4 DESC
	
--9. **Monthly Sales Growth**  
  -- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly).
  
  WITH
monthly_sales
AS
(
	SELECT 
		ci.city_name,
		EXTRACT(MONTH FROM sale_date) as month,
		EXTRACT(YEAR FROM sale_date) as YEAR,
		SUM(s.total) as total_sale
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1, 2, 3
	ORDER BY 1, 3, 2
),
growth_ratio
AS
(
		SELECT
			city_name,
			month,
			year,
			total_sale as cr_month_sale,
			LAG(total_sale, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
		FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cr_month_sale,
	last_month_sale,
	ROUND(
		(cr_month_sale-last_month_sale)::numeric/last_month_sale::numeric * 100
		, 2
		) as growth_ratio

FROM growth_ratio
WHERE 
	last_month_sale IS NOT NULL	

--10. **Market Potential Analysis**  
--  Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated  coffee consumer

WITH city_table
AS
(
	SELECT 
		ci.city_name,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)::numeric/
					COUNT(DISTINCT s.customer_id)::numeric
				,2) as avg_sale_pr_cx
		
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2 DESC
),
city_rent
AS
(
	SELECT 
		city_name, 
		estimated_rent,
		ROUND((population * 0.25)/1000000, 3) as estimated_coffee_consumer_in_millions
	FROM city
)
SELECT 
	cr.city_name,
	total_revenue,
	cr.estimated_rent as total_rent,
	ct.total_cx,
	estimated_coffee_consumer_in_millions,
	ct.avg_sale_pr_cx,
	ROUND(
		cr.estimated_rent::numeric/
									ct.total_cx::numeric
		, 2) as avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
ORDER BY 2 DESC

/*
-- Recomendation
City 1: Pune
	1.Average rent per customer is very low.
	2.Highest total revenue.
	3.Average sales per customer is also high.

City 2: Delhi
	1.Highest estimated coffee consumers at 7.7 million.
	2.Highest total number of customers, which is 68.
	3.Average rent per customer is 330 (still under 500).

City 3: Jaipur
	1.Highest number of customers, which is 69.
	2.Average rent per customer is very low at 156.
	3.Average sales per customer is better at 11.6k.
