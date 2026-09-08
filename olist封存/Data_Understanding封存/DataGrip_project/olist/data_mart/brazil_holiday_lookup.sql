DROP TABLE IF EXISTS olist_data_mart.brazil_holiday_lookup;


CREATE TABLE olist_data_mart.brazil_holiday_lookup(
    holiday_date DATE primary key,
    holiday_name VARCHAR(100) NOT NULL,
    holiday_type VARCHAR(50) NOT NULL
);


INSERT INTO olist_data_mart.brazil_holiday_lookup
    (holiday_date, holiday_name, holiday_type)
VALUES
-- 2016
('2016-01-01', 'New Year''s Day', 'national'),
('2016-02-09', 'Carnival Tuesday', 'government_holiday'),
('2016-02-10', 'Carnival End / Ash Wednesday', 'government_holiday'),
('2016-03-25', 'Good Friday', 'national_or_widely_observed'),
('2016-04-21', 'Tiradentes Day', 'national'),
('2016-05-01', 'Labour Day', 'national'),
('2016-05-26', 'Corpus Christi', 'government_or_widely_observed'),
('2016-09-07', 'Independence Day', 'national'),
('2016-10-12', 'Our Lady of Aparecida', 'national'),
('2016-11-02', 'All Souls'' Day', 'national'),
('2016-11-15', 'Republic Day', 'national'),
('2016-12-25', 'Christmas Day', 'national'),

-- 2017
('2017-01-01', 'New Year''s Day', 'national'),
('2017-02-28', 'Carnival Tuesday', 'government_holiday'),
('2017-03-01', 'Carnival End / Ash Wednesday', 'government_holiday'),
('2017-04-14', 'Good Friday', 'national_or_widely_observed'),
('2017-04-21', 'Tiradentes Day', 'national'),
('2017-05-01', 'Labour Day', 'national'),
('2017-06-15', 'Corpus Christi', 'government_or_widely_observed'),
('2017-09-07', 'Independence Day', 'national'),
('2017-10-12', 'Our Lady of Aparecida', 'national'),
('2017-11-02', 'All Souls'' Day', 'national'),
('2017-11-15', 'Republic Day', 'national'),
('2017-12-25', 'Christmas Day', 'national'),

-- 2018
('2018-01-01', 'New Year''s Day', 'national'),
('2018-02-13', 'Carnival Tuesday', 'government_holiday'),
('2018-02-14', 'Carnival End / Ash Wednesday', 'government_holiday'),
('2018-03-30', 'Good Friday', 'national_or_widely_observed'),
('2018-04-21', 'Tiradentes Day', 'national'),
('2018-05-01', 'Labour Day', 'national'),
('2018-05-31', 'Corpus Christi', 'government_or_widely_observed'),
('2018-09-07', 'Independence Day', 'national'),
('2018-10-12', 'Our Lady of Aparecida', 'national'),
('2018-11-02', 'All Souls'' Day', 'national'),
('2018-11-15', 'Republic Day', 'national'),
('2018-12-25', 'Christmas Day', 'national');