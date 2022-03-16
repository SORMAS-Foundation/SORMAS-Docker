CREATE DATABASE first_database_created_by_init;
\c first_database_created_by_init;

CREATE SEQUENCE seq_person;
CREATE TABLE Persons (
    LastName varchar(255),
    FirstName varchar(255),
    id integer NOT NULL DEFAULT nextval('seq_person')
);

INSERT INTO Persons VALUES ('First', 'User');
INSERT INTO Persons VALUES ('Second', 'User');
