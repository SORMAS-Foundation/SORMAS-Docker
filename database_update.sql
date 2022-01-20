-- 2021-08-23 set symptomatic to null when visit was performed unsuccessfully
UPDATE symptoms SET symptomatic=null FROM visit WHERE visit.symptoms_id = symptoms.id AND visit.visitstatus!='COOPERATIVE';

INSERT INTO schema_version (version_number, comment) VALUES (402, 'Update symptomatic-status for visits #6466');

-- 2021-08-01 Modifications to immunization tables #6025
ALTER TABLE immunization ALTER COLUMN externalid DROP NOT NULL;
ALTER TABLE immunization ALTER COLUMN positivetestresultdate DROP NOT NULL;
ALTER TABLE immunization ALTER COLUMN recoverydate DROP NOT NULL;
ALTER TABLE immunization ADD COLUMN diseasedetails varchar(512);
ALTER TABLE immunization ADD COLUMN healthfacility_id bigint;
ALTER TABLE immunization ADD COLUMN healthfacilitydetails varchar(512);
ALTER TABLE immunization ADD COLUMN facilitytype varchar(255);
ALTER TABLE immunization ADD COLUMN validfrom timestamp;
ALTER TABLE immunization ADD COLUMN validuntil timestamp;
ALTER TABLE immunization ADD CONSTRAINT fk_immunization_healthfacility_id FOREIGN KEY (healthfacility_id) REFERENCES facility(id);

ALTER TABLE immunization_history ALTER COLUMN externalid DROP NOT NULL;
ALTER TABLE immunization_history ALTER COLUMN positivetestresultdate DROP NOT NULL;
ALTER TABLE immunization_history ALTER COLUMN recoverydate DROP NOT NULL;
ALTER TABLE immunization_history ADD COLUMN diseasedetails varchar(512);
ALTER TABLE immunization_history ADD COLUMN healthfacility_id bigint;
ALTER TABLE immunization_history ADD COLUMN healthfacilitydetails varchar(512);
ALTER TABLE immunization_history ADD COLUMN facilitytype varchar(255);
ALTER TABLE immunization_history ADD COLUMN validfrom timestamp;
ALTER TABLE immunization_history ADD COLUMN validuntil timestamp;

INSERT INTO schema_version (version_number, comment) VALUES (403, 'Modifications to immunization tables #6025');

-- 2021-08-30 - Add TravelEntries to tasks #5844
ALTER TABLE task ADD COLUMN travelentry_id bigint;
ALTER TABLE task ADD CONSTRAINT fk_task_travelentry_id FOREIGN KEY (travelentry_id) REFERENCES travelentry (id);
ALTER TABLE task_history ADD COLUMN travelentry_id bigint;

INSERT INTO schema_version (version_number, comment) VALUES (404, 'Add TravelEntries to tasks #5844');

-- 2021-09-13 - Vaccination drop details columns #5843
ALTER TABLE vaccination DROP COLUMN vaccinenamedetails;
ALTER TABLE vaccination DROP COLUMN vaccinemanufacturerdetails;
ALTER TABLE vaccination_history DROP COLUMN vaccinenamedetails;
ALTER TABLE vaccination_history DROP COLUMN vaccinemanufacturerdetails;

INSERT INTO schema_version (version_number, comment) VALUES (405, 'Vaccination drop details columns #5843');

-- 2021-09-03 Vaccination refactoring #5909
/* Vaccination refactoring */
/* Step 1: Create a temporary table containing the latest vaccination information for each disease of each person */
DROP TABLE IF EXISTS tmp_vaccinated_entities;
CREATE TEMP TABLE tmp_vaccinated_entities AS
(
    SELECT DISTINCT ON (person.id, cases.disease)
        person.id AS person_id, cases.disease, cases.reportdate AS reportdate, cases.diseasedetails, cases.reportinguser_id,
        cases.responsibleregion_id AS responsibleregion_id, cases.responsibledistrict_id AS responsibledistrict_id, cases.responsiblecommunity_id AS responsiblecommunity_id,
        cases.firstvaccinationdate, cases.lastvaccinationdate, CAST(NULLIF(cases.vaccinationdoses, '') AS int) AS vaccinationdoses,
        CASE
            WHEN
                (cases.vaccinename IS NOT NULL OR cases.vaccine IS NULL)
                THEN
                vaccinename
            ELSE
                'OTHER'
            END
            AS vaccinename,
        CASE
            WHEN
                cases.vaccinename = 'OTHER'
                THEN
                cases.othervaccinename
            ELSE
                cases.vaccine
            END
            AS othervaccinename,
        cases.vaccinemanufacturer, cases.othervaccinemanufacturer, cases.vaccinationinfosource, cases.vaccineinn, cases.vaccinebatchnumber,
        cases.vaccineuniicode, cases.vaccineatccode, cases.pregnant AS pregnant, cases.trimester AS trimester, clinicalcourse.healthconditions_id AS healthconditions_id,
        coalesce(symptoms.onsetdate, cases.reportdate) AS relevancedate
    FROM person
             LEFT JOIN cases ON cases.person_id = person.id
             LEFT JOIN clinicalcourse ON cases.clinicalcourse_id = clinicalcourse.id
             LEFT JOIN symptoms ON cases.symptoms_id = symptoms.id
    WHERE cases.vaccination = 'VACCINATED' AND cases.deleted = false
    ORDER BY person.id, cases.disease, relevancedate DESC
)
UNION
(
    SELECT DISTINCT ON (person.id, contact.disease)
        person.id AS person_id, contact.disease, contact.reportdatetime AS reportdate, contact.diseasedetails, contact.reportinguser_id,
        CASE
            WHEN
                contact.region_id IS NOT NULL
                THEN
                contact.region_id
            ELSE
                cases.responsibleregion_id
            END
                  AS responsibleregion_id,
        CASE
            WHEN
                contact.district_id IS NOT NULL
                THEN
                contact.district_id
            ELSE
                cases.responsibledistrict_id
            END
                  AS responsibledistrict_id,
        CASE
            WHEN
                contact.community_id IS NOT NULL
                THEN
                contact.community_id
            ELSE
                cases.responsiblecommunity_id
            END
                  AS responsiblecommunity_id,
        vaccinationinfo.firstvaccinationdate, vaccinationinfo.lastvaccinationdate, CAST(NULLIF(vaccinationinfo.vaccinationdoses, '') AS int) AS vaccinationdoses,
        vaccinationinfo.vaccinename AS vaccinename, vaccinationinfo.othervaccinename AS othervaccinename, vaccinationinfo.vaccinemanufacturer,
        vaccinationinfo.othervaccinemanufacturer, vaccinationinfo.vaccinationinfosource, vaccinationinfo.vaccineinn, vaccinationinfo.vaccinebatchnumber,
        vaccinationinfo.vaccineuniicode, vaccinationinfo.vaccineatccode, null AS pregnant, null AS trimester, contact.healthconditions_id AS healthconditions_id,
        coalesce(contact.lastcontactdate, contact.reportdatetime) AS relevancedate
    FROM person
             LEFT JOIN contact ON contact.person_id = person.id
             LEFT JOIN cases ON contact.caze_id = cases.id
             LEFT JOIN vaccinationinfo ON contact.vaccinationinfo_id = vaccinationinfo.id
    WHERE vaccinationinfo.vaccination = 'VACCINATED' AND contact.deleted = false
    ORDER BY person.id, contact.disease, relevancedate DESC
)
UNION
(
    SELECT DISTINCT ON (person.id, events.disease)
        person.id AS person_id, events.disease, events.reportdatetime AS reportdate, events.diseasedetails, eventparticipant.reportinguser_id,
        CASE
            WHEN
                eventparticipant.region_id IS NOT NULL
                THEN
                eventparticipant.region_id
            ELSE
                location.region_id
            END
                  AS responsibleregion_id,
        CASE
            WHEN
                eventparticipant.district_id IS NOT NULL
                THEN
                eventparticipant.district_id
            ELSE
                location.district_id
            END
                  AS responsibledistrict_id,
        location.community_id AS responsiblecommunity, vaccinationinfo.firstvaccinationdate, vaccinationinfo.lastvaccinationdate,
        CAST(NULLIF(vaccinationinfo.vaccinationdoses, '') AS int) AS vaccinationdoses, vaccinationinfo.vaccinename AS vaccinename, vaccinationinfo.othervaccinename AS othervaccinename,
        vaccinationinfo.vaccinemanufacturer, vaccinationinfo.othervaccinemanufacturer, vaccinationinfo.vaccinationinfosource, vaccinationinfo.vaccineinn,
        vaccinationinfo.vaccinebatchnumber, vaccinationinfo.vaccineuniicode, vaccinationinfo.vaccineatccode, null AS pregnant, null AS trimester, null AS healthconditions_id,
        coalesce(events.startdate, events.enddate, events.reportdatetime) AS relevancedate
    FROM person
             LEFT JOIN eventparticipant ON eventparticipant.person_id = person.id
             LEFT JOIN events ON eventparticipant.event_id = events.id
             LEFT JOIN location ON events.eventlocation_id = location.id
             LEFT JOIN vaccinationinfo ON eventparticipant.vaccinationinfo_id = vaccinationinfo.id
    WHERE vaccinationinfo.vaccination = 'VACCINATED' AND eventparticipant.deleted = false
    ORDER BY person.id, events.disease, relevancedate DESC
);

DROP TABLE IF EXISTS tmp_vaccinated_persons;
CREATE TEMP TABLE tmp_vaccinated_persons AS
SELECT DISTINCT ON (person_id, disease) person_id,
                                        disease, diseasedetails, reportdate, reportinguser_id, responsibleregion_id, responsibledistrict_id, responsiblecommunity_id,
                                        firstvaccinationdate, lastvaccinationdate, vaccinationdoses, vaccinename, othervaccinename, vaccinemanufacturer, othervaccinemanufacturer,
                                        vaccinationinfosource, vaccineinn, vaccinebatchnumber, vaccineuniicode, vaccineatccode, pregnant, trimester, healthconditions_id,
                                        nextval('entity_seq') AS immunization_id, relevancedate
FROM tmp_vaccinated_entities
ORDER BY person_id, disease, relevancedate DESC;

/* Step 2: Create a new immunization entity for each person-disease combination */
INSERT INTO immunization
(
    id, uuid, disease, diseasedetails, person_id, reportdate, reportinguser_id, immunizationstatus, meansofimmunization, immunizationmanagementstatus, responsibleregion_id,
    responsibledistrict_id, responsiblecommunity_id, startdate, enddate, numberofdoses, changedate, creationdate
)
SELECT
    immunization_id, generate_base32_uuid(), disease, diseasedetails, person_id, reportdate, reportinguser_id, 'ACQUIRED', 'VACCINATION', 'COMPLETED',
    responsibleregion_id, responsibledistrict_id, responsiblecommunity_id, firstvaccinationdate, lastvaccinationdate, vaccinationdoses, now(), now()
FROM tmp_vaccinated_persons;

/* Step 3: Create a new vaccination entity for each immunization start and date (or for each immunization without a start or end date) */
CREATE OR REPLACE FUNCTION clone_healthconditions(healthconditions_id bigint)
    RETURNS bigint
    LANGUAGE plpgsql
    SECURITY DEFINER AS
$BODY$
DECLARE new_id bigint;
BEGIN
    DROP TABLE IF EXISTS tmp_healthconditions;
    CREATE TEMP TABLE tmp_healthconditions AS SELECT * FROM healthconditions WHERE id = healthconditions_id;
    UPDATE tmp_healthconditions SET id = nextval('entity_seq'), uuid = generate_base32_uuid(), changedate = now(), creationdate = now(), sys_period = tstzrange(now(), null);
    INSERT INTO healthconditions SELECT * FROM tmp_healthconditions RETURNING id INTO new_id;
    DROP TABLE IF EXISTS tmp_healthconditions;
    RETURN new_id;
END;
$BODY$;
ALTER FUNCTION clone_healthconditions(bigint) OWNER TO sormas_user;

CREATE OR REPLACE FUNCTION create_healthconditions()
    RETURNS bigint
    LANGUAGE plpgsql
    SECURITY DEFINER AS
$BODY$
DECLARE new_id bigint;
BEGIN
    INSERT INTO healthconditions (id, uuid, changedate, creationdate) VALUES (nextval('entity_seq'), generate_base32_uuid(), now(), now()) RETURNING id INTO new_id;
    RETURN new_id;
END;
$BODY$;
ALTER FUNCTION create_healthconditions() OWNER TO sormas_user;

CREATE OR REPLACE FUNCTION create_vaccination(
    immunization_id bigint, new_healthconditions_id bigint, reportdate timestamp, reportinguser_id bigint, vaccinationdate timestamp, vaccinename varchar(255),
    othervaccinename text, vaccinemanufacturer varchar(255), othervaccinemanufacturer text, vaccineinn text, vaccinebatchnumber text, vaccineuniicode text,
    vaccineatccode text, vaccinationinfosource varchar(255), pregnant varchar(255), trimester varchar(255))
    RETURNS void
    LANGUAGE plpgsql
    SECURITY DEFINER AS
$BODY$
BEGIN
    INSERT INTO vaccination (
        id, uuid, changedate, creationdate, immunization_id, healthconditions_id, reportdate, reportinguser_id, vaccinationdate, vaccinename, othervaccinename,
        vaccinemanufacturer, othervaccinemanufacturer, vaccineinn, vaccinebatchnumber, vaccineuniicode, vaccineatccode, vaccinationinfosource, pregnant, trimester
    )
    VALUES (
               nextval('entity_seq'), generate_base32_uuid(), now(), now(), immunization_id, new_healthconditions_id, reportdate, reportinguser_id,
               vaccinationdate, vaccinename, othervaccinename, vaccinemanufacturer, othervaccinemanufacturer, vaccineinn, vaccinebatchnumber, vaccineuniicode,
               vaccineatccode, vaccinationinfosource, pregnant, trimester
           );
END;
$BODY$;
ALTER FUNCTION create_vaccination(
    bigint, bigint, timestamp, bigint, timestamp, varchar(255), text, varchar(255), text, text, text, text, text, varchar(255),
    varchar(255), varchar(255)
    ) OWNER TO sormas_user;

DO $$
    DECLARE rec RECORD;
        DECLARE new_healthconditions_id bigint;
    BEGIN
        FOR rec IN SELECT * FROM tmp_vaccinated_persons
            LOOP
                IF (
                        rec.firstvaccinationdate IS NOT NULL OR
                        (
                            rec.firstvaccinationdate IS NULL AND
                            rec.lastvaccinationdate IS NULL
                        )
                    )
                THEN
                    PERFORM create_vaccination(
                            rec.immunization_id,
                            CASE WHEN rec.healthconditions_id IS NOT NULL THEN (SELECT * FROM clone_healthconditions(rec.healthconditions_id)) ELSE (SELECT * FROM create_healthconditions()) END,
                            rec.reportdate, rec.reportinguser_id, rec.firstvaccinationdate,
                            CASE
                                WHEN
                                            rec.vaccinename = 'ASTRA_ZENECA_COMIRNATY' OR rec.vaccinename = 'ASTRA_ZENECA_MRNA_1273'
                                    THEN
                                    'OXFORD_ASTRA_ZENECA'
                                ELSE
                                    rec.vaccinename
                                END,
                            rec.othervaccinename,
                            CASE
                                WHEN
                                            rec.vaccinename = 'ASTRA_ZENECA_COMIRNATY' OR rec.vaccinename = 'ASTRA_ZENECA_MRNA_1273'
                                    THEN
                                    'ASTRA_ZENECA'
                                ELSE
                                    rec.vaccinemanufacturer
                                END,
                            rec.othervaccinemanufacturer, rec.vaccineinn, rec.vaccinebatchnumber,
                            rec.vaccineuniicode, rec.vaccineatccode, rec.vaccinationinfosource,
                            rec.pregnant, rec.trimester
                        );
                END IF;

                IF (
                        rec.lastvaccinationdate IS NOT NULL OR
                        rec.vaccinename = 'ASTRA_ZENECA_COMIRNATY' OR
                        rec.vaccinename = 'ASTRA_ZENECA_MRNA_1273'
                    )
                THEN
                    PERFORM create_vaccination(
                            rec.immunization_id,
                            CASE WHEN rec.healthconditions_id IS NOT NULL THEN (SELECT * FROM clone_healthconditions(rec.healthconditions_id)) ELSE (SELECT * FROM create_healthconditions()) END,
                            rec.reportdate, rec.reportinguser_id, rec.lastvaccinationdate,
                            CASE
                                WHEN
                                        rec.vaccinename = 'ASTRA_ZENECA_COMIRNATY'
                                    THEN
                                    'COMIRNATY'
                                WHEN
                                        rec.vaccinename = 'ASTRA_ZENECA_MRNA_1273'
                                    THEN
                                    'MRNA_1273'
                                ELSE
                                    rec.vaccinename
                                END,
                            rec.othervaccinename,
                            CASE
                                WHEN
                                        rec.vaccinename = 'ASTRA_ZENECA_COMIRNATY'
                                    THEN
                                    'BIONTECH_PFIZER'
                                WHEN
                                        rec.vaccinename = 'ASTRA_ZENECA_MRNA_1273'
                                    THEN
                                    'MODERNA'
                                ELSE
                                    rec.vaccinemanufacturer
                                END,
                            rec.othervaccinemanufacturer, rec.vaccineinn, rec.vaccinebatchnumber,
                            rec.vaccineuniicode, rec.vaccineatccode, rec.vaccinationinfosource,
                            rec.pregnant, rec.trimester
                        );
                END IF;
            END LOOP;
    END;
$$ LANGUAGE plpgsql;

DROP TABLE IF EXISTS tmp_vaccinated_entities;
DROP TABLE IF EXISTS tmp_vaccinated_persons;
DROP FUNCTION IF EXISTS clone_healthconditions(bigint);
DROP FUNCTION IF EXISTS create_healthconditions();
DROP FUNCTION IF EXISTS create_vaccination(bigint, bigint, timestamp, bigint, timestamp, varchar(255), text, varchar(255), text, text, text, text, text, varchar(255), varchar(255), varchar(255));

/* Step 4: Clean up cases, contacts and event participants */
ALTER TABLE cases RENAME COLUMN vaccination TO vaccinationstatus;
ALTER TABLE cases_history RENAME COLUMN vaccination TO vaccinationstatus;
-- last vaccination date has been moved to the vaccination entity, but still has to be used for Monkeypox
ALTER TABLE cases RENAME COLUMN lastvaccinationdate TO smallpoxlastvaccinationdate;
ALTER TABLE cases_history RENAME COLUMN lastvaccinationdate TO smallpoxlastvaccinationdate;
UPDATE cases SET smallpoxlastvaccinationdate = null WHERE disease != 'MONKEYPOX';

ALTER TABLE cases DROP COLUMN vaccinationdoses;
ALTER TABLE cases DROP COLUMN vaccinationinfosource;
ALTER TABLE cases DROP COLUMN firstvaccinationdate;
ALTER TABLE cases DROP COLUMN vaccinename;
ALTER TABLE cases DROP COLUMN othervaccinename;
ALTER TABLE cases DROP COLUMN vaccinemanufacturer;
ALTER TABLE cases DROP COLUMN othervaccinemanufacturer;
ALTER TABLE cases DROP COLUMN vaccineinn;
ALTER TABLE cases DROP COLUMN vaccinebatchnumber;
ALTER TABLE cases DROP COLUMN vaccineuniicode;
ALTER TABLE cases DROP COLUMN vaccineatccode;
ALTER TABLE cases DROP COLUMN vaccine;

ALTER TABLE contact ADD COLUMN vaccinationstatus varchar(255);
ALTER TABLE contact_history ADD COLUMN vaccinationstatus varchar(255);
ALTER TABLE eventparticipant ADD COLUMN vaccinationstatus varchar(255);
ALTER TABLE eventparticipant_history ADD COLUMN vaccinationstatus varchar(255);

UPDATE contact SET vaccinationstatus = vaccinationinfo.vaccination, changedate = now() FROM vaccinationinfo WHERE contact.vaccinationinfo_id = vaccinationinfo.id;
UPDATE eventparticipant SET vaccinationstatus = vaccinationinfo.vaccination, changedate = now() FROM vaccinationinfo WHERE eventparticipant.vaccinationinfo_id = vaccinationinfo.id;

ALTER TABLE contact DROP COLUMN vaccinationinfo_id;
ALTER TABLE eventparticipant DROP COLUMN vaccinationinfo_id;
DROP TABLE IF EXISTS vaccinationinfo;

UPDATE exportconfiguration SET propertiesstring = replace(propertiesstring, 'vaccination,', 'vaccinationstatus,');

UPDATE featureconfiguration SET enabled = true, changedate = now() WHERE featuretype = 'IMMUNIZATION_MANAGEMENT';
UPDATE featureconfiguration SET enabled = true, changedate = now() WHERE featuretype = 'IMMUNIZATION_STATUS_AUTOMATION';
/* End of vaccination refactoring */

INSERT INTO schema_version (version_number, comment) VALUES (406, 'Vaccination refactoring #5909');