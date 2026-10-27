CREATE DATABASE IF NOT EXISTS catalog_db;
CREATE USER IF NOT EXISTS 'catalog_user'@'localhost' IDENTIFIED BY 'Lokesh@312';
CREATE USER IF NOT EXISTS 'catalog_user'@'127.0.0.1' IDENTIFIED BY 'Lokesh@312';
-- reset the password in case the user already existed with a different one
ALTER USER 'catalog_user'@'localhost' IDENTIFIED BY 'Lokesh@312';
ALTER USER 'catalog_user'@'127.0.0.1' IDENTIFIED BY 'Lokesh@312';
GRANT ALL ON catalog_db.* TO 'catalog_user'@'localhost';
GRANT ALL ON catalog_db.* TO 'catalog_user'@'127.0.0.1';
FLUSH PRIVILEGES;
