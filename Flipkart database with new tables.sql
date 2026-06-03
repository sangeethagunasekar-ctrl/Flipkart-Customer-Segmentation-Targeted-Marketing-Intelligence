-- =====================================
-- 1. CITY TIER MAPPING
-- =====================================

create table city_tier_mapping(
city varchar(50) primary key,
state varchar(50),
tier varchar(20),
region varchar(20)
);

-- =====================================
-- 2. CUSTOMERS
-- =====================================

create table customers(
customer_id varchar(15) primary key,
full_name varchar(100),
email varchar(100),
gender varchar(10),
age int,
city varchar(50),
state varchar(50),
tier varchar(20),
region varchar(20),
signup_date date,
preferred_language varchar(20)
);

alter table customers
add foreign key (city)
references city_tier_mapping(city);

-- =====================================
-- 3. PRODUCTS 
-- =====================================

create table products(
product_id varchar(15) primary key,
brand varchar(50),
category varchar(50),
subcategory varchar(50),
price_mrp numeric(10,2),
price_segment varchar(20),
avg_rating numeric(2,1),
in_stock boolean,
flipkart_assured boolean
);

-- =====================================
-- 4. ORDERS -- Order level info
-- =====================================

create table orders(
order_id varchar(15) primary key,
customer_id varchar(15),
order_date date,
order_status varchar(20),
payment_method varchar(20),
delivery_days smallint,
discount_code varchar(20),
is_festive_order boolean
);

alter table orders
add foreign key (customer_id)
references customers(customer_id);

select * from orders;

-- =====================================
-- 5. ORDER ITEMS --Product level sales detail
-- =====================================

create table order_items(
item_id varchar(15) primary key,
order_id varchar(15),
product_id varchar(15),
quantity smallint,
unit_price numeric(10,2),
discount_percent int,
discount_amount numeric(10,2),
final_price numeric(10,2)
);

alter table order_items
add foreign key (order_id)
references orders(order_id);

alter table order_items
add foreign key (product_id)
references products(product_id);

select * from order_items;

-- =====================================
-- 6. CUSTOMER PREFERENCES
-- =====================================

create table customer_preferences(
preference_id serial primary key, --created the column for unique identification of rows
customer_id varchar(15),
preferred_categories text,
wishlist_product_ids text,
saved_searches text,
price_range_min numeric,
price_range_max numeric,
notification_opt_in boolean,
flipkart_plus_member boolean,
preferred_brands text,
avg_session_duration_min numeric,
last_app_open date
);

alter table customer_preferences
add foreign key (customer_id)
references customers(customer_id);

-- =====================================
-- 7. CAMPAIGN RESPONSES
-- =====================================

create table campaign_responses(
customer_id varchar(15),
campaign_id varchar(15),
campaign_name varchar(100),
campaign_type varchar(50),
sent_date date,
opened boolean,
clicked boolean,
converted boolean,
response_date date,
revenue_generated numeric,
primary key (customer_id, campaign_id)
);

alter table campaign_responses
add foreign key (customer_id)
references customers(customer_id);

select * fr

-- =====================================
-- 8. BROWSING EVENTS
-- =====================================

create table browsing_events(
customer_id varchar(15),
session_id varchar(50),
session_date date,
device varchar(20),
city varchar(50),
total_events int,
event_seq int,
page_type varchar(50),
product_id varchar(15),
category_viewed varchar(50),
time_spent_sec int,
event_timestamp timestamp,
added_to_cart boolean,
added_to_wishlist boolean,
primary key (customer_id, session_id, event_seq)
);

alter table browsing_events
add foreign key (customer_id)
references customers(customer_id);

alter table browsing_events
add foreign key (product_id)
references products(product_id);

-- =====================================
-- 9. FACT TABLE - by joining orders,order_items & customers table
-- =====================================

create table fact_order_items as
select oi.item_id, 
oi.order_id,
oi.product_id,
o.customer_id,
o.order_date,
oi.quantity,
oi.unit_price,
oi.discount_percent,
oi.discount_amount,
oi.final_price,
o.is_festive_order,
c.region,
c.tier,
o.payment_method
from order_items oi
join orders o on oi.order_id = o.order_id
join customers c on o.customer_id = c.customer_id;

alter table fact_order_items
add constraint pk_fact_order_items primary key (item_id);

alter table fact_order_items
add constraint fk_fact_customer
foreign key (customer_id)
references customers(customer_id);

-- =====================================
-- 10. RFM score
-- =====================================

create table rfm_scores as
select customer_id,
max(order_date) as last_order_date,
count(distinct order_id) as frequency,
sum(final_price) as monetary
from fact_order_items
group by customer_id;

alter table rfm_scores
add constraint pk_rfm_scores primary key (customer_id);

alter table rfm_scores
add constraint fk_rfm_customer
foreign key (customer_id)
references customers(customer_id);
-- =====================================
-- 11. ADD RECENCY COLUMN
-- =====================================

alter table rfm_scores
add column recency_days int;

-- =====================================
-- 12. UPDATE RECENCY DAYS
-- =====================================

update rfm_scores
set recency_days = date '2024-12-31' - last_order_date;

-- =====================================
-- 13. ADD RFM SCORE COLUMNS
-- =====================================

alter table rfm_scores
add column r_score int,
add column f_score int,
add column m_score int,
add column rfm_combined_score varchar(10),
add column segment varchar(50);

-- =====================================
-- 14. RFM SCORING
-- =====================================

-- Recency Score
update rfm_scores
set r_score = sub.r_score
from (
select customer_id,
6 - ntile(5) over (order by recency_days asc) as r_score
from rfm_scores
) sub
where rfm_scores.customer_id = sub.customer_id;

-- Frequency Score
update rfm_scores
set f_score = sub.f_score
from (
select customer_id,
ntile(5) over (order by frequency desc) as f_score
from rfm_scores
) sub
where rfm_scores.customer_id = sub.customer_id;

-- Monetary Score
update rfm_scores
set m_score = sub.m_score
from (
select customer_id,
ntile(5) over (order by monetary desc) as m_score
from rfm_scores
) sub
where rfm_scores.customer_id = sub.customer_id;

-- =====================================
-- 15. COMBINED SCORE
-- =====================================

update rfm_scores
set rfm_combined_score = r_score::text || f_score::text || m_score::text;

-- =====================================
-- 16. SEGMENTATION
-- =====================================

update rfm_scores
set segment = case

-- Champions
when r_score in (4,5) and f_score in (4,5) and m_score in (4,5)
then 'Champions'

-- Loyal Customers
when r_score between 3 and 5 and f_score between 3 and 5 and m_score between 3 and 5
and not (r_score in (4,5) and f_score in (4,5) and m_score in (4,5))
then 'Loyal Customers'

-- Potential Loyalists
when r_score between 3 and 5 and f_score between 1 and 3 and m_score between 1 and 3
then 'Potential Loyalists'

-- New Customers
when r_score in (4,5) and f_score = 1
then 'New Customers'

-- Promising
when r_score between 3 and 4 and f_score between 1 and 2 and m_score between 1 and 2
then 'Promising'

-- Need Attention
when r_score between 2 and 3 and f_score between 2 and 3 and m_score between 2 and 3
then 'Need Attention'

-- About to Sleep
when r_score between 2 and 3 and f_score between 1 and 2 and m_score between 1 and 2
then 'About to Sleep'

-- Cannot Lose Them
when r_score = 1 and f_score in (4,5) and m_score in (4,5)
then 'Cannot Lose Them'

-- At Risk
when r_score between 1 and 2 and f_score between 2 and 5 and m_score between 2 and 5
then 'At Risk'

-- Lost Customers
when r_score = 1 and f_score between 1 and 2 and m_score between 1 and 2
then 'Lost Customers'

else 'Others'

end;

-----------------------------------
select * from customers;
select*from products;
select * from fact_order_items;
select * from rfm_scores;
select count(*) from rfm_scores;
select * from browsing_events;

update products
set category = initcap(lower(category));

--------------------------------------------
--Analysis queries
--------------------------------------------

-------------------------------------
--Phase 3: Behavioural enrichment
-------------------------------------

select * from browsing_events; 
select * from rfm_scores;

-- 1.Average session time per segment
select r.segment,
round(avg(b.time_spent_sec),2) as average_time_spent
from browsing_events b
join rfm_scores r
on b.customer_id = r.customer_id
group by r.segment
order by average_time_spent desc;

-- 2. Most used device
select device,
count(distinct customer_id) as customers_count
from browsing_events
group by device
order by customers_count desc; --without segmentation

select r.segment,
b.device,
count(*) as usage_count
from browsing_events b
join rfm_scores r
on b.customer_id = r.customer_id
group by r.segment, b.device
order by r.segment, usage_count desc;--with segmentation

--3. Browse to Cart+wish list rate in browsing_events
select r.segment,
round(sum(case when b.added_to_cart = true then 1 else 0 end) *1.0/ count(*),2) as cart_rate,
round(sum(case when b.added_to_wishlist = true then 1 else 0 end) *1.0/ count(*),3) as wishlist_rate
from browsing_events b
join rfm_scores r
on b.customer_id = r.customer_id
group by r.segment;

-- 4.Top categories
select segment, category_viewed, total_views
from (
select r.segment,
b.category_viewed,
count(*) as total_views,
row_number() over (partition by r.segment order by count(*) desc) as rank -- row_number for numbering rows, partition to group & apply it on segments,desc used for top 3 results
from browsing_events b
join rfm_scores r
on b.customer_id = r.customer_id
group by r.segment, b.category_viewed
) sub
where rank <= 3;--Only 3 results

-- 5.Wishlist size
select * from customer_preferences;
select * from rfm_scores;

select  r.segment, AVG(w.wishlist_size) as avg_wishlist_size
from (
select customer_id, count(distinct wishlist_product_ids) as wishlist_size
from customer_preferences
where wishlist_product_ids is NOT NULL --is to exclude rows where the customer has no wishlist product saved.
group by customer_id
) w
join rfm_scores r
on w.customer_id = r.customer_id
group by r.segment
order by avg_wishlist_size desc;

--6. Purchase gap-- in total 4 tables referred(browsing_events, rfm_score, fact_order_items,products)
select r.segment,
b.category_viewed as browsed_category,
p.category as purchased_category,
count(*) as total
from browsing_events b
join fact_order_items f--fact_order_
on b.customer_id = f.customer_id
join products p
on f.product_id = p.product_id
join rfm_scores r
on b.customer_id = r.customer_id
group by r.segment, b.category_viewed, p.category
order by total desc;

---------------------------------------------
-- Phase 4 : Financial and Marketing Analysis 
---------------------------------------------
-- 1. Customerlifetime value
select segment,
round(avg(monetary*1.0/frequency),2) as avg_order_value,
round(avg(frequency),2) as purchase_frequency,
2 as retention_years,
round(avg(monetary*1.0/frequency) * avg(frequency) * 2,2) as clv,
round((avg(monetary*1.0/frequency) * avg(frequency) * 2) * 0.20,2) as max_acquisition_cost
from rfm_scores
group by segment
order by clv desc;

--2. Revenue contribution%
select segment,
sum(monetary) as total_revenue,
round(100.0 * sum(monetary) / sum(sum(monetary)) over (),2) as revenue_percent
from rfm_scores
group by segment
order by total_revenue desc;

--3. Average revenue per customer
select segment,
round(avg(monetary),2) as avg_revenue_per_customer
from rfm_scores
group by segment
order by avg_revenue_per_customer desc;

--4. Festive vs Non-festive
--4a.  Average order value
select 
    r.segment,
    f.is_festive_order,
    round(avg(order_total), 2) as avg_order_value
from (
    select 
        order_id,
        customer_id,
        is_festive_order,
        sum(final_price) as order_total
    from fact_order_items
    group by order_id, customer_id, is_festive_order
) f
join rfm_scores r
on f.customer_id = r.customer_id
group by r.segment, f.is_festive_order
order by r.segment, f.is_festive_order;

--4b. Category mix
select r.segment,
f.is_festive_order,
p.category,
count(*) as total_orders
from fact_order_items f
join products p on f.product_id = p.product_id
join rfm_scores r on f.customer_id = r.customer_id
group by r.segment, f.is_festive_order, p.category
order by r.segment, p.category;

--4c. Discount usage
select r.segment,
f.is_festive_order,
count(*) filter (where f.discount_percent > 0) as discount_orders,
count(*) as total_orders,
round(count(*) filter(where f.discount_percent > 0) * 100.0 / count(*),2) as discount_usage_percentage
from fact_order_items f
join rfm_scores r
on f.customer_id = r.customer_id
group by r.segment, f.is_festive_order;

--Discount_depth
select 
    r.segment,
    case 
        when f.discount_percent = 0 then '0%'
        when f.discount_percent between 1 and 10 then '1-10%'
        when f.discount_percent between 11 and 20 then '11-20%'
        when f.discount_percent between 21 and 30 then '21-30%'
        when f.discount_percent between 31 and 40 then '31-40%'
        else '40%+'
    end as discount_bucket,
    count(*) as total_orders,
    round(100.0 * count(*) / sum(count(*)) over (partition by r.segment), 2) as percent_within_segment
from fact_order_items f
join rfm_scores r
on f.customer_id = r.customer_id
group by r.segment, discount_bucket
order by r.segment, percent_within_segment desc;

--5. Value vs volume
--5a high value segments (same as 3.Average revenue per customer)
select segment,
round(avg(monetary),2) as revenue_per_customer
from rfm_scores
group by segment
order by revenue_per_customer desc
limit 5;

--5b high volume segments
select segment,
count(*) as total_customers
from rfm_scores
group by segment
order by total_customers desc;

----------------------------------------
--Phase 5 Advertisement & Offer strategy
---------------------------------------

select r.segment,
c.campaign_type,
round(avg(case when c.opened = true then 1 else 0 end)::numeric,2) as open_rate,
round(avg(case when c.clicked = true then 1 else 0 end)::numeric,2) as click_rate,
round(avg(case when c.converted = true then 1 else 0 end)::numeric,2) as conversion_rate
from campaign_responses c
join rfm_scores r
on c.customer_id = r.customer_id
group by r.segment, c.campaign_type
order by r.segment;

------------------------------------------------
-- Other Analysis queries - not asked in project
-----------------------------------------------

--1. RFM segment distribution

select segment, count(*) as total_customers
from rfm_scores
group by segment
order by total_customers desc;

--2. Revenue by segment
select r.segment, sum(f.final_price) as total_revenue 
from fact_order_items f
join rfm_scores r
on f.customer_id = r.customer_id
group by segment
order by total_revenue desc;

--3. Average order value by segment
select r.segment, avg(f.final_price) as average_order_value
from fact_order_items f
join rfm_scores r
on f.customer_id = r.customer_id
group by segment
order by average_order_value desc;

--4. Top 10 high value customers
select customer_id, monetary from rfm_scores
order by monetary desc
limit 10;

--5. customer count by region
select region, count(distinct customer_id) as customers_count from fact_order_items
group by region 
order by customers_count desc;

--6. Revenue by category
select p.category, sum(f.final_price) as total_revenue
from fact_order_items f
join products p 
on f.product_id = p.product_id
group by p.category
order by total_revenue desc;

--7.Festive vs Non festive orders (from fact_order_items table)
select
case
when is_festive_order = true then 'festive'
else 'non_festive'
end 
as order_type, sum(final_price) as total_revenue from fact_order_items
group by order_type;

-------------
select * from fact_order_items;

--Payment method analysis
select payment_method,
count(*) as total_orders 
from fact_order_items
group by payment_method
order by total_orders desc;


--Purchase gap mismatch % 
select
    r.segment,
    count(*) as total_links,
    sum(case when b.category_viewed = p.category then 1 else 0 end) as same_category_count,
    sum(case when b.category_viewed <> p.category then 1 else 0 end) as different_category_count,
    round(
        100.0 * sum(case when b.category_viewed <> p.category then 1 else 0 end) / count(*),
        2
    ) as mismatch_percent
from browsing_events b
join fact_order_items f
    on b.customer_id = f.customer_id
join products p
    on f.product_id = p.product_id
join rfm_scores r
    on b.customer_id = r.customer_id
where b.category_viewed is not null
group by r.segment
order by mismatch_percent desc;


select segment,
count(*) as total 
from rfm_scores
where segment= 'promising'
group by segment; 


