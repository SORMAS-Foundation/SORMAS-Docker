CREATE DATABASE second_database_created_by_init;
\c second_database_created_by_init;

CREATE SEQUENCE seq_person;
CREATE TABLE Persons (
    LastName varchar(255),
    FirstName varchar(255),
    id integer NOT NULL DEFAULT nextval('seq_person')
);

INSERT INTO Persons VALUES ('Third', 'User');
INSERT INTO Persons VALUES ('Fourth', 'User');
