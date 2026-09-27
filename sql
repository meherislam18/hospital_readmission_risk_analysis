SELECT * FROM project2healthdata.diabetic_data_raw;

select count(*)
from diabetic_data_raw;

--data cleaning

-modify text to int; 
ALTER TABLE diabetic_data_raw
MODIFY encounter_id BIGINT,
MODIFY patient_nbr BIGINT,
MODIFY admission_type_id INT,
MODIFY discharge_disposition_id INT,
MODIFY admission_source_id INT,
MODIFY time_in_hospital INT,
MODIFY num_lab_procedures INT,
MODIFY num_procedures INT,
MODIFY num_medications INT,
MODIFY number_outpatient INT,
MODIFY number_emergency INT,
MODIFY number_inpatient INT,
MODIFY number_diagnoses INT;

 -- see datatype
 SELECT  COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'project2healthdata'
  AND TABLE_NAME = 'diabetic_data_raw'
ORDER BY ORDINAL_POSITION;

select * from diabetic_data_raw
limit 10;

--remove question marks from dataset which used to mark null values
update diabetic_data_raw
set race = nullif(race,"?"),
weight= nullif(weight, "?"),
payer_code= nullif(payer_code, "?"),
medical_specialty= nullif(medical_specialty,"?"),
diag_1=nullif(diag_1,"?"),
diag_2=nullif(diag_2,"?"),
diag_3=nullif(diag_3,"?");

select * from diabetic_data_raw
limit 30;

--finding missing data 
select 
round(sum(weight is null)/ count(*) *100,1) as pct_missing_wt,
round(sum(payer_code is null)/ count(*) *100,1) as pct_missing_payer,
round(sum(medical_specialty is null)/ count(*) *100,1) as pct_missing_specialty
from diabetic_data_raw;

--duplicate patient encounters
select patient_nbr,
count(*) as encounter_count
from diabetic_data_raw
group by patient_nbr
having count(*) > 1
order by encounter_count desc
limit 10;

- find unique patient and their earliest encounter who had multiple encounters
create table diabetic_data_dedup as 
select t.*
from diabetic_data_raw as t
inner join
(select patient_nbr,
min(encounter_id) as first_encounter
from diabetic_data_raw
group by patient_nbr) first_enc
on t.patient_nbr = first_enc.patient_nbr 
and t.encounter_id= first_enc.first_encounter;

--left rows after joining;
select count(*) from  diabetic_data_dedup;

--remove encounters that cannot be readmitted
select discharge_disposition_id,
count(*) as encounter_count
from diabetic_data_raw
group by discharge_disposition_id
order by encounter_count desc;

-- checking ids mapping table for hospice, discharge disposition, expried or death
select * from ids_mapping_raw
where description like '%hospice%' or description like '%expired%' or description like '%deceased%';

-- delete  hospice, discharge disposition, expried or death data from ids mapping table as they are not eligible for readmission
delete from diabetic_data_dedup
where discharge_disposition_id in (11,13,14,19,20,21,26); 

-- turn ids_mapping to csv file 
-- check the data coloumns 1st
select * from ids_mapping_raw;

--create the missing coloumn in ids mapping
create table discharge_dispostition_map ( 
discharge_disposition_id int,
description varchar (150));
create table admission_source_map ( 
admission_source_id int,
description varchar (150));

describe  discharge_dispostition_map;
describe  admission_source_map;

--input data to this new tables from ids mapping file that was failed to import whole dataset
 INSERT INTO discharge_dispostition_map
    (discharge_disposition_id, description)
VALUES
    (1, 'Discharged to home'),
    (2, 'Discharged/transferred to another short term hospital'),
    (3, 'Discharged/transferred to SNF'),
    (4, 'Discharged/transferred to ICF'),
    (5, 'Discharged/transferred to another type of inpatient care institution'),
    (6, 'Discharged/transferred to home with home health service'),
    (7, 'Left AMA'),
    (8, 'Discharged/transferred to home under care of Home IV provider'),
    (9, 'Admitted as an inpatient to this hospital'),
    (10, 'Neonate discharged to another hospital for neonatal aftercare'),
    (11, 'Expired'),
    (12, 'Still patient or expected to return for outpatient services'),
    (13, 'Hospice / home'),
    (14, 'Hospice / medical facility'),
    (15, 'Discharged/transferred within this institution to Medicare approved swing bed'),
    (16, 'Discharged/transferred/referred another institution for outpatient services'),
    (17, 'Discharged/transferred/referred to this institution for outpatient services'),
    (18, 'NULL'),
    (19, 'Expired at home. Medicaid only, hospice.'),
    (20, 'Expired in a medical facility. Medicaid only, hospice.'),
    (21, 'Expired, place unknown. Medicaid only, hospice.'),
    (22, 'Discharged/transferred to another rehab fac including rehab units of a hospital.'),
    (23, 'Discharged/transferred to a long term care hospital.'),
    (24, 'Discharged/transferred to a nursing facility certified under Medicaid but not certified under Medicare.'),
    (25, 'Not Mapped'),
    (26, 'Unknown/Invalid'),
    (27, 'Discharged/transferred to a federal health care facility.'),
    (28, 'Discharged/transferred/referred to a psychiatric hospital of psychiatric distinct part unit of a hospital'),
    (29, 'Discharged/transferred to a Critical Access Hospital (CAH).'),
    (30, 'Discharged/transferred to another Type of Health Care Institution not Defined Elsewhere');

  INSERT INTO admission_source_map
    (admission_source_id, description)
VALUES
    (1, 'Physician Referral'),
    (2, 'Clinic Referral'),
    (3, 'HMO Referral'),
    (4, 'Transfer from a hospital'),
    (5, 'Transfer from a Skilled Nursing Facility (SNF)'),
    (6, 'Transfer from another health care facility'),
    (7, 'Emergency Room'),
    (8, 'Court/Law Enforcement'),
    (9, 'Not Available'),
    (10, 'Transfer from a Critical Access Hospital'),
    (11, 'Normal Delivery'),
    (12, 'Premature Delivery'),
    (13, 'Sick Baby'),
    (14, 'Extramural Birth'),
    (15, 'Not Available'),
    (17, 'Not Available'),
    (18, 'Transfer from a hospital'),
    (19, 'Transfer from a Skilled Nursing Facility (SNF)'),
    (20, 'Transfer from another health care facility'),
    (21, 'Unknown/Invalid'),
    (22, 'Transfer from hospital inpatient'),
    (23, 'Born inside this hospital'),
    (24, 'Born outside this hospital'),
    (25, 'Not Available'),
    (26, 'Transfer from Hospice');

-validate the inserts
select * from discharge_dispostition_map;
select * from admission_source_map;

-- cleaning age coloumn removing the bracket;
select * from diabetic_data_dedup
limit 50;

--creating numeric midpoint version along side with original bracket
alter table  diabetic_data_dedup add column  age_midpoint int;
update  diabetic_data_dedup
set  age_midpoint = case
    WHEN age = '[0-10)'   THEN 5
    WHEN age = '[10-20)'  THEN 15
    WHEN age = '[20-30)'  THEN 25
    WHEN age = '[30-40)'  THEN 35
    WHEN age = '[40-50)'  THEN 45
    WHEN age = '[50-60)'  THEN 55
    WHEN age = '[60-70)'  THEN 65
    WHEN age = '[70-80)'  THEN 75
    WHEN age = '[80-90)'  THEN 85
    WHEN age = '[90-100)' THEN 95
END;


-- data analysis
-- what does overall readmission breakdown look
select readmitted, 
count(*) as encounter_count,
round(count(*) / (select count(*) from diabetic_data_dedup) * 100, 1) as pct_of_total
from diabetic_data_dedup
group by readmitted
order by encounter_count desc; 

-- readmission by age
SELECT age, age_midpoint, 
    COUNT(*) as total_encounters, 
    SUM(readmitted = '<30') as readmitted_under_30,
    ROUND(SUM(readmitted = '<30') / COUNT(*) * 100, 1) as readmission_rate_pct
FROM diabetic_data_dedup
GROUP BY age, age_midpoint
ORDER BY age_midpoint;

SELECT 
    readmitted,
    COUNT(*) AS count
FROM diabetic_data_dedup
GROUP BY readmitted;
SELECT 
    COUNT(*) AS under_30_count
FROM diabetic_data_dedup
WHERE readmitted = '<30';

-- checking error for why showing 0 
-- update readmit coloumn
UPDATE diabetic_data_dedup
SET readmitted = REPLACE(
                    REPLACE(readmitted, CHAR(13), ''),
                    CHAR(10), '');
-- verify if its update

SELECT 
    readmitted,
    LENGTH(readmitted) AS length,
    HEX(readmitted) AS hex_value,
    COUNT(*) AS count
FROM diabetic_data_dedup
GROUP BY readmitted;

-- see the results readmission by age
SELECT 
    age,
    age_midpoint,
    COUNT(*) AS total_encounters,
    SUM(readmitted = '<30') AS readmitted_under_30,
    ROUND(
        SUM(readmitted = '<30') / COUNT(*) * 100,
        1
    ) AS readmission_rate
FROM diabetic_data_dedup
GROUP BY age, age_midpoint
ORDER BY age_midpoint;

-- how is patient is readmitted relates to readmission risk
select 
m.description as admission_type,
count(*) as total_encounters,
round(sum(d.readmitted= '<30') / count(*)* 100,1) as readmission_name_pct
from diabetic_data_dedup as d
join ids_mapping_raw as m
on  d.admission_type_id= m.admission_type_id
group by m.description
order by readmission_name_pct desc;

--redmission flag and clean set of risk relevent columns;
with patient_risk_base as (
select
encounter_id, patient_nbr, age_midpoint, time_in_hospital, num_medications, num_lab_procedures, number_diagnoses, number_inpatient,
number_emergency, number_outpatient,diag_1, readmitted, 
case when readmitted= '<30' then 1 else 0 end as is_readmitted_30
from diabetic_data_dedup)
select * from patient_risk_base 
limit 20;

-- within each age group who is carrying the heaviest medication load 
with patient_risk_base as (
select encounter_id, age_midpoint, num_medications, readmitted,
case when readmitted= '<30' then 1 else 0 end as is_readmitted_30
from diabetic_data_dedup)
select encounter_id, age_midpoint, num_medications,
rank() over (partition by age_midpoint order by num_medications desc) as med_rank_age_group
from patient_risk_base
order by age_midpoint, med_rank_age_group
LIMIT 200;

-- population level segmentation by risk groups;

with patient_risk_base as (
select encounter_id, number_inpatient,readmitted, 
case when readmitted= '<30' then 1 else 0 end as is_readmitted_30
from diabetic_data_dedup)
select encounter_id, number_inpatient, 
ntile(4) over (order by number_inpatient desc) as risk_quartile
from patient_risk_base;

-- risk tiering  (easier for non_technicals)
select encounter_id, num_medications,
case 
when num_medications <= 10 then ' low'
when num_medications between 11 and 20 then ' medium'
else 'high'
end as medication_burden_tier,
case when number_diagnoses <= 5 then ' low complexity'
 when number_diagnoses between  6 and 9 then 'moderate complexity'
else ' severe complexity'
end as diagnosis_complexity_tier
from diabetic_data_dedup;

--Which diagnosis categories are driving readmission above our hospital-wide average  based on icd code
-- Find top diagnosis categories driving readmission

WITH diag_categorized AS (
	SELECT encounter_id,  readmitted, 
        CASE
			WHEN diag_1 LIKE '250%' THEN 'Diabetes'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 390 AND 459 THEN 'CIRCULATORY'
			WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 460 AND 519 THEN 'Respiratory'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 520 AND 579 THEN 'Digestive'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 580 AND 629 THEN 'Genitourinary'
            WHEN CAST(LEFT(diag_1, 3) AS UNSIGNED) BETWEEN 800 AND 999 THEN 'Injury'
		ELSE 'Other'
	END AS diagnosis_category, 
    CASE WHEN readmitted = '<30' THEN 1 ELSE 0 END AS is_readmitted_30
	FROM diabetic_data_dedup
    WHERE diag_1 IS NOT NULL)
SELECT diagnosis_cateogry, 
    COUNT(*) AS total_encounters, 
    ROUND(AVG(is_readmitted_30) * 100, 1) AS readmission_rate_pct
FROM diag_categorized
GROUP BY diagnosis_cateogry
HAVING AVG(is_readmitted_30) > ( SELECT AVG(is_readmitted_30) FROM diag_categorized)
ORDER BY readmission_rate_pct DESC;

-- Does a medication change at discharge affect readmission?
select `change_medication`, 
count(*) as total_encounters,
  ROUND(sum(readmitted = '<30') / count(*)* 100, 1) AS readmission_rate_pct
  from diabetic_data_dedup
  group by `change_medication`;

-- finding discharge disposition impact
select 
m.description as discharge_disposition,
count(*) as total_encounters,
  ROUND(sum(d.readmitted = '<30') / count(*)* 100, 1) AS readmission_rate_pct
  from  diabetic_data_dedup as d
join discharge_disposition_map as m
on d.discharge_disposition_id = m.discharge_disposition_id
group by m.description 
having count(*) > 100
order by readmission_rate_pct desc
LIMIT 10;

-- finding A1c testing and readmission
select A1Cresult, 
count(*) as total_encounters, 
  ROUND(sum(readmitted = '<30') / count(*)* 100, 1) AS readmission_rate_pct
  from diabetic_data_dedup
  group by A1Cresult ; 
