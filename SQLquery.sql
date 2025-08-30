create DATABasE EnergyConsump;
use EnergyConsump;
-- 1. country table
create TABLE country(
    CID VARCHAR(10) PRIMARY KEY,
    Country VARCHAR(100) UNIQUE
);
-- has null in last 

-- 2. emission_3 table
create TABLE emission (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission double,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);
-- had null values in emission -- added 0 to null by pandas 

-- 3. population table
create TABLE population (
    countries VARCHAR(100),
    year INT,
    Value double,
    FOREIGN KEY (countries) REFERENCES country(Country)
);
-- had null values in Value -- added 0 to null by pandas 

-- 4. production table
create TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production double,
    FOREIGN KEY (country) REFERENCES country(Country)
);
-- had null values in production -- added 0 to null by pandas 


-- 5. gdp tableproduction
create TABLE gdp (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

-- 6. consumption table
create TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(100),
    year INT,
    consumption double,
    FOREIGN KEY (country) REFERENCES country(Country)
);
-- had null values in consumption -- added 0 to null by pandas

-- added rows in all table by table wizard import


use EnergyConsump;

-- Data Analysis Questions
-- General & Comparative Analysis
-- What is the total emission per country for the most recent year available?

select country, sum(emission)as total_emission from emission
where `year` =
(select MAX(`year`) 
    from emission
    where country = country)
group by country
order by total_emission desc;
    
    
-- What are the top 5 countries by GDP in the most recent year?
select country, sum(`value`)as total_Gdp from gdp
where `year` =
(select MAX(`year`) 
    from gdp
    where country = country) -- 2024 
group by country
order by total_Gdp desc
limit 5;

-- Compare energy production and consumption by country and year. 
with pro as (
	select 
		country, year,
		sum(production) as total_pro
	from production 
	group by country ,year 
	order by total_pro desc
),
con as(
	select 
		country, year,
		sum(consumption) as total_con
	from consumption 
	group by country ,year 
	order by total_con desc
)
select 
	p.country , p.year , 
	p.total_pro, c.total_con, 
	(p.total_pro - c.total_con) as energy_saved
from pro p 
join con c 
	on p.country =c.country 
	and c.year =  p.year
group by p.country , p.year
order by energy_saved desc;


-- Which energy types contribute most to emissions across all countries?
select energy_type,sum(emission)as total_emission from emission
group by energy_type
order by total_emission desc;



--  Trend Analysis Over Time
-- How have global emissions changed year over year?
select year,
sum(emission)as total_emission ,
sum(emission) - lag(sum(emission)) OVER (order by year) as difference_in_year,
round(
        (sum(emission) - lag(sum(emission)) OVER (order by year)) 
        / lag(sum(emission)) OVER (order by year) * 100, 2
    ) as pct_change_from_prev_year
from emission
group by year
order by total_emission desc;

-- What is the trend in GDP for each country over the given years?
select country,year, sum(`value`)as total_Gdp
from gdp
group by country,year
order by country , year desc;

-- How has population growth affected total emissions in each country?   
WITH yearly_data AS (
    SELECT 
        p.countries,
        p.year,
        SUM(p.value) AS total_population,
        SUM(e.emission) AS total_emission
    FROM population p
    JOIN emission e
        ON p.countries = e.country
       AND p.year = e.year
    GROUP BY p.countries, p.year
), 
years AS (
    SELECT 
        countries,
        year,
        total_population,
        total_emission,
        ROUND(
            ((total_population - LAG(total_population) OVER (PARTITION BY countries ORDER BY year)) 
             * 100.0 / LAG(total_population) OVER (PARTITION BY countries ORDER BY year)), 
        2) AS population_growth_pct,
        ROUND(
            ((total_emission - LAG(total_emission) OVER (PARTITION BY countries ORDER BY year)) 
             * 100.0 / LAG(total_emission) OVER (PARTITION BY countries ORDER BY year)), 
        2) AS emission_change_pct
    FROM yearly_data
    ORDER BY countries, year
)
SELECT 
    countries,
    year,
    total_population,
    total_emission,
    population_growth_pct,
    emission_change_pct
FROM years
ORDER BY countries, year;



-- Has energy consumption increased or decreased over the years for major economies?
-- overall
-- increased by 8.97
select  year, sum(consumption) as total_consumption,
round(
        (sum(consumption) - lag(sum(consumption)) OVER (order by year)) 
        / lag(sum(consumption)) OVER (order by year) * 100, 2
    ) as pct_change_from_prev_year
from consumption
where year = 2023 or year = 2020
group by year
having SUM(consumption) != 0
order by year;

--  country wise
WITH consumption_by_year AS (
    SELECT 
        country,
        year,
        SUM(consumption) AS total_consumption
    FROM consumption
    GROUP BY country, year
),
diff AS (
    SELECT 
        country,
        year,
        total_consumption,
        total_consumption - LAG(total_consumption) 
        OVER (PARTITION BY country ORDER BY year) AS consumption_diff
    FROM consumption_by_year
),
only_2023 AS (
    SELECT 
        country,year,total_consumption,consumption_diff
    FROM diff
    WHERE year in (2020,2023)
    group by country,year
)
SELECT country,consumption_diff
FROM only_2023
where consumption_diff is not null
order by consumption_diff desc;




-- What is the average yearly change in emissions per capita for each country?
   
WITH per_capita as (
    select 
        p.countries,
        p.year,
        sum(e.emission) / sum(p.value) as emissions_per_capita
    from population p
    join emission e
        on p.countries = e.country 
       and p.year = e.year
    group by p.countries, p.year
),
yearly_change as (
    select
        countries,
        year,
        emissions_per_capita,
        emissions_per_capita - lag(emissions_per_capita) OVER (PARTITIon BY countries order by year) as change_per_year
    from per_capita
)
select
    countries,
    round(AVG(change_per_year), 5) as avg_yearly_change_per_capita
from yearly_change
WHERE change_per_year IS NOT NULL
group by countries
order by countries ;

    
-- Ratio & Per Capita Analysis
-- What is the emission-to-GDP ratio for each country by year?
select 
    e.country,
    e.year,
    round(sum(e.emission) / sum(g.value), 4) as emission_to_GDP
from gdp g
join emission e
    on g.country = e.country 
   and g.year = e.year
group by e.country, e.year
order by e.country, e.year;


-- What is the energy consumption per capita for each country over the last decade?
select 
        p.countries,p.year,
        sum(e.consumption) as total_energy_consumption,
        sum(pr.production) as total_energy_prduce,
        sum(p.value) as total_population,
        sum(e.consumption) / sum(p.value) as energy_consumption_per_capita,
        sum(pr.production) / sum(p.value) as energy_prod_per_capita
    from population p
    join consumption e
        on p.countries = e.country 
       and p.year = e.year
	join production pr 
		on pr.country = e.country 
       and pr.year = e.year
       where p.year=2020 or p.year=2023
    group by p.countries,p.year
    order by energy_consumption_per_capita desc;
    
-- How does energy production per capita vary across countries?
select 
        p.countries,
        sum(e.production) as total_energy_prduce,
        sum(p.value) as total_population,
        sum(e.production) / sum(p.value) as energy_per_capita
    from population p
    join production e
        on p.countries = e.country and p.year = e.year
    group by p.countries
    order by energy_per_capita desc;


-- Which countries have the highest energy consumption relative to GDP?
select 
	g.country, 
	g.total_gdp,
	sum(c.consumption) as total_consumption
from (
	select country,sum(value) as total_gdp
	from gdp
	group by country
) g 
join consumption c
	on g.country = c.country
group by c.country
order by c.country desc;


-- What is the correlation between GDP growth and energy production growth?
WITH gdp_growth as (
    select 
        country,
        year,
        sum(value) as total_gdp,
        sum(value) - lag(sum(value)) OVER (
            PARTITIon BY country order by year
        ) as gdp_growth
    from gdp
    group by country, year
),
production_growth as (
    select 
        country,
        year,
        sum(production) as total_production,
        sum(production) - lag(sum(production)) OVER (
            PARTITIon BY country order by year
        ) as prod_growth
    from production
    group by country, year
)
select 
    g.country, g.year, g.total_gdp, g.gdp_growth,
    p.total_production, p.prod_growth
from gdp_growth g
join production_growth p
    on g.country = p.country
   and g.year = p.year
order by g.country, g.year;

 -- Global Comparisons
-- What are the top 10 countries by population and how do their emissions compare?
select 
    p.countries,
    p.total_population,
    sum(e.emission) as total_emission
from (
    select countries, sum(value) as total_population
    from population
    group by countries
) p
join emission e
    on p.countries = e.country
group by p.countries, p.total_population
order by p.total_population DESC
LIMIT 10;


-- Which countries have improved (reduced) their per capita emissions the most over the last decade?
WITH total_emission AS (
    SELECT 
        country, 
        year, 
        SUM(emission) AS emi
    FROM emission
    GROUP BY country, year
),
total_population AS (
    SELECT 
        countries, 
        year, 
        SUM(value) AS pop
    FROM population 
    GROUP BY countries, year
),

per_capita_emission AS (
    SELECT e.country,e.year,(e.emi / p.pop) AS emission_per_person
    FROM total_emission  e
    JOIN total_population p 
      ON e.country = p.countries AND e.year = p.year
),
reduction AS (
    SELECT 
        country,year,emission_per_person,
        ROUND(emission_per_person - LAG(emission_per_person) 
        OVER (PARTITION BY country ORDER BY year), 4) AS change_in_decade
    FROM per_capita_emission
    WHERE year IN (2020, 2023) 
)
SELECT 
    country,change_in_decade
FROM reduction
where change_in_decade IS NOT NULL
ORDER BY change_in_decade;





-- What is the global share (%) of emissions by country?
select
    country,
    sum(emission) as total_emission,
    round(
        (sum(emission) / (select sum(emission) from emission) * 100), 
        2
    ) as emission_share_percent
from emission
group by country
order by emission_share_percent desc;


-- What is the global average GDP, emission, population and consumption by year?
select
    g.year,
    round(avg(g.total_gdp), 2) as avg_gdp,
    round(avg(e.total_emission), 2) as avg_emission,
    round(avg(p.total_population), 2) as avg_population,
    round(avg(c.total_consumption),2) as avg_consumption
from(
    select year, sum(value) as total_gdp
    from gdp
    group by year
) g
join (
    select year, sum(emission) as total_emission
    from emission
    group by year
) e on g.year = e.year
join (
    select year, sum(value) as total_population
    from population
    group by year
) p on g.year = p.year
join 
(select year , sum(consumption) as total_consumption
from consumption
group by year
) c on p.year = c.year

group by g.year
order by g.year;

