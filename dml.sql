-- Практична робота №9. Маніпулювання даними у SQL/DML
-- База даних: college | Схема: college
-- PostgreSQL

-- Підготовка сумісності з фактичною схемою ПР №8:
-- у попередньому DDL не було таблиці students та стовпця enrollments.status.
CREATE TABLE IF NOT EXISTS college.students (
    student_id INTEGER PRIMARY KEY,
    student_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) UNIQUE
);

ALTER TABLE college.enrollments
    ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'active';

-- 1. Додавання кафедр.
INSERT INTO college.departments (code, name)
VALUES
    ('IT', 'Інформаційні технології'),
    ('FIZ', 'Фізика')
ON CONFLICT (code) DO NOTHING;

-- 2. Додавання курсів.
-- У схемі ПР №8 назва курсу зберігається у course_name,
-- а tuition_fee є обов'язковим стовпцем.
INSERT INTO college.courses
    (department_id, course_name, credits, tuition_fee)
SELECT d.department_id, v.course_name, v.credits, v.tuition_fee
FROM (VALUES
    ('IT', 'Бази даних', 4, 1200.00::NUMERIC(10,2)),
    ('IT', 'Вебтехнології', 3, 1000.00::NUMERIC(10,2)),
    ('FIZ', 'Загальна фізика', 4, 900.00::NUMERIC(10,2))
) AS v(department_code, course_name, credits, tuition_fee)
JOIN college.departments d ON d.code = v.department_code
WHERE NOT EXISTS (
    SELECT 1
    FROM college.courses c
    WHERE c.department_id = d.department_id
      AND c.course_name = v.course_name
);

-- 3. Додавання чотирьох студентів.
-- RETURNING показує додані рядки.
INSERT INTO college.students (student_id, student_name, email)
VALUES
    (101, 'Іван Петренко', 'ivan.petrenko@example.com'),
    (102, 'Олена Коваль', 'olena.koval@example.com'),
    (103, 'Андрій Шевченко', 'andrii.shevchenko@example.com'),
    (104, 'Марія Бондар', 'mariia.bondar@example.com')
ON CONFLICT (student_id) DO NOTHING
RETURNING student_id, student_name, email;

-- 4. Реєстрація студентів на курси.
-- INSERT ... SELECT знаходить course_id за назвою, не припускаючи конкретних ID.
INSERT INTO college.enrollments (student_id, course_id, status)
SELECT v.student_id, c.course_id, 'active'
FROM (VALUES
    (101, 'Бази даних'),
    (102, 'Бази даних'),
    (103, 'Вебтехнології'),
    (104, 'Вебтехнології')
) AS v(student_id, course_name)
JOIN college.courses c ON c.course_name = v.course_name
ON CONFLICT (student_id, course_id) DO NOTHING;

-- 5. П'ять базових SELECT-запитів.

-- SELECT 1. Список студентів з псевдонімами стовпців.
SELECT
    s.student_id AS "ID студента",
    s.student_name AS "ПІБ",
    s.email AS "Електронна пошта"
FROM college.students AS s
ORDER BY s.student_name;

-- SELECT 2. Курси, кафедри та кількість кредитів.
SELECT
    c.course_name AS "Назва курсу",
    d.name AS "Кафедра",
    c.credits AS "Кредити"
FROM college.courses AS c
JOIN college.departments AS d
    ON d.department_id = c.department_id
ORDER BY d.name, c.course_name;

-- SELECT 3. Обчислюваний стовпець: вартість одного кредиту.
SELECT
    c.course_name AS "Курс",
    c.tuition_fee AS "Вартість курсу",
    c.credits AS "Кредити",
    ROUND(c.tuition_fee / NULLIF(c.credits, 0), 2) AS "Вартість кредиту"
FROM college.courses AS c
ORDER BY "Вартість кредиту" DESC;

-- SELECT 4. Реєстрації студентів на курси.
SELECT
    s.student_name AS "Студент",
    c.course_name AS "Курс",
    e.enrollment_date AS "Дата реєстрації",
    e.status AS "Статус"
FROM college.enrollments AS e
JOIN college.students AS s ON s.student_id = e.student_id
JOIN college.courses AS c ON c.course_id = e.course_id
ORDER BY e.enrollment_date DESC, s.student_name;

-- SELECT 5. Кількість зареєстрованих студентів на кожному курсі.
SELECT
    c.course_name AS "Курс",
    COUNT(e.student_id) AS "Кількість студентів"
FROM college.courses AS c
LEFT JOIN college.enrollments AS e ON e.course_id = c.course_id
GROUP BY c.course_id, c.course_name
ORDER BY "Кількість студентів" DESC, c.course_name;

-- 6. Безпечне оновлення: перегляд рядка ДО UPDATE.
SELECT
    student_id, course_id, enrollment_date, status
FROM college.enrollments
WHERE student_id = 101
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Бази даних'
      ORDER BY course_id
      LIMIT 1
  );

-- UPDATE змінює тільки реєстрацію студента 101 на курс "Бази даних".
UPDATE college.enrollments
SET status = 'completed'
WHERE student_id = 101
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Бази даних'
      ORDER BY course_id
      LIMIT 1
  );

-- Перегляд рядка ПІСЛЯ UPDATE.
SELECT
    student_id, course_id, enrollment_date, status
FROM college.enrollments
WHERE student_id = 101
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Бази даних'
      ORDER BY course_id
      LIMIT 1
  );

-- 7. Видалення однієї реєстрації студента 104 на курс "Вебтехнології".
-- Перед DELETE перевіряємо рядок, який буде видалено.
SELECT
    student_id, course_id, enrollment_date, status
FROM college.enrollments
WHERE student_id = 104
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Вебтехнології'
      ORDER BY course_id
      LIMIT 1
  );

DELETE FROM college.enrollments
WHERE student_id = 104
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Вебтехнології'
      ORDER BY course_id
      LIMIT 1
  );

-- Перевірка після DELETE: запит має повернути 0 рядків.
SELECT
    student_id, course_id, enrollment_date, status
FROM college.enrollments
WHERE student_id = 104
  AND course_id = (
      SELECT course_id
      FROM college.courses
      WHERE course_name = 'Вебтехнології'
      ORDER BY course_id
      LIMIT 1
  );

-- Кінець практичної роботи №9.
