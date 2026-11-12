-- Experiment 1: insert ten synthetic records into each relational table.
-- The upserts make this seed file safe to run again without duplicate rows.

USE SUMS;

INSERT INTO Campuses (Campus_ID, Campus_Name) VALUES
    (1, 'North Campus'),
    (2, 'South Campus'),
    (3, 'East Campus'),
    (4, 'West Campus'),
    (5, 'Central Campus'),
    (6, 'Research Campus'),
    (7, 'Medical Campus'),
    (8, 'Technology Campus'),
    (9, 'Arts Campus'),
    (10, 'Online Campus')
ON DUPLICATE KEY UPDATE Campus_Name = VALUES(Campus_Name);

INSERT INTO Departments (Department_ID, Department_Name) VALUES
    (1, 'Computer Science'),
    (2, 'Mathematics'),
    (3, 'Physics'),
    (4, 'Biological Sciences'),
    (5, 'Chemistry'),
    (6, 'Economics'),
    (7, 'English'),
    (8, 'History'),
    (9, 'Electrical Engineering'),
    (10, 'Business Administration')
ON DUPLICATE KEY UPDATE Department_Name = VALUES(Department_Name);

INSERT INTO Students (Student_ID, Name, Email, Department_ID, Campus_ID) VALUES
    (1, 'Aarav Mehta', 'aarav.mehta01@sums.example.edu', 1, 1),
    (2, 'Diya Sharma', 'diya.sharma02@sums.example.edu', 2, 2),
    (3, 'Kabir Rao', 'kabir.rao03@sums.example.edu', 3, 3),
    (4, 'Anaya Iyer', 'anaya.iyer04@sums.example.edu', 4, 4),
    (5, 'Arjun Patel', 'arjun.patel05@sums.example.edu', 5, 5),
    (6, 'Meera Nair', 'meera.nair06@sums.example.edu', 6, 6),
    (7, 'Rohan Das', 'rohan.das07@sums.example.edu', 7, 7),
    (8, 'Sana Khan', 'sana.khan08@sums.example.edu', 8, 8),
    (9, 'Vikram Bose', 'vikram.bose09@sums.example.edu', 9, 9),
    (10, 'Tara Sen', 'tara.sen10@sums.example.edu', 10, 10)
ON DUPLICATE KEY UPDATE
    Name = VALUES(Name),
    Email = VALUES(Email),
    Department_ID = VALUES(Department_ID),
    Campus_ID = VALUES(Campus_ID);

INSERT INTO Courses (Course_ID, Course_Name, Credits, Department_ID) VALUES
    (1, 'Introduction to Python', 4, 1),
    (2, 'Linear Algebra', 3, 2),
    (3, 'General Physics', 4, 3),
    (4, 'Cell Biology', 3, 4),
    (5, 'Organic Chemistry', 4, 5),
    (6, 'Microeconomics', 3, 6),
    (7, 'Academic Writing', 2, 7),
    (8, 'World History', 3, 8),
    (9, 'Electrical Circuits', 4, 9),
    (10, 'Principles of Management', 3, 10)
ON DUPLICATE KEY UPDATE
    Course_Name = VALUES(Course_Name),
    Credits = VALUES(Credits),
    Department_ID = VALUES(Department_ID);

INSERT INTO Professors (Professor_ID, Name, Department_ID, Campus_ID) VALUES
    (1, 'Dr. Leena Kapoor', 1, 1),
    (2, 'Dr. Mohan Kulkarni', 2, 2),
    (3, 'Dr. Farah Qureshi', 3, 3),
    (4, 'Dr. Nikhil Menon', 4, 4),
    (5, 'Dr. Kavita Rao', 5, 5),
    (6, 'Dr. Sameer Joshi', 6, 6),
    (7, 'Dr. Pooja Sen', 7, 7),
    (8, 'Dr. Imran Ali', 8, 8),
    (9, 'Dr. Neha Bose', 9, 9),
    (10, 'Dr. Dev Malhotra', 10, 10)
ON DUPLICATE KEY UPDATE
    Name = VALUES(Name),
    Department_ID = VALUES(Department_ID),
    Campus_ID = VALUES(Campus_ID);

INSERT INTO Enrollments
    (Enrollment_ID, Student_ID, Course_ID, Semester, Grade) VALUES
    (1, 1, 1, '2026-Fall', 'A'),
    (2, 2, 2, '2026-Fall', 'A-'),
    (3, 3, 3, '2026-Fall', 'B+'),
    (4, 4, 4, '2026-Fall', 'B'),
    (5, 5, 5, '2026-Fall', 'A'),
    (6, 6, 6, '2026-Fall', 'B+'),
    (7, 7, 7, '2026-Fall', 'A-'),
    (8, 8, 8, '2026-Fall', 'B'),
    (9, 1, 2, '2026-Fall', 'A'),
    (10, 2, 1, '2026-Fall', 'B+')
ON DUPLICATE KEY UPDATE
    Student_ID = VALUES(Student_ID),
    Course_ID = VALUES(Course_ID),
    Semester = VALUES(Semester),
    Grade = VALUES(Grade);

-- Verify seeded row counts. On a fresh SUMS database, every table reports 10.
SELECT 'Campuses' AS Table_Name, COUNT(*) AS Record_Count FROM Campuses
UNION ALL
SELECT 'Departments', COUNT(*) FROM Departments
UNION ALL
SELECT 'Students', COUNT(*) FROM Students
UNION ALL
SELECT 'Courses', COUNT(*) FROM Courses
UNION ALL
SELECT 'Professors', COUNT(*) FROM Professors
UNION ALL
SELECT 'Enrollments', COUNT(*) FROM Enrollments
ORDER BY Table_Name;

-- Verify there are no student rows whose department or campus is missing.
SELECT
    (SELECT COUNT(*)
     FROM Students AS s
     LEFT JOIN Departments AS d ON d.Department_ID = s.Department_ID
     WHERE d.Department_ID IS NULL) AS Students_Without_Department,
    (SELECT COUNT(*)
     FROM Students AS s
     LEFT JOIN Campuses AS c ON c.Campus_ID = s.Campus_ID
     WHERE c.Campus_ID IS NULL) AS Students_Without_Campus;
