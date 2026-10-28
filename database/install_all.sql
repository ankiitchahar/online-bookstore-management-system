-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- Master Execution Script: install_all.sql
-- Usage: In SQL*Plus, SQL Developer, or Oracle LiveSQL:
--        @install_all.sql
-- ============================================================================

PROMPT ====================================================================
PROMPT STARTING ONLINE BOOKSTORE SYSTEM INSTALLATION
PROMPT ====================================================================

SET ECHO OFF
SET FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT 1. Executing Schema Setup (Tables, Constraints, Indexes, Sequences)...
@@01_schema.sql

PROMPT 2. Creating Database Triggers...
@@02_triggers.sql

PROMPT 3. Creating User Management Package...
@@03_user_pkg.sql

PROMPT 4. Creating Book Management Package...
@@04_book_pkg.sql

PROMPT 5. Creating Shopping Cart Package...
@@05_cart_pkg.sql

PROMPT 6. Creating Order Management Package...
@@06_order_pkg.sql

PROMPT 7. Creating Analytical Reporting Package...
@@07_reporting_pkg.sql

PROMPT 8. Seeding Sample Roles, Categories, Books, and Initial Orders...
@@08_sample_data.sql

PROMPT 9. Running Verification Test Suite...
@@09_test_suite.sql

PROMPT ====================================================================
PROMPT ONLINE BOOKSTORE SYSTEM INSTALLATION COMPLETED SUCCESSFULLY!
PROMPT ====================================================================
