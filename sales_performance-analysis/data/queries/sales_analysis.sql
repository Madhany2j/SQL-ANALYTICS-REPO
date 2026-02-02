-- 1. Change overtime Analysis--
select 
    datetrunc(month, order_date) as order_month,
    sum(sales_amount) as total_sales,
    count(distinct customer_key) as total_customers,
    sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by datetrunc(month, order_date)
order by datetrunc(month, order_date);


-- 2. Cummulative analysis (Calculate Total sales per month and running total overtime) --
select 
    order_month, 
    total_sales,
    sum(total_sales) over (
        order by order_month
    ) as running_total,
    avg(average_price) over (
        order by order_month
    ) as moving_average_price
from (
    select 
        datetrunc(month, order_date) as order_month,
        sum(sales_amount) as total_sales,
        avg(price) as average_price
    from gold.fact_sales
    where order_date is not null
    group by datetrunc(month, order_date)
) t;


/* 3. Performance analysis (analyse the yearly performance of products 
by comparing their sales to both the average sales performance of the product and the previous year's sales)*/
with yearly_product_sales as (
	select 
		year(f.order_date) as order_year,
		p.product_name,
		sum(f.sales_amount) as current_sales
		from gold.fact_sales f left join
		gold.dim_products p
		on f.product_key = p.product_key
		where f.order_date is not null
		group by year(f.order_date),
		p.product_name)

select order_year,
		product_name,
		current_sales,
		avg(current_sales) over(partition by product_name) as avg_sales,
		current_sales-avg(current_sales) over(partition by product_name) as diff_avg,
		case when current_sales-avg(current_sales) over(partition by product_name)<0 then 'below avg'
			 when current_sales-avg(current_sales) over(partition by product_name)>0 then 'above avg'
			 else 'avg' 
		end as avg_change,
		lag(current_sales) over(partition by product_name order by order_year) as py_sales,
		case when current_sales-lag(current_sales) over(partition by product_name order by order_year)<0 then 'decreasing'
			 when current_sales-lag(current_sales) over(partition by product_name order by order_year)>0 then 'increasing'
			 else 'no change' 
		end as current_status
from yearly_product_sales
order by product_name,order_year

-- 4. Proportional Anaslysis (Categories contributing to overall sales) --
with category_total_sales 
as (
	select dp.category, sum(fs.sales_amount) as category_sales 
	from gold.fact_sales fs left join 
	gold.dim_products dp on
	fs.product_key=dp.product_key 
	group by dp.category)

select 
	category, 
	category_sales,
	sum(category_sales) over() total_sales,
	concat(Round((cast(category_sales as float)/sum(category_sales) over())*100,2),'%') as Contribution
from category_total_sales
order by category_sales desc

-- 5. Segment Products into cost range and count how many products fall into that segment --
with cost_segment as (
    select 
        product_key,
        product_name,
        cost,
        case 
            when cost < 100 then 'Below 100'
            when cost between 100 and 500 then '100-500'
            when cost between 500 and 1000 then '500-1000'
            else 'Above 1000'
        end as cost_range
    from gold.dim_products
)

select 
    cost_range,
    count(*) as no_of_products
from cost_segment
group by cost_range
order by no_of_products desc;

/* 6. Group customers into three segments based on their spending behavior:
	i: VIP- Customers with atleast 12 months of history and spending more than 5000
	ii: Regular- Customers with atleast 12 months of history and spending 5000 or less
	iii: New- Customers with a lifespan less than 12 months.
And find total number of customers in each group */

with customer_ltv as (
    select 
        dc.customer_key as customers,
        sum(fs.sales_amount) as total_spending,
        min(fs.order_date) as first_order,
        max(fs.order_date) as last_order,
        datediff(
            month,
            min(fs.order_date),
            max(fs.order_date)
        ) as lifespan
    from gold.fact_sales fs
    left join gold.dim_customers dc 
        on fs.customer_key = dc.customer_key
    group by dc.customer_key
)

select 
    customer_segment,
    count(customers) as total_customers
from (
    select 
        customers,
        case 
            when lifespan >= 12 and total_spending > 5000 then 'VIP'
            when lifespan >= 12 and total_spending <= 5000 then 'Regular'
            else 'New'
        end as customer_segment
    from customer_ltv
) t
group by customer_segment
order by total_customers desc;

-- 7. a. Find total customers by countires --
		select country,count(distinct customer_id) total_customers
		from gold.dim_customers
		group by country
		order by count(distinct customer_id)  desc
  --  b. Find total customers by gender --
		select gender,count(distinct customer_id) total_customers
		from gold.dim_customers
		group by gender
  -- c. find total products by category --
		select category, count(distinct product_id) as total_products
		from gold.dim_products
		group by category
		order by count(distinct product_id) desc
  -- d. Average cost in each category --
		select  category, avg(cost) as average_cost
		from gold.dim_products
		group by category
		order by average_cost desc
  -- e. Total revenue genrated for each category --
		select dp.category,sum(fs.sales_amount) as rev_generated 
		from gold.dim_products dp left join
		gold.fact_sales fs on dp.product_key=fs.product_key
		where dp.category is not null
		group by dp.category
		order by rev_generated desc
   -- f. Total revenue generated by each customer --
		select customer_key, sum(sales_amount) as total_sales 
		from gold.fact_sales 
		group by customer_key
		order by total_sales desc
   -- g. distribution of sold items (quantity wise) across country --
		select dc.country country,dp.product_name product_name,
		sum(fs.quantity) total_quantity 
		from gold.dim_customers dc left join
		gold.fact_sales fs on dc.customer_key=fs.customer_key
		left join gold.dim_products dp on fs.product_key=dp.product_key
		where dc.country is not null
		group by dc.country ,dp.product_name 
		order by total_quantity desc
   -- h. Which 5 products generated the highest revenue --
		select top 5 product_key,product_name,
		DENSE_RANK() over( order by total_sales desc) from
		(select dp.product_key product_key,dp.product_name product_name,
		sum(fs.sales_amount) total_sales
		from gold.dim_products dp join 
		gold.fact_sales fs on dp.product_key = fs.product_key
		group by dp.product_key,dp.product_name) t
  -- i. Find the top 10 customers who have generated the highest revenue --
		select top 10 customer_key,full_name, total_Sales,
		dense_rank() over(order by total_sales desc) as customer_rank
		from (
		select dc.customer_key customer_key,concat(dc.first_name,' ',dc.last_name) as full_name,
		sum(fs.sales_amount) as total_sales 
		from gold.dim_customers dc left join gold.fact_sales fs 
		on dc.customer_key=fs.customer_key
		group by dc.customer_key,concat(dc.first_name,' ',dc.last_name) ) t
  -- j. Top 5 customers with fewest placed orders
		select top 5 customer_key,full_name, total_quantity,
		ROW_NUMBER() over(order by total_quantity asc) as customer_rank
		from (
		select dc.customer_key customer_key,concat(dc.first_name,' ',dc.last_name) as full_name,
		sum(fs.quantity) as total_quantity 
		from gold.dim_customers dc left join gold.fact_sales fs 
		on dc.customer_key=fs.customer_key
		group by dc.customer_key,concat(dc.first_name,' ',dc.last_name) ) t


/*  Customer Report

Purpose: - This report consolidates key customer metrics and behaviors

Highlights:

1. Gathers essential fields such as names, ages, and transaction details. 
2. Segments customers into categories (VIP, Regular, New) and age groups.

3. Aggregates customer-level metrics:

		- total orders
		- total sales
		- total quantity purchased
		- total products
		-lifespan (in months)

	4. Calculates valuable KPIs:

		- recency (months since last order)
		- average order value
		- average monthly spend
*/
drop view gold.master_customer_query
go

create view gold.master_customer_details as

With base_query as (
    Select
        fs.order_number orders,
        fs.product_key products,
        fs.order_date order_date,
        fs.sales_amount sales,
        fs.quantity quantity,
        dc.customer_key customer_key,
        CONCAT(dc.first_name, ' ', dc.last_name) customer_name,
        DATEDIFF(YEAR, dc.birthdate, GETDATE()) age
    From gold.fact_sales fs
    left join gold.dim_customers dc 
        on fs.customer_key = dc.customer_key
    Where fs.order_date IS NOT NULL
),

customer_aggregation as (
    select
        customer_key,
        customer_name,
        age,
        count(DISTINCT orders)  total_orders,
        sum(quantity)  total_quantity,
        sum(sales) total_sales,
        count(DISTINCT products)  total_products,
        datediff(month, min(order_date), max(order_date)) lifespan,
        max(order_date) as last_order_date
    from base_query
    group by
        customer_key,
        customer_name,
        age
)

select
    customer_key,customer_name,age,
    total_orders,total_quantity,total_sales,total_products,lifespan,
    case 
        when age < 20 then 'under 20'
        when age between 20 and 29 then '20-29'
        when age between 30 and 39 then '30-39'
        when age between 40 and 49 then '40-49'
        else '50 and above'
    end  age_group,
    case 
		when lifespan >= 12 and total_sales > 5000 then 'VIP'
        when lifespan >= 12 and total_sales <= 5000 then 'Regular'
        else 'New'
    end as customer_segment,
    datediff(month, last_order_date, getdate()) AS order_recency,
    -- Average Order Value --
    case 
        when total_orders = 0 then 0
        else total_sales / total_orders
    end as avg_order_value,
    -- Average Monthly Spend --
    case 
        when lifespan = 0 then total_sales
        else total_sales / lifespan
    end as avg_monthly_spend

From customer_aggregation;


/*  Product report:

Purpose:
This report consolidates key product metrics and behaviors.
Highlights:
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify Hi h-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
	- total orders
	- total sales
	- total quantity sold
	- total customers (unique)
	- lifespan (in months)
Calculates valuable KPIs:
	- Build Product Report - recency (months since last sale)
	- average order revenue (AOR)
	- average monthly revenue */
create view gold.master_product_details as

with base_query as (
select  fs.order_number orders,
        fs.sales_amount sales,
        fs.quantity quantity,
		fs.order_date order_date,
		fs.customer_key customers,
		dp.product_name products, 
	    dp.category category,		
	    dp.subcategory sub_category,		
	    dp.cost cost, 
		dp.start_date start_date
from gold.fact_sales fs 
left join gold.dim_products dp 
on fs.product_key=dp.product_key),

product_aggregation as (
select products,category,sub_category, cost,     
	   max(order_date) as max_date,
	   count(distinct orders) total_orders,
	   sum(sales) as total_sales,
	   sum(quantity) total_quantity,
	   count(distinct customers) total_customers,
	   datediff(month,min(order_date),max(order_date)) lifespan,
	   (sum(sales)/sum(quantity)) avg_selling_price
from base_query
group by products,category,sub_category,cost,start_date)

select products,category,sub_category, cost
	   total_orders,
	   total_sales,
	   total_quantity,
	   total_customers,
	   lifespan,
	   avg_selling_price,
	   case when total_sales>25000 then 'Hi-range'
			when total_sales between 10000 and 25000 then 'Mid-range'
			else 'Low-range'
	   end as Product_performance,
	   datediff(month,max_date,getdate()) recency,
	   case when total_orders=0 then 0
	   else (total_sales/total_orders) 
	   end as AOV,
	   case when lifespan=0 then total_sales
	   else (total_sales/lifespan) 
	   end as avg_monthly_revenue
from product_aggregation
