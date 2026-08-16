SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE Building (
    BuildingID   INT NOT NULL AUTO_INCREMENT,
    BuildingName VARCHAR(100) NOT NULL,
    Location     VARCHAR(100) NOT NULL,
    FloorCount   INT DEFAULT 1,
    TotalArea    DECIMAL(10,2) DEFAULT 0.00,
    PRIMARY KEY (BuildingID)
);

CREATE TABLE Department (
    DeptID     INT NOT NULL AUTO_INCREMENT,
    DeptName   VARCHAR(100) NOT NULL,
    BuildingID INT DEFAULT NULL,
    HeadOfDept VARCHAR(100) DEFAULT 'TBD',
    PRIMARY KEY (DeptID),
    CONSTRAINT fk_dept_building FOREIGN KEY (BuildingID)
        REFERENCES Building(BuildingID) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE EnergySource (
    SourceID       INT NOT NULL AUTO_INCREMENT,
    SourceType     VARCHAR(50) NOT NULL,
    UnitCostPerKWh DECIMAL(8,4) NOT NULL DEFAULT 0.0000,
    Description    VARCHAR(200) DEFAULT NULL,
    PRIMARY KEY (SourceID),
    UNIQUE KEY uq_source_type (SourceType)
);

CREATE TABLE EnergyMeter (
    MeterID          INT NOT NULL AUTO_INCREMENT,
    MeterType        VARCHAR(50) NOT NULL,
    BuildingID       INT NOT NULL,
    InstallationDate DATE NOT NULL,
    Status           ENUM('Active','Inactive') DEFAULT 'Active',
    PRIMARY KEY (MeterID),
    CONSTRAINT fk_meter_building FOREIGN KEY (BuildingID)
        REFERENCES Building(BuildingID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE EnergyReading (
    ReadingID     INT NOT NULL AUTO_INCREMENT,
    MeterID       INT NOT NULL,
    SourceID      INT NOT NULL,
    ReadingDate   DATE NOT NULL,
    UnitsConsumed DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    PeakLoad      DECIMAL(10,2) DEFAULT 0.00,
    PRIMARY KEY (ReadingID),
    CONSTRAINT fk_reading_meter FOREIGN KEY (MeterID)
        REFERENCES EnergyMeter(MeterID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_reading_source FOREIGN KEY (SourceID)
        REFERENCES EnergySource(SourceID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE User (
    UserID       INT NOT NULL AUTO_INCREMENT,
    Name         VARCHAR(100) NOT NULL,
    Email        VARCHAR(100) NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Role         ENUM('Admin','HOD','Operator') DEFAULT 'Operator',
    CreatedAt    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (UserID),
    UNIQUE KEY uq_user_email (Email)
);

CREATE TABLE Alert (
    AlertID     INT NOT NULL AUTO_INCREMENT,
    MeterID     INT NOT NULL,
    AlertDate   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Threshold   DECIMAL(10,2) NOT NULL,
    ActualValue DECIMAL(10,2) NOT NULL,
    AlertType   VARCHAR(50) DEFAULT 'Overuse',
    PRIMARY KEY (AlertID),
    CONSTRAINT fk_alert_meter FOREIGN KEY (MeterID)
        REFERENCES EnergyMeter(MeterID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE UserBuilding (
    UserID     INT NOT NULL,
    BuildingID INT NOT NULL,
    AssignedOn DATE DEFAULT (CURRENT_DATE),
    PRIMARY KEY (UserID, BuildingID),
    CONSTRAINT fk_ub_user FOREIGN KEY (UserID)
        REFERENCES User(UserID) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ub_building FOREIGN KEY (BuildingID)
        REFERENCES Building(BuildingID) ON DELETE CASCADE ON UPDATE CASCADE
);

-- All sample data
INSERT INTO Building (BuildingName, Location, FloorCount, TotalArea) VALUES
('Main Administrative Block', 'North Campus', 4, 2500.00),
('CSE & IT Block',            'East Campus',  3, 1800.00),
('ECE & EEE Block',           'East Campus',  3, 1800.00),
('Library & Resource Centre', 'Central',      2, 1200.00),
('Sports & Gymnasium',        'South Campus', 1,  950.00);

INSERT INTO Department (DeptName, BuildingID, HeadOfDept) VALUES
('Principal Office',            1, 'Dr. R. Sharma'),
('Accounts & Finance',          1, 'Mr. K. Nair'),
('Computer Science & Engg.',    2, 'Dr. P. Rao'),
('Information Technology',      2, 'Dr. S. Mehta'),
('Electronics & Communication', 3, 'Dr. A. Iyer'),
('Electrical & Electronics',    3, 'Dr. V. Kumar'),
('Digital Library',             4, 'Ms. T. Reddy'),
('Physical Education',          5, 'Mr. D. Singh');

INSERT INTO EnergySource (SourceType, UnitCostPerKWh, Description) VALUES
('Grid Electricity', 7.5000, 'Main BESCOM grid supply'),
('Solar Panel',      0.5000, 'Rooftop solar installation'),
('Diesel Generator', 18.000, 'Backup DG set for outages');

INSERT INTO EnergyMeter (MeterType, BuildingID, InstallationDate, Status) VALUES
('Digital',  1, '2022-06-01', 'Active'),
('Digital',  2, '2022-06-01', 'Active'),
('Digital',  3, '2022-06-01', 'Active'),
('Digital',  4, '2022-06-15', 'Active'),
('Analogue', 5, '2021-03-10', 'Active'),
('Digital',  2, '2023-01-20', 'Active');

INSERT INTO EnergyReading (MeterID, SourceID, ReadingDate, UnitsConsumed, PeakLoad) VALUES
(1, 1, '2024-01-05', 320.50, 45.20),
(1, 2, '2024-01-05',  85.00, 12.00),
(2, 1, '2024-01-05', 415.75, 60.10),
(2, 2, '2024-01-05',  95.00, 14.50),
(3, 1, '2024-01-05', 380.00, 55.00),
(4, 1, '2024-01-05', 210.30, 30.80),
(5, 1, '2024-01-05',  98.60, 18.20),
(6, 1, '2024-01-05', 200.00, 35.00),
(1, 1, '2024-02-05', 290.00, 42.00),
(2, 1, '2024-02-05', 450.00, 65.00),
(3, 3, '2024-02-05', 120.00, 25.00),
(4, 1, '2024-02-05', 195.00, 28.50),
(5, 1, '2024-02-05',  88.00, 16.00),
(6, 2, '2024-02-05', 110.00, 20.00);

INSERT INTO User (Name, Email, PasswordHash, Role) VALUES
('Admin User',   'admin@cecms.edu',  'hashed_admin_pw', 'Admin'),
('Dr. P. Rao',   'prao@cecms.edu',   'hashed_hod1_pw',  'HOD'),
('Dr. A. Iyer',  'aiyer@cecms.edu',  'hashed_hod2_pw',  'HOD'),
('Ravi Kumar',   'ravi@cecms.edu',   'hashed_op1_pw',   'Operator'),
('Sunita Patil', 'sunita@cecms.edu', 'hashed_op2_pw',   'Operator');

INSERT INTO Alert (MeterID, AlertDate, Threshold, ActualValue, AlertType) VALUES
(2, '2024-01-05 08:30:00', 400.00, 415.75, 'Overuse'),
(3, '2024-01-05 09:00:00', 350.00, 380.00, 'Overuse'),
(2, '2024-02-05 08:45:00', 400.00, 450.00, 'Overuse'),
(3, '2024-02-05 10:00:00', 100.00, 120.00, 'Overuse');

INSERT INTO UserBuilding (UserID, BuildingID, AssignedOn) VALUES
(1, 1, '2023-06-01'),
(1, 2, '2023-06-01'),
(1, 3, '2023-06-01'),
(2, 2, '2023-06-01'),
(3, 3, '2023-06-01'),
(4, 1, '2023-06-01'),
(5, 4, '2023-06-01');

SHOW TABLES;