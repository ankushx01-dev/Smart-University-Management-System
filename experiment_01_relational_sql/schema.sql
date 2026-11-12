-- Experiment 1: create the SUMS relational schema with MySQL 8.0 syntax.
-- Run this file before insert_data.sql. It preserves existing rows and tables.

CREATE DATABASE IF NOT EXISTS SUMS
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE SUMS;

CREATE TABLE IF NOT EXISTS Campuses (
    Campus_ID SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    Campus_Name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_campuses PRIMARY KEY (Campus_ID),
    CONSTRAINT uq_campuses_name UNIQUE (Campus_Name)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS Departments (
    Department_ID SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    Department_Name VARCHAR(100) NOT NULL,
    CONSTRAINT pk_departments PRIMARY KEY (Department_ID),
    CONSTRAINT uq_departments_name UNIQUE (Department_Name)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS Students (
    Student_ID INT UNSIGNED NOT NULL AUTO_INCREMENT,
    Name VARCHAR(120) NOT NULL,
    Email VARCHAR(254) NOT NULL,
    Department_ID SMALLINT UNSIGNED NOT NULL,
    Campus_ID SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT pk_students PRIMARY KEY (Student_ID),
    CONSTRAINT uq_students_email UNIQUE (Email),
    CONSTRAINT fk_students_department
        FOREIGN KEY (Department_ID) REFERENCES Departments (Department_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_students_campus
        FOREIGN KEY (Campus_ID) REFERENCES Campuses (Campus_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS Courses (
    Course_ID SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    Course_Name VARCHAR(150) NOT NULL,
    Credits TINYINT UNSIGNED NOT NULL,
    Department_ID SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT pk_courses PRIMARY KEY (Course_ID),
    CONSTRAINT uq_courses_name UNIQUE (Course_Name),
    CONSTRAINT chk_courses_credits CHECK (Credits BETWEEN 1 AND 6),
    CONSTRAINT fk_courses_department
        FOREIGN KEY (Department_ID) REFERENCES Departments (Department_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS Professors (
    Professor_ID SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    Name VARCHAR(120) NOT NULL,
    Department_ID SMALLINT UNSIGNED NOT NULL,
    Campus_ID SMALLINT UNSIGNED NOT NULL,
    CONSTRAINT pk_professors PRIMARY KEY (Professor_ID),
    CONSTRAINT fk_professors_department
        FOREIGN KEY (Department_ID) REFERENCES Departments (Department_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_professors_campus
        FOREIGN KEY (Campus_ID) REFERENCES Campuses (Campus_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS Enrollments (
    Enrollment_ID INT UNSIGNED NOT NULL AUTO_INCREMENT,
    Student_ID INT UNSIGNED NOT NULL,
    Course_ID SMALLINT UNSIGNED NOT NULL,
    Semester VARCHAR(20) NOT NULL,
    Grade VARCHAR(2) NOT NULL,
    CONSTRAINT pk_enrollments PRIMARY KEY (Enrollment_ID),
    CONSTRAINT uq_enrollment_student_course_semester
        UNIQUE (Student_ID, Course_ID, Semester),
    CONSTRAINT chk_enrollments_grade
        CHECK (Grade IN ('A+', 'A', 'A-', 'B+', 'B', 'B-', 'C+', 'C', 'D', 'F', 'IP')),
    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (Student_ID) REFERENCES Students (Student_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (Course_ID) REFERENCES Courses (Course_ID)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

-- Verify that the six expected tables now exist in SUMS.
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'SUMS'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
