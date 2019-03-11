DROP TABLE patients CASCADE CONSTRAINTS;
DROP TABLE doctor CASCADE CONSTRAINTS;
DROP TABLE employees CASCADE CONSTRAINTS;
DROP TABLE rooms CASCADE CONSTRAINTS;
DROP TABLE equipmenttypes CASCADE CONSTRAINTS;
DROP TABLE equipment CASCADE CONSTRAINTS;
DROP TABLE roomservice CASCADE CONSTRAINTS;
DROP TABLE roomaccess CASCADE CONSTRAINTS;
DROP TABLE admission CASCADE CONSTRAINTS;
DROP TABLE examine CASCADE CONSTRAINTS;
DROP TABLE stayin CASCADE CONSTRAINTS;


CREATE TABLE patients (
    ssn         VARCHAR2(25) PRIMARY KEY,
    firstname   VARCHAR2(25) NOT NULL,
    lastname    VARCHAR2(25) NOT NULL,
    address     VARCHAR2(100),
    telnum      VARCHAR2(25)
);
CREATE TABLE doctor (
    id          VARCHAR2(20) PRIMARY KEY,
    gender      VARCHAR2(10),
    specialty   VARCHAR2(20),
    lastname    VARCHAR2(20) NOT NULL,
    firstname   VARCHAR2(20) NOT NULL
);
 
CREATE TABLE employees (
    id             VARCHAR(20) PRIMARY KEY,
    fname          VARCHAR(20) NOT NULL,
    lname          VARCHAR(20) NOT NULL,
    salary         NUMBER(10) NOT NULL,
    jobtitle       VARCHAR(20) NOT NULL,
    officenum      VARCHAR(10),
    emprank        VARCHAR(20) DEFAULT ( 'Regular Employee' ),
    supervisorid   VARCHAR2(20)
);
CREATE TABLE rooms (
    roomnum         NUMBER(10) PRIMARY KEY,
    occupied_flag   NUMBER(2) DEFAULT ( 0 )
);

CREATE TABLE equipmenttypes (
    id              VARCHAR(20) PRIMARY KEY,
    descrp          VARCHAR(100) NOT NULL,
    model           VARCHAR(20) NOT NULL,
    instructions    VARCHAR(200),
    numberofunits   NUMBER(10) NOT NULL
);

CREATE TABLE equipment (
    serial#          VARCHAR(20) PRIMARY KEY,
    typeid           VARCHAR2(20)
        CONSTRAINT equipmenttypes_id_fkey
            REFERENCES equipmenttypes ( id ),
    purchaseyear     NUMBER(10) NOT NULL,
    lastinspection   VARCHAR2(10),
    roomnum          NUMBER(10)
        CONSTRAINT equipment_roomnum_fkey
            REFERENCES rooms (roomnum )
);

CREATE TABLE roomservice (
    roomnum   NUMBER(10)
        CONSTRAINT roomservice_roomnum_fkey
            REFERENCES rooms ( roomnum ),
    service   VARCHAR2(20),
    PRIMARY KEY ( roomnum,
                  service )
);

CREATE TABLE roomaccess (
    roomnum   NUMBER(10)
        CONSTRAINT roomaccess_roomnum_fkey
            REFERENCES rooms ( roomnum ),
    empid     VARCHAR2(20)
        CONSTRAINT roomaccess_empid_fkey
            REFERENCES employees ( id ),
    PRIMARY KEY ( roomnum,
                  empid )
);

CREATE TABLE admission (
    admissionnum       NUMBER(10) PRIMARY KEY,
    admissiondate      VARCHAR(20) NOT NULL,
    leavedate          VARCHAR(20),
    totalpayment       NUMBER(10) NOT NULL,
    insurancepayment   NUMBER(10) DEFAULT ( 0 ),
    patientssn         VARCHAR2(20)
        CONSTRAINT admission_patientssn_fkey
            REFERENCES patients( ssn ),
    futurevisit        VARCHAR2(20)
);

CREATE TABLE examine (
    doctorid       VARCHAR2(20)
        CONSTRAINT examine_doctorid_fkey
            REFERENCES doctor( id ),
    admissionnum   NUMBER(10)
        CONSTRAINT examine_admissionnum_fkey
            REFERENCES admission ( admissionnum ),
    doctor_comment        VARCHAR2(100),
    PRIMARY KEY ( doctorid,
                  admissionnum )
);

CREATE TABLE stayin (
    admissionnum   NUMBER NOT NULL
        CONSTRAINT stayin_admissionnum_fkey
            REFERENCES admission ( admissionnum ),
    roomnum        NUMBER(10) NOT NULL
        CONSTRAINT stayin_roomnum_fkey
            REFERENCES rooms (roomnum ),
    startdate      VARCHAR(20) NOT NULL,
    enddate        VARCHAR(20),
    PRIMARY KEY ( admissionnum,
                  roomnum,
                  startdate )
);



/*---------------------------------------------------------------------------------*/
/* TRIGGERS */

/* Insurance update trigger */
CREATE OR REPLACE TRIGGER INSURANCEUPDATE 
BEFORE INSERT OR UPDATE ON ADMISSION
FOR EACH ROW 
BEGIN
  :new.insurancepayment := :new.totalpayment * .65;
END;
/

/* Doctor Visit trigger */

create or replace TRIGGER DOCTORVISIT 
BEFORE INSERT ON examine
FOR EACH ROW   
DECLARE
    serviceType varchar(200); room Number(10);
    /* Gets us list of room# */
    cursor c1 is select roomnum From stayin where admissionnum = :new.admissionnum;
BEGIN
    For rec in c1 loop
        Select service into serviceType
        From roomservice
        Where rec.roomnum = roomnum;
        
        IF serviceType='ICU' AND :new.doctor_comment IS NULL Then
             RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because comment can''t be null');
        END IF;
    END LOOP;
END;

/



create or replace TRIGGER REGULAREMPLOYEECHECK
BEFORE INSERT ON EMPLOYEES 
FOR EACH ROW 
DECLARE 
    sid varchar(20);
BEGIN
    if :new.emprank = 'Regular Employee' Then
        SELECT employees.emprank into sid
        FROM employees
        WHERE id= :new.supervisorid;
        IF siD IS NULL Then
            RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because employee supervisor rank not ''Division Manager'' ');
        END IF;
        IF siD IS NOT NULL AND sid <> 'Division Manager' Then
             RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because employee supervisor rank not ''Division Manager'' ');
        END IF;
    END IF;
END;
/

create or replace TRIGGER DIVISIONMANAGERCHECK 
BEFORE INSERT ON EMPLOYEES
FOR EACH ROW 
DECLARE 
    sid varchar(20);
BEGIN
  if :new.emprank = 'Division Manager' Then
        SELECT employees.emprank into sid
        FROM employees
        WHERE id= :new.supervisorid;

        IF sid <> 'General Manager' Then
            RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because employee supervisor rank not ''Division Manager'' ');
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER GENERALMANAGERCHECK 
BEFORE INSERT ON EMPLOYEES 
FOR EACH ROW
DECLARE 
    sid varchar(20);
BEGIN
    if :new.emprank = 'General Manager'  AND :new.supervisorid IS NOT NULL Then
      
            RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because employee supervisor rank not ''Division Manager'' ');
    END IF;
END;
/
/* CT Scannder and Ultrasound check trigger */
create or replace TRIGGER CTULTRACHECK 
BEFORE INSERT ON EQUIPMENT 
FOR EACH ROW 
DECLARE
    purchaseDate varchar(20);
BEGIN
    IF :new.typeid = 'CT Scanner' OR :new.typeid = 'Ultrasound' Then
        IF :new.purchaseyear <=2006 Then
                RAISE_APPLICATION_ERROR(-20004,'Cannot insert record because purchase year is not recent enough');
        END IF;
    END IF;
END;
/

create or replace TRIGGER PATIENTLEAVEUPDATE 
BEFORE UPDATE OF LEAVEDATE ON ADMISSION 
FOR EACH ROW 
DECLARE 
    /* This gives us doctors that have viewed the patient, thus all the comments and their names */
    cursor c1 is 
    SELECT doctorid
    FROM examine 
    WHERE :old.admissionnum = admissionnum;
    fn varchar(25); ln varchar(25); pAddress varchar(100);  
    df varchar(20); dl varchar(20); dcomment varchar(100);
BEGIN
    /* Retrieves first name, last name, and address of the patient */
    SELECT firstname, lastname, address
    INTO fn, ln, pAddress
    FROM patients
    WHERE :old.patientssn = ssn;
    
    For rec in c1 Loop
        /*Get the doctor's name */
        SELECT firstname, lastname
        INTO df,dl
        FROM doctor
        WHERE rec.doctorid = id;
        
        /*Get the doctor's comments */
        SELECT doctor_comment
        INTO dcomment
        FROM examine
        WHERE rec.doctorid = doctorid;
        
        dbms_output.put_line(fn || ' ' || ln || ' ' || pAddress || ' ' || df || ' ' || dl || ' ' || dcomment); 
    END Loop;
END;
/

create or replace TRIGGER PATIENTLEAVEUPDATE 
BEFORE UPDATE OF LEAVEDATE ON ADMISSION 
FOR EACH ROW 
DECLARE 
    /* This gives us doctors that have viewed the patient, thus all the comments and their names */
    cursor c1 is SELECT doctorid FROM examine WHERE :old.admissionnum = admissionnum;

    fn varchar(25); ln varchar(25); pAddress varchar(100);  
    df varchar(20); dl varchar(20); dcomment varchar(100);
BEGIN
    /* Retrieves first name, last name, and address of the patient */
    SELECT firstname, lastname, address
    INTO fn, ln, pAddress
    FROM patients
    WHERE :old.patientssn = ssn;
    
    For rec in c1 Loop
        /*Get the doctor's name */
        SELECT firstname, lastname
        INTO df,dl
        FROM doctor
        WHERE rec.doctorid = id;
        
        /*Get the doctor's comments */
        SELECT doctor_comment
        INTO dcomment
        FROM examine
        WHERE rec.doctorid = doctorid AND :old.admissionnum = admissionnum;
        DBMS_OUTPUT.PUT_LINE(fn || ' ' || ln || ' ' || pAddress || ' ' || df || ' ' || dl || ' ' || dcomment); 
    END Loop;
END;


/
/*---------------------------------------------------------------------------------*/
/* Patients */
insert into patients VALUES('111-22-3333', 'Carl', 'Wheezer', '123 Highland Street, Worcester, 01609', '855-643-2483');
insert into patients VALUES('158-42-5224', 'Maxine', 'Singleton', '862 West Garden St., Corona, NY 11368', '774-760-6852');
insert into patients VALUES('644-35-8268', 'Tiffany', 'Olson', '872 S. Country Street, Phoenixville, PA 19460', '607-363-7763');
insert into patients VALUES('782-55-0829', 'Grace', 'Morton', '45 High Noon Street, San Angelo, TX 76901', '729-255-2401');
insert into patients VALUES('993-64-1253', 'Darnell', 'Ramos', '9609 River Road, Maineville, OH 45039', '586-698-2906');
insert into patients VALUES('681-76-9487', 'Katrina', 'Norton', '9770 Carriage Court, Hopkins, MN 55343', '501-586-9424');
insert into patients VALUES('905-90-0947', 'Philip', 'Newton', '58 Garfield Ave., Wooster, OH 44691', '145-947-6339');
insert into patients VALUES('602-58-7826', 'Christian', 'Wolfe', '816 Southampton Street, Stafford, VA 22554', '548-811-5080');
insert into patients VALUES('840-52-2349', 'Rachel', 'Brewer', '9 University Drive, Midlothian, VA 23112', '317-235-2567');
insert into patients VALUES('934-58-6472', 'Randall', 'Craig', '11 N. Country Drive, Portsmouth, VA 23703', '147-894-0471');
insert into patients VALUES ('123-45-6789', 'Bobby' , 'Flay', 'Middle of nowhere', '000-000-0000');
insert into patients VALUES ('987-65-4321', 'Gordon' , 'Ramsey', 'Middle of nowhere', '000-000-0000');


INSERT INTO doctor VALUES (
    '1',
    'Male',
    'Surgeon',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '2',
    'Female',
    'Clinician',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '3',
    'Male',
    'None',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '4',
    'Female',
    'Vet',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '5',
    'Male',
    'Surgeon',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '6',
    'Female',
    'None',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '7',
    'Male',
    'Pediatrics',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '8',
    'Female',
    'None',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '9',
    'Male',
    'None',
    'Carlos',
    'Smith'
);

INSERT INTO doctor VALUES (
    '10',
    'Female',
    'None',
    'Carlos',
    'Smith'
);
/* Genderal Managers */
INSERT INTO employees
VALUES('gm1','Fred ','Rogers',100000,'Just a dude', '3', 'General Manager', NULL);
INSERT INTO employees
VALUES('gm2','Eren ','Knightly',100000,'Just a dude', '4', 'General Manager', NULL);

/* Division Managers */
INSERT INTO employees
VALUES('div1','Fred ','Edwards',100000,'Just a dude', '2', 'Division Manager', 'gm1');
INSERT INTO employees
VALUES('div2','Bill ','Edwards',100000,'Just a dude', '2', 'Division Manager', 'gm1');
INSERT INTO employees
VALUES('div3','Fred ','Edwards',100000,'Just a dude', '2', 'Division Manager', 'gm2');
INSERT INTO employees
VALUES('div4','Fred ','Edwards',100000,'Just a dude', '2', 'Division Manager', 'gm2');
/* Intentional Trigger Fail */
INSERT INTO employees
VALUES('div5','Test1','Failure1',100000,'Just a dude', '2', 'Division Manager', 'gm3');
INSERT INTO employees
VALUES('div5','Test2','Failure2',100000,'Just a dude', '2', 'Division Manager', NULL);
/* Regular Employees */
INSERT INTO employees
VALUES('reg1','Bob','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div1');
INSERT INTO employees
VALUES('reg2','Joe','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div1');
INSERT INTO employees
VALUES('reg3','Roger','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div1');
INSERT INTO employees
VALUES('reg4','Eli','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div1');
INSERT INTO employees
VALUES('reg5','Connor','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div4');
INSERT INTO employees
VALUES('reg6','Zach','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div2');
INSERT INTO employees
VALUES('reg7','Sam','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div4');
INSERT INTO employees
VALUES('reg8','John','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div2');
INSERT INTO employees
VALUES('reg9','Bill','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div3');
INSERT INTO employees
VALUES('reg10','Fred ','Smith',100000,'Just a dude', '1', 'Regular Employee', 'div3');





/* Rooms */
INSERT INTO rooms VALUES(1,0);
INSERT INTO rooms VALUES(2,0);
INSERT INTO rooms VALUES(3,1);
INSERT INTO rooms VALUES(4,0);
INSERT INTO rooms VALUES(5,1);
INSERT INTO rooms VALUES(6,0);
INSERT INTO rooms VALUES(7,1);
INSERT INTO rooms VALUES(8,0);
INSERT INTO rooms VALUES(9,1);
INSERT INTO rooms VALUES(10,1);
INSERT INTO rooms VALUES(11,0);


/* Equipment types */
insert into equipmenttypes VALUES('Heart Monitor', 'Collects information on a patients heart', 'Gregnant', 'Press the button', 3);
insert into equipmenttypes VALUES('Breath Monitor', 'Collects information on a patients lungs', 'Whoopscoop', 'Insert into patients lungs', 4);
insert into equipmenttypes VALUES('IV', 'Delivers fluids into a patients vains', 'Skribblebop', 'Stab the patient', 10);
insert into equipmenttypes VALUES('CT Scanner', 'Delivers fluids into a patients vains', 'Skribblebop', 'Stab the patient', 10);
insert into equipmenttypes VALUES('Ultrasound', 'Delivers fluids into a patients vains', 'Skribblebop', 'Stab the patient', 10);




/* Equipment */
insert into equipment VALUES('qUjGwwRT', 'Heart Monitor', 2010, '05-26-2013', '8');
insert into equipment VALUES('qU2GjwRT', 'Heart Monitor', 2010, '05-26-2010', '8');
insert into equipment VALUES('62r4sbKN', 'Heart Monitor', 2006, '07-13-2009', '7');
insert into equipment VALUES('ce5gSHfH', 'Heart Monitor', 2011, '10-03-2015', '1');
insert into equipment VALUES('yLDnSrbo', 'Breath Monitor', 2012, '02-28-2018', '3');
insert into equipment VALUES('cgKsK5Yz', 'Breath Monitor', 2010, '04-19-2019', '5');
insert into equipment VALUES('9LKBRrSB', 'Breath Monitor', 2010, '03-01-3013', '9');
insert into equipment VALUES('RP4otjS4', 'IV', 2010, '12-07-2016', '4');
insert into equipment VALUES('8ZCjEuNa', 'IV', 2011, '01-30-2013', '8');
insert into equipment VALUES('A01-02X', 'IV', 2000, '11-10-2006', '1');

/*Trigger tests */

/* These should fail because purchase year is before 2006 */
insert into equipment VALUES('test_serial_1', 'CT Scanner', 2000, '11-10-2006', '1');
insert into equipment VALUES('test_serial_2', 'Ultrasound', 2000, '11-10-2006', '1');
insert into equipment VALUES('test_serial_3', 'Ultrasound', NULL, '11-10-2006', '1');

/* These should pass because purchase year is after 2006 */
insert into equipment VALUES('test_serial_4', 'CT Scanner', 2007, '11-10-2006', '1');
insert into equipment VALUES('test_serial_5', 'Ultrasound', 2008, '11-10-2006', '1');

/*Room service */
INSERT INTO roomservice VALUES(1,'X-Ray');
INSERT INTO roomservice VALUES(2,'Blood Pump');
INSERT INTO roomservice VALUES(3, 'Blood Pump');
INSERT INTO roomservice VALUES(4, 'X-Ray');
INSERT INTO roomservice VALUES(5, 'Syringe Cabinent');
INSERT INTO roomservice VALUES(6, 'Blood Pump');
INSERT INTO roomservice VALUES(7, 'X-Ray');
INSERT INTO roomservice VALUES(8, 'ICU');
INSERT INTO roomservice VALUES(9, 'ICU');
INSERT INTO roomservice VALUES(10, 'ICU');
INSERT INTO roomservice VALUES(11, 'Emergency room');




/* Room access */
INSERT INTO roomaccess VALUES(1,'reg1');
INSERT INTO roomaccess VALUES(2,'reg1');
INSERT INTO roomaccess VALUES(3,'reg2');
INSERT INTO roomaccess VALUES(1,'reg2');
INSERT INTO roomaccess VALUES(5,'reg2');
INSERT INTO roomaccess VALUES(4,'reg3');

/* Admission */
insert into admission VALUES(1,'2019-05-12', NULL, 248000, 124000, '111-22-3333', '2020-12-10');
insert into admission VALUES(16,'2019-05-12', '2020-12-09', 248000, 124000, '111-22-3333', '2025-12-10');
insert into admission VALUES(17,'2019-05-12', '2020-12-09', 248000, 124000, '111-22-3333', '2025-12-10');
insert into admission VALUES(2,'2002-01-14', '2002-01-15', 1361346, 231567, '158-42-5224',NULL);
insert into admission VALUES(3,'2010-06-05', '2010-06-25', 120558, 12534, '644-35-8268', NULL);
insert into admission VALUES(4,'2003-11-12', '2003-11-15', 702935, 345354, '782-55-0829', NULL);
insert into admission VALUES(5,'1990-04-01', '2000-11-04', 20000000, 12, '993-64-1253', NULL);
insert into admission VALUES(6,'2000-10-12', '2000-12-01', 384763, 384763, '644-35-8268', NULL);
insert into admission VALUES(7,'2001-08-17', '2002-02-09', 512, 22, '905-90-0947', NULL);
insert into admission VALUES(8,'2002-03-30', '2006-11-20', 123856, 98, '602-58-7826', '2020-12-10');
insert into admission VALUES(9,'2015-09-28', '2015-10-09', 464738, 41346, '840-52-2349', NULL);
insert into admission VALUES(10,'2008-04-06', '2008-04-10', 809364, 768674, '934-58-6472', NULL);
insert into admission VALUES(11,'2009-05-13', '2009-06-09', 496743, 30000, '934-58-6472', '2020-12-10');
insert into admission VALUES(12,'2007-01-01', '2007-01-02', 24900, 1500, '934-58-6472', NULL);
insert into admission VALUES(13,'2004-02-13', '2004-07-21', 4454, 200, '111-22-3333', NULL);
insert into admission VALUES(14,'2012-01-12', '2016-02-26', 20004, 1800, '111-22-3333', NULL);
insert into admission VALUES(15,'2015-08-07', '2020-12-09', 368463, 47684, '158-42-5224', NULL);
INSERT INTO admission VALUES(100, '2019-02-22', '2019-02-30', 368463, 47684,'111-22-3333', NULL);

/*ICU View data */ 
INSERT INTO admission VALUES(20,'2019-02-22', '2004-07-21', 1000, 200, '123-45-6789', NULL);
INSERT INTO admission VALUES(21,'2019-02-22', '2004-07-21', 1000, 200, '123-45-6789', NULL);
INSERT INTO admission VALUES(22,'2019-02-22', '2004-07-21', 1000, 200, '123-45-6789', NULL);
INSERT INTO admission VALUES(23,'2019-02-22', '2004-07-21', 1000, 200, '123-45-6789', NULL);
INSERT INTO admission VALUES(24,'2019-02-22', '2004-07-21', 1000, 200, '123-45-6789', NULL);


INSERT INTO admission VALUES(25,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);
INSERT INTO admission VALUES(26,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);
INSERT INTO admission VALUES(27,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);
INSERT INTO admission VALUES(28,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);
INSERT INTO admission VALUES(29,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);
INSERT INTO admission VALUES(30,'2019-02-22', '2004-07-21', 1000, 200, '987-65-4321', NULL);

/* Stayin */
insert into stayin VALUES(1, 5,'2012-10-10','2012-12-10');
insert into stayin VALUES(2,6,'2011-15-10','2012-15-17');
insert into stayin VALUES(2,9,'2011-15-17','2011-15-18');
insert into stayin VALUES(4,8,'2012-10-10','2012-12-10');
insert into stayin VALUES(1,10,'2012-10-10','2012-12-10');

/*ICU View data */ 
INSERT INTO stayin VALUES(20,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(21,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(22,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(23,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(24,8,'2012-10-10','2012-12-10');


INSERT INTO stayin VALUES(25,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(26,8,'2012-10-10','2012-12-10');
INSERT INTO stayin VALUES(27,8,'2012-10-10','2012-12-10');


/* This should trigger the emergency visit trigger */
insert into stayin values(100,11,'2019-02-22', '2019-2-23');

/* Examine */

insert into examine VALUES('1',16,'Did not do fine');
insert into examine VALUES('1',17,'Did not do fine');
insert into examine VALUES('3',2,'Did not do fine');
insert into examine VALUES('9',1,'ok');
insert into examine VALUES('9',2,'fine'); 
insert into examine VALUES('9',4,'fine'); 
insert into examine VALUES('9',5,'fine'); 
INSERT INTO examine VALUES('4',1, 'Doing swell');
INSERT INTO examine VALUES('4',16, 'Doing swole');
INSERT INTO examine VALUES('4',17, 'He thicc');

/* Pop trigger for doctor visit */
insert into examine VALUES('1',1,NULL);

/* Overload View data */
/* ------------ADMISSIONS--------------- */
insert into admission VALUES( 50, '2019-01-01', '2019-02-01', 800, 100, '111-22-3333', NULL);
insert into admission VALUES( 51, '2019-01-02', '2019-02-02', 900, 200, '158-42-5224', NULL);
insert into admission VALUES( 52, '2019-01-03', '2019-02-03', 1000, 300, '644-35-8268', NULL);
insert into admission VALUES( 53, '2019-01-04', '2019-02-04', 1100, 400, '782-55-0829', NULL);
insert into admission VALUES( 54, '2019-01-05', '2019-02-05', 1200, 500, '993-64-1253', NULL);
insert into admission VALUES( 55, '2019-01-06', '2019-02-06', 1300, 600, '681-76-9487', NULL);
insert into admission VALUES( 56, '2019-01-07', '2019-02-07', 1400, 700, '905-90-0947', NULL);
insert into admission VALUES( 57, '2019-01-08', '2019-02-08', 1500, 800, '602-58-7826', NULL);
insert into admission VALUES( 58, '2019-01-09', '2019-02-09', 1600, 900, '840-52-2349', NULL);
insert into admission VALUES( 59, '2019-01-10', '2019-02-10', 1700, 1000, '934-58-6472', NULL);
insert into admission VALUES( 70, '2019-01-11', '2019-02-11', 1800, 1100, '123-45-6789', NULL);
insert into admission VALUES( 71, '2019-01-12', '2019-02-12', 1900, 1200, '987-65-4321', NULL);
/* -----------EXAMINES----------------- */
insert into examine VALUES('2',50,'SHEEEEEEEEN'); 
insert into examine VALUES('2',51,'Ate a can'); 
insert into examine VALUES('2',52,'Got heatvision'); 
insert into examine VALUES('2',53,'Light switch stuck under fingernail'); 
insert into examine VALUES('2',54,'Hair randomly changes color'); 
insert into examine VALUES('2',55,'Old yeller them'); 
insert into examine VALUES('2',56,'Yikes'); 
insert into examine VALUES('2',57,'I dont know if we can save them'); 
insert into examine VALUES('2',58,'YEET'); 
insert into examine VALUES('2',59,'SKRRT'); 
insert into examine VALUES('2',70,'Burnt the burg'); 
insert into examine VALUES('2',71,'Became vegan'); 

INSERT INTO examine VALUES('1',20, 'He hurtin');
INSERT INTO examine VALUES('1',21, 'he still hurtin');

/* Update patient leave trigger check */
update admission
Set leavedate = '2019-05-20'
WHERE admissionnum = 2;



/*---------------------------------------------------------------------------------*/
/* Views */
/*Task 1: Find the critical patients*/
CREATE OR REPLACE VIEW CriticalCases AS
SELECT ssn as Patient_SSN, firstname, lastname, count(admissionnum) as numberOfAdmissionsToICU
FROM (SELECT p.ssn, p.firstname, p.lastname, RS.service, A.admissionnum FROM patients P, admission A, stayin S, roomservice RS
WHERE P.ssn = A.patientssn AND A.admissionnum = S.admissionnum AND S.roomnum = RS.roomnum) 
WHERE service = 'ICU'
GROUP BY ssn, firstname, lastname
HAVING count(admissionnum) >1;

/*Task 2: Find the overloaded and underloadede doctors*/
CREATE OR REPLACE VIEW DoctorsLoad AS
SELECT id as doctorid, gender, 'Overloaded' as load FROM (
SELECT doctorid, count(admissionnum) as cnt
FROM (SELECT distinct admissionnum, doctorid FROM examine) 
group by doctorid) gurt, doctor D
WHERE gurt.cnt > 10 AND gurt.doctorid = D.id
UNION
SELECT id, gender, 'Underloaded' as load FROM (
SELECT doctorid, count(admissionnum) as cnt
FROM (SELECT distinct admissionnum, doctorid FROM examine) 
group by doctorid) gurt, doctor D
WHERE gurt.cnt < 10 AND gurt.doctorid = D.id;



SELECT * FROM CriticalCases;
SELECT * FROM DoctorsLoad;

/*Task 3: Report patients who visited the icu more than 4 times*/
Select * FROM CriticalCases WHERE numberofadmissionstoicu > 4;

/*Task 4: Report the female overloaded doctors*/
SELECT D.id, D.firstname, D.lastname
FROM DoctorsLoad gurt, doctor D
WHERE gurt.doctorid = D.id AND gurt.gender = 'Female' AND gurt.load = 'Overloaded';

/*Task 5: Report comments by underloaded doctors on critical patients*/
SELECT E.doctorid, CC.Patient_SSN, E.doctor_comment
FROM examine E,admission A, CriticalCases CC, DoctorsLoad D
WHERE D.load = 'Underloaded' AND A.patientssn = CC.Patient_SSN AND E.admissionnum = A.admissionnum AND E.doctorid = D.doctorid;




/* Q1: Report the hospital rooms (the room number) that are currently occupied. */
SELECT roomnum
FROM rooms
WHERE occupied_flag = 1;

/* Q2: For a given division manager (say, ID = 10), report all regular employees that are supervised 
by this manager. Display the employees ID, names, and salary. */
SELECT id,fname,lname, salary
FROM employees
WHERE supervisorid='div2';

/* Q3: For each patient, report the sum of amounts paid by the insurance company for that patient, i.e., 
report the patients SSN, and the sum of insurance payments over all visits. */
SELECT patientssn,sum(insurancepayment) as SUM
FROM admission
GROUP BY patientssn;



/* Q4: Report the number of visits done for each patient, i.e., for each patient, report the patient SSN, 
first and last names, and the count of visits done by this patient. */
SELECT patientssn,firstname,lastname,count(patientssn) as Visit_Count
FROM admission A, patients P
WHERE P.ssn = A.patientssn
GROUP BY patientssn, firstname, lastname;


/* Q5: Report the room number that has an equipment unit with serial number ?01-02X? */
SELECT roomnum
FROM equipment
WHERE serial#='A01-02X';

/* Q6: Report the employee who has access to the largest number of rooms. 
We need the employee ID, and the number of rooms (s)he can access. */
SELECT  room_counts.empid, MAX(room_counts.count) as rooms
FROM (
    SELECT empid, count(*) as count
    FROM roomaccess group by empid) room_counts
group by room_counts.empid;


/* Q7: Report the number of regular employees, division managers, and general managers in the hospital. */
SELECT count(emprank) as CNT
FROM employees
GROUP BY emprank;

/* Q8: For patients who have a scheduled future visit (which is part of their most recent visit), report that patient 
(SSN, and first and last names) and the visit date. Do not report patients who do not have scheduled visit. */
SELECT A.patientssn, P.firstname, P.lastname, A.futurevisit
FROM admission A, patients P
WHERE futurevisit is not NULL AND a.patientssn=p.ssn;



/* Q9: For each equipment type that has more than 3 units, 
report the equipment type ID, model, and the number of units this type has. */
SELECT id, model ,numberofunits
FROM equipmenttypes
WHERE numberofunits > 3;

/* Q10: Report the date of the coming future visit for patient with SSN = 111-22-3333. */
SELECT futurevisit
FROM admission
WHERE patientssn = '111-22-3333' AND futurevisit is not NULL;


/* Q11: For patient with SSN = 111-22-3333, report the doctors (only ID) 
who have examined this patient more than 2 times. */


/*Get the admission numbers*/
SELECT doctorid, count(doctorid) as examCount
FROM examine E, admission A
WHERE e.admissionnum=a.admissionnum AND a.patientssn='111-22-3333' 
group by doctorid
having count(doctorid) >2;



/* Q12: Report the equipment types (only the ID) for which the hospital has 
purchased equipments (units) in both 2010 and 2011. Do not report duplication. */
SELECT DISTINCT typeid
FROM equipment
WHERE purchaseyear = 2010 
UNION
SELECT DISTINCT typeid
FROM equipment
WHERE purchaseyear = 2011;