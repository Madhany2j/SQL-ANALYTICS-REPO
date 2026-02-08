# SALES PERFORMANCE ANALYSIS
                                                      
**OVERVIEW:**
  This This project analyzes sales performance data using SQL to uncover trends, patterns, and business insights.
  The goal is to demonstrate practical SQL skills such as data cleaning, joins, aggregations, and analytical queries.

**Business Questions**
- How are sales trending over time?
- Which products generate the most revenue?
- Who are the top customers?
- Which regions perform best?

**Dataset**
- Orders
- Customers
- Products

**Skills Demonstrated**
- SQL Joins
- Aggregations
- Group By
- Window Functions
- Date Functions
- Subqueries / CTEs

**TABLE SCHEMA**
**SALES TABLE - gold.fact_sales**
- order_number (nvarchar)
- product_key (int)
- customer_key (int)
- order_date (date)
- shipping_date (date)
- due_date (date)
- sales_amount (int)
- quantity (tinyint)
- price (int)

**PRODUCT TABLE - gold.dim_products**
- product_key (int)
- product_id (int)
- product_number (nvarchar)
- category (nvarchar)
- subcategory (nvarchar)
- maintenance (nvarchar)
- product_line (nvarchar)
- cost (int)
- start_date (date)

**CUSTOMER TABLE - gold.dim_customers**
- customer_key (int)
- customer_id (int)
- customer_number (nvarchar)
- first_name (nvarchar)
- last_name (nvarchar)
- country (nvarchar)
- marital_status (nvarchar)
- gender (nvarchar)
- birthdate (date)
- create_date (date)
