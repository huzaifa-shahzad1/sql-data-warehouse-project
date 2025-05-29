/*
===============================================================================
DDL Script: Create Gold Views 
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse. 
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer 
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
CREATE VIEW gold.dim_customers AS 
(
	SELECT 
		ROW_NUMBER() OVER(ORDER BY ci.cst_id) AS customer_key,
		ci.cst_id AS customer_id,
		ci.cst_key AS customer_number,
		ci.cst_firstname AS first_name,
		ci.cst_lastname AS last_name,
		el.cntry AS country,
		ci.cst_marital_status AS marital_status,
		-- Considering the Master Source for gender is CRM 
		CASE
			WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
			ELSE COALESCE(ca.gen, 'n/a')
		END AS gender,
		ca.bdate AS birth_date,
		ci.cst_create_date AS create_date
	FROM silver.crm_cust_info AS ci
	LEFT JOIN silver.erp_cust_az12 AS ca
		ON ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 AS el
		ON ci.cst_key = el.cid
)
;

-- =============================================================================
-- Create Dimension: gold.dim_products
-- =============================================================================
CREATE VIEW gold.dim_products AS
(
	SELECT 
		ROW_NUMBER() OVER(ORDER BY pi.prd_start_dt, pi.prd_key) AS product_key,
		pi.prd_id AS product_id,
		pi.prd_key AS product_number,
		pi.prd_nm AS product_name,
		pi.cat_id AS category_id,
		pc.cat AS category,
		pc.subcat AS subcategory,
		pc.maintenance,
		pi.prd_cost AS cost,
		pi.prd_line AS product_line,
		pi.prd_start_dt AS start_date
	FROM silver.crm_prd_info AS pi
	LEFT JOIN silver.erp_px_cat_g1v2 AS pc
		ON pi.cat_id = pc.id
	WHERE prd_end_dt IS NULL -- FILTER OUT historical data and get only active products
)
;

-- =============================================================================
-- Create Fact Table: gold.fact_sales
-- =============================================================================
CREATE VIEW gold.fact_sales AS
(
	SELECT
		cs.sls_ord_num AS order_number,
		pr.product_key,
		cu.customer_key,
		cs.sls_order_dt AS order_date,
		cs.sls_ship_dt AS shipping_date,
		cs.sls_due_dt AS due_date,
		cs.sls_sales AS sales_amount,
		cs.sls_quantity AS quantity,
		cs.sls_price AS price
	FROM silver.crm_sales_details AS cs
	LEFT JOIN gold.dim_products AS pr
		ON cs.sls_prd_key = pr.product_number
	LEFT JOIN gold.dim_customers AS cu
		ON cs.sls_cust_id = cu.customer_id
)
;
