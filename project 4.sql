show tables;
use gdb023;
select * from dim_customer;
select * from fact_pre_invoice_deductions;

# 1. Provide a list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.
SELECT DISTINCT
    market
FROM
    dim_customer
WHERE
    customer = 'Atliq Exclusive'
        AND region = 'APAC';

# 2. What is the percentage of unique product increse in 2020 vs 2021? The final outfut contain these: unique_product_2020, unique_product_2021, percentage.
with cte1 as (select count(distinct product_code) as product_2020
              from  fact_sales_monthly
              where fiscal_year = 2020 )
              ,
     cte2 as (select count(distinct product_code) as product_2021
              from fact_sales_monthly
              where fiscal_year = 2021 )
              
select cte1.product_2020, cte2.product_2021,
       round((product_2021 - product_2020)*100/(product_2020),2) as percent_difference
from cte1, cte2;

# 3. Provide a report with all the unique product counts for each segment and sort them in desc order of product counts. 
# The final output contains two fiels - Segment, unique product count.

SELECT 
    segment,
    COUNT(DISTINCT product_code) AS unique_product_counts
FROM
    dim_product
GROUP BY segment
ORDER BY unique_product_counts DESC;

# 4. Which segment has the most increse in unique product 2020 vs. 2021. 
# The final output contain these field - segment, product_count_2020, product_count_2021
with cte1 as 
(select p.segment, count(distinct f.product_code) as product_2020
 from dim_product as p
 join fact_sales_monthly as f
 on p.product_code = f.product_code
 where f.fiscal_year = 2020
 group by p.segment
 order by product_2020)
 ,
 cte2 as 
 (select p.segment, count(distinct f.product_code) as product_2021
  from dim_product as p
  join fact_sales_monthly as f
  on p.product_code = f.product_code
  where f.fiscal_year = 2021
  group by p.segment
  order by product_2021
  )
  select cte1.segment, cte1.product_2020, cte2.product_2021, ((cte2.product_2021) - (cte1.product_2020)) as product_differance
  from cte1, cte2
  where cte1.segment = cte2.segment
  group by cte1.segment
  order by product_differance desc;
  
  # 5. Get the products that have the highest and lowest manufacturing_cost. 
  # The output should contain these field: Product_code, Product, manufacturing_cost. 
  with cte1 as 
  (select p.product_code, p.product, manufacturing_cost
  from dim_product as p
  join fact_manufacturing_cost as m
  on p.product_code = m.product_code
  where manufacturing_cost = (select max(manufacturing_cost) from fact_manufacturing_cost))
  ,
  cte2 as 
  (select p.product_code, p.product, manufacturing_cost
  from dim_product as p
  join fact_manufacturing_cost as m
  on p.product_code = m.product_code
  where manufacturing_cost = (select min(manufacturing_cost) from fact_manufacturing_cost))
  select cte1.product_code, 
		 cte1.product, 
         manufacturing_cost
  from cte1
  union
  select cte2.product_code,
         cte2.product,
         manufacturing_cost
  from cte2;
  
  /* 6.Generate a report which contain the top 5 customer who recived an average high pre_invoice_discount_pct for the year 2021
      and in the Indian market. 
      The final output contains these field: customer, customer_code, average_discount_pct. */
      
SELECT 
    c.customer_code,
    c.customer,
    ROUND(AVG(d.pre_invoice_discount_pct) * 100, 2) AS avg_discount_percentage
FROM
    dim_customer AS c
        JOIN
    fact_pre_invoice_deductions AS d ON c.customer_code = d.customer_code
WHERE
    d.fiscal_year = 2021
        AND c.market = 'India'
GROUP BY c.customer_code , c.customer
ORDER BY avg_discount_percentage DESC
LIMIT 5;

/* 7. get the complete report of the gross sales amount for the customer "Atliq Exclusive" for each month. 
   This analysis helps to get an idea of low and high performing months and take strategic decision. 
   The finel output contains: Month, year, gross_sales_month. */
   
with cte as
(select  monthname(s.date) as month_name,
         s.fiscal_year,
		 s.customer_code,
         s.sold_quantity,
         g.gross_price
from fact_gross_price as g 
join fact_sales_monthly as s    
on s.product_code = g.product_code
and s.fiscal_year = g.fiscal_year
join dim_customer as c
on c.customer_code = s.customer_code
where c.customer = "Atliq Exclusive")

select month_name, 
	   fiscal_year, 
       round(sum(sold_quantity * gross_price)) as Gross_sales_amount
from cte
group by month_name, fiscal_year
order by fiscal_year;

/* 8. In which quarter of 2020, got the maximum told_sold_quntity?
       The final output contain these field sorted by the total_sold_quantity. */
       
 with cte as (select  month(date) as month_name,
                      sum(sold_quantity) as sold_qty
              from fact_sales_monthly
              where fiscal_year = 2020
              group by date 
              order by month_name )
 select 
     case 
         when month_name in (9,10,11) then "Q1"
         when month_name in (12,1,2)  then "Q2" 
         when month_name in (3,4,5)  then "Q3"
         when month_name in (6,7,8)  then "Q4"
         end as quarter,
     sum(sold_qty) as total_sold_qty
 from cte
 group by quarter 
 order by total_sold_qty desc;
 
 /* 9. Which channel helped to bring more gross sales in the fiscal yeal 2021 and the percentage of contribution?
    The finel output contains: Channel, gross_sales_min_percentage. */
    
With cte as (Select d.channel, round(sum(m.sold_quantity * f.gross_price)/ 1000000,2) as gross_sales_mln  
             from fact_sales_monthly as m
             join fact_gross_price as f
             on m.product_code = f.product_code
             join dim_customer as d
             on d.customer_code = m.customer_code
             where m.fiscal_year = 2021
             group by d.channel
             order by gross_sales_mln desc)
             
select *, round(gross_sales_mln * 100 / sum(gross_sales_mln)over(),2 ) as percentage
from cte
order by percentage desc;

/* 10. Get the top 3 products in each division that have a high total_sold_quantity in the fiscal_year_2021?
   The final output contains these field: Division, Product_code, Product, Total_sold_qty, rank_order. */
   
With cte as (Select p.division, p.product_code, p.product,
                    sum(s.sold_quantity) as total_sold_qty
             from dim_product as p
             join fact_sales_monthly as s
             on p.product_code = s.product_code
             where s.fiscal_year = 2021
             group by p.division, p.product_code, p.product
             order by total_sold_qty desc),
             
	cte2 as (select *, dense_rank() over(partition by division order by total_sold_qty desc) as rank_order
             from cte)
select * from cte2
where rank_order <= 3;             
             
             
             
             
             
              
       
       
         
   


  
  
  
  
  
  
  
  
  
  
  








