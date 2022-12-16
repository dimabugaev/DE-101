-- lab 2 full script filling stg -> dwh all entity
create schema if not exists dwh;

-- clean all

drop table if exists dwh.order_detales_fact;
drop table if exists dwh.location_dim;
drop table if exists dwh.date_dim;
drop procedure if exists dwh.populate_dim_date;
drop table if exists dwh.customer_dim;
drop table if exists dwh.product_dim;
drop table if exists dwh.people_dim;
drop table if exists dwh.shiping_dim;


-- date_dim

CREATE TABLE dwh.date_dim
(
 "date"      date NOT NULL,
 year      int NOT NULL,
 month     int NOT NULL,
 month_day int NOT NULL,
 quarter   int NOT NULL,
 week      int NOT NULL,
 week_day  int NOT NULL,
 CONSTRAINT PK_1 PRIMARY KEY ( "date" )
);

CREATE or replace PROCEDURE dwh.populate_dim_date(start_date date, end_date date)
LANGUAGE plpgsql
AS $$
declare 
	date_counter date := start_date; 
	param_year int;
	param_mount int;
	param_mount_day int;
	param_quarter int;
	param_week int;
	param_week_day int;
begin
	IF start_date IS NULL OR end_date IS null then
	    RAISE notice 'Start and end dates MUST be provided in order for this stored procedure to work.';
		return;
	end if; 

	IF start_date > end_date then
		RAISE notice 'Start date must be less than or equal to the end date.';
		RETURN;
	end if;

	delete from dwh.date_dim 
	where "date" between start_date and end_date;


	--RAISE notice ' year (%), month (%), day (%), quarter (%), week (%), day of week (%)', 
	--param_year, param_mount, param_mount_day, param_quarter, param_week, param_week_day;

	while date_counter <= end_date loop
		param_year := extract(year from date_counter);
		param_mount := extract(month from date_counter);
		param_mount_day := extract(day from date_counter);
		param_quarter := extract(quarter from date_counter);
		param_week := extract(week from date_counter);
		param_week_day := extract(dow from date_counter);

		insert into dwh.date_dim (date, year, "month", month_day, quarter, week, week_day) 
		values(date_counter, param_year, param_mount, param_mount_day, param_quarter, param_week, param_week_day);
		
		date_counter := date_counter + 1;	
	end loop;
	
END;
$$;

DO $$
DECLARE 
	startdate date;
	enddate date;
begin
	startdate := (select 
					case 
						when min(o.order_date) < min(o.ship_date) then
							min(o.order_date)
						else
							min(o.ship_date)
					end min_date
				  from stg.orders o);
				 
	enddate := (select 
					case 
						when max(o.order_date) > max(o.ship_date) then
							max(o.order_date)
						else
							max(o.ship_date)
					end min_date
				from stg.orders o);

	RAISE notice ' startdate (%) enddate (%) ',startdate, enddate;
	
  	CALL dwh.populate_dim_date(startdate, enddate);

END;
$$;

-- customer_dim

CREATE TABLE dwh.customer_dim
(
	 customer_key  int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 customer_id   varchar(15) NOT NULL,
	 customer_name varchar(50) NOT NULL,
	 segment       varchar(50) NOT NULL
);

insert into dwh.customer_dim (customer_id, customer_name, segment)
select distinct
	o.customer_id customer_id,
	o.customer_name customer_name,
	o.segment segment 
from stg.orders o;

-- product_dim

CREATE TABLE dwh.product_dim
(
	 product_key  int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 product_id   varchar(15) NOT NULL,
	 category     varchar NOT NULL,
	 sub_category varchar NOT NULL,
	 product_name varchar NOT NULL
);

insert into dwh.product_dim (product_id, category, sub_category, product_name)
select distinct
	o.product_id  product_id,
	o.category  category,
	o.subcategory subcategory,
	o.product_name product_name
from stg.orders o;

-- people_dim

CREATE TABLE dwh.people_dim
(
	 people_key  int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 sales_name   varchar NOT NULL
);

insert into dwh.people_dim (sales_name)
select distinct
	p.person 
from stg.people p;


-- shiping_dim

CREATE TABLE dwh.shiping_dim
(
	 shipping_key  int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 ship_mode   varchar NOT NULL
);

insert into dwh.shiping_dim (ship_mode)
select distinct
	o.ship_mode  
from stg.orders o;


-- location_dim

CREATE TABLE dwh.location_dim
(
	 location_key  int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 country   varchar(15) NOT NULL,
	 city     varchar NOT NULL,
	 state varchar NOT NULL,
	 postal_code varchar,
	 region varchar NOT NULL
);

insert into dwh.location_dim (country, city, state, postal_code, region)
select distinct
	o.country country,
	o.city city,
	o.state state,
	o.postal_code postal_code,
	o.region region
from stg.orders o;

UPDATE dwh.location_dim
SET postal_code='05401'
WHERE city='Burlington' and country='United States' 
	and state='Vermont' and postal_code is null;

-- orders_detales_fact

CREATE TABLE dwh.order_detales_fact
(
	 row_key        int GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
	 row_id			int not null, 
	 order_id       varchar(15) NOT NULL,
	 ship_date_key  date NOT NULL,
	 customer_key   int NOT NULL,	
	 order_date_key date NOT NULL,
	 product_key    int NOT NULL,
	 shipping_key   int NOT NULL,
	 people_key     int NOT NULL,
	 location_key	int NOT NULL,
	 returned       boolean NOT NULL,
	 sales          decimal(18,2) NOT NULL,
	 quantity       int NOT NULL,
	 discount       decimal(3,2) NOT NULL,
	 profit         decimal(18,2) NOT NULL,
	 CONSTRAINT FK_1 FOREIGN KEY ( product_key ) REFERENCES dwh.product_dim ( product_key ),
	 CONSTRAINT FK_2 FOREIGN KEY ( order_date_key ) REFERENCES dwh.date_dim ( "date" ),
	 CONSTRAINT FK_3 FOREIGN KEY ( customer_key ) REFERENCES dwh.customer_dim ( customer_key ),
	 CONSTRAINT FK_4 FOREIGN KEY ( ship_date_key ) REFERENCES dwh.date_dim ( "date" ),
	 CONSTRAINT FK_5 FOREIGN KEY ( shipping_key ) REFERENCES dwh.shiping_dim ( shipping_key ),
	 CONSTRAINT FK_6 FOREIGN KEY ( people_key ) REFERENCES dwh.people_dim  ( people_key ),
	 CONSTRAINT FK_7 FOREIGN KEY ( location_key ) REFERENCES dwh.location_dim  ( location_key )
);

CREATE INDEX FK_2 ON dwh.order_detales_fact
(
 	product_key
);

CREATE INDEX FK_3 ON dwh.order_detales_fact
(
 	order_date_key
);

CREATE INDEX FK_4 ON dwh.order_detales_fact
(
 	customer_key
);

CREATE INDEX FK_5 ON dwh.order_detales_fact
(
 	ship_date_key
);

CREATE INDEX FK_6 ON dwh.order_detales_fact
(
 	shipping_key
);

CREATE INDEX FK_7 ON dwh.order_detales_fact
(
 	people_key
);

CREATE INDEX FK_8 ON dwh.order_detales_fact
(
 	location_key
);


INSERT INTO dwh.order_detales_fact(
	row_id, 
	order_id, 
	ship_date_key, 
	customer_key, 
	order_date_key, 
	product_key,
	
	shipping_key,
	people_key,
	location_key,
	 
	returned, 
	sales, 
	quantity, 
	discount, 
	profit)
SELECT 
	o.row_id, 
	o.order_id,
	o.ship_date,
	c.customer_key, 
	o.order_date,
	p.product_key,
	
	sd.shipping_key,
	pd.people_key,
	ld.location_key,
	
	case 
		when r.returned is null then
			false
		else
			true
	end,
	o.sales, 
	o.quantity, 
	o.discount, 
	o.profit
FROM stg.orders o left join dwh.customer_dim c on o.customer_id = c.customer_id 
	left join dwh.product_dim p on o.product_id = p.product_id and o.product_name = p.product_name
	left join stg.people s on o.region = s.region
	left join dwh.people_dim pd on pd.sales_name = s.person
	left join dwh.shiping_dim sd on sd.ship_mode = o.ship_mode
	left join dwh.location_dim ld on ld.country = o.country and ld.city = o.city and ld.state = o.state 
		and ld.region = o.region and (ld.postal_code = o.postal_code::varchar or o.postal_code is null)
	left join (
		select distinct 
			*
		from stg."returns") r on o.order_id = r.order_id ;
	
--test

select 
count(*)
from dwh.order_detales_fact odf 
join dwh.customer_dim cd on cd.customer_key = odf.customer_key 
join dwh.date_dim ship_date on ship_date."date" = odf.ship_date_key
join dwh.date_dim order_date on order_date."date" = odf.order_date_key
join dwh.location_dim ld on ld.location_key = odf.location_key 
join dwh.people_dim pd on pd.people_key = odf.people_key 
join dwh.product_dim product on product.product_key = odf.product_key
join dwh.shiping_dim sd on sd.shipping_key = odf.shipping_key 

-- end
