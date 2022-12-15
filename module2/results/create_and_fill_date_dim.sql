
drop if exists table dwh.date_dim;
drop if exists procedure dwh.populate_dim_date;

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
				  from public.orders o);
				 
	enddate := (select 
					case 
						when max(o.order_date) > max(o.ship_date) then
							max(o.order_date)
						else
							max(o.ship_date)
					end min_date
				from public.orders o);

	RAISE notice ' startdate (%) enddate (%) ',startdate, enddate;
	
  	CALL dwh.populate_dim_date(startdate, enddate);

END;
$$;

select 
*
from dwh.date_dim dd;




	