-- ============================================================================
-- ONLINE BOOKSTORE MANAGEMENT SYSTEM (PL/SQL)
-- File: 03_user_pkg.sql
-- Description: User Management Package (Registration, Authentication, Profile)
-- ============================================================================

CREATE OR REPLACE PACKAGE USER_MGMT_PKG AS
    -- Hash helper function
    FUNCTION hash_password(p_password IN VARCHAR2, p_salt IN VARCHAR2) RETURN VARCHAR2;

    -- Register a new customer or admin
    PROCEDURE register_user(
        p_full_name       IN  VARCHAR2,
        p_email           IN  VARCHAR2,
        p_password        IN  VARCHAR2,
        p_phone           IN  VARCHAR2,
        p_shipping_address IN VARCHAR2,
        p_role_name       IN  VARCHAR2 DEFAULT 'CUSTOMER',
        o_user_id         OUT NUMBER,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    );

    -- Authenticate login credentials
    PROCEDURE authenticate_user(
        p_email           IN  VARCHAR2,
        p_password        IN  VARCHAR2,
        o_user_id         OUT NUMBER,
        o_full_name       OUT VARCHAR2,
        o_role_name       OUT VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    );

    -- Update user profile information
    PROCEDURE update_profile(
        p_user_id         IN  NUMBER,
        p_full_name       IN  VARCHAR2,
        p_phone           IN  VARCHAR2,
        p_shipping_address IN VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    );

    -- Change password
    PROCEDURE change_password(
        p_user_id         IN  NUMBER,
        p_old_password    IN  VARCHAR2,
        p_new_password    IN  VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    );

    -- Get user profile cursor
    PROCEDURE get_profile(
        p_user_id         IN  NUMBER,
        o_cursor          OUT SYS_REFCURSOR
    );
END USER_MGMT_PKG;
/

CREATE OR REPLACE PACKAGE BODY USER_MGMT_PKG AS

    -- Function to generate deterministic hash with salt
    FUNCTION hash_password(p_password IN VARCHAR2, p_salt IN VARCHAR2) RETURN VARCHAR2 IS
        v_raw_input RAW(500);
        v_hash      VARCHAR2(256);
    BEGIN
        v_raw_input := UTL_RAW.CAST_TO_RAW(p_password || '@BOOKSTORE#' || p_salt);
        -- Generate standard hex representation
        BEGIN
            EXECUTE IMMEDIATE 'SELECT STANDARD.HASH(:1, ''SHA256'') FROM DUAL' INTO v_hash USING v_raw_input;
        EXCEPTION
            WHEN OTHERS THEN
                -- Fallback to standard raw hex digest
                v_hash := RAWTOHEX(v_raw_input);
        END;
        RETURN v_hash;
    END hash_password;

    -- Register a new user
    PROCEDURE register_user(
        p_full_name       IN  VARCHAR2,
        p_email           IN  VARCHAR2,
        p_password        IN  VARCHAR2,
        p_phone           IN  VARCHAR2,
        p_shipping_address IN VARCHAR2,
        p_role_name       IN  VARCHAR2 DEFAULT 'CUSTOMER',
        o_user_id         OUT NUMBER,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    ) IS
        v_role_id      NUMBER;
        v_existing_cnt NUMBER;
        v_salt         VARCHAR2(64);
        v_hashed_pwd   VARCHAR2(256);
    BEGIN
        -- 1. Validate inputs
        IF p_full_name IS NULL OR p_email IS NULL OR p_password IS NULL THEN
            o_status := 'ERROR';
            o_message := 'Name, email, and password are required fields.';
            RETURN;
        END IF;

        IF LENGTH(p_password) < 6 THEN
            o_status := 'ERROR';
            o_message := 'Password must be at least 6 characters long.';
            RETURN;
        END IF;

        -- 2. Check duplicate email
        SELECT COUNT(*) INTO v_existing_cnt FROM USERS WHERE LOWER(email) = LOWER(p_email);
        IF v_existing_cnt > 0 THEN
            o_status := 'ERROR';
            o_message := 'An account with email ' || p_email || ' already exists.';
            RETURN;
        END IF;

        -- 3. Lookup role_id
        BEGIN
            SELECT role_id INTO v_role_id FROM ROLES WHERE UPPER(role_name) = UPPER(p_role_name);
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Default to CUSTOMER role (id 2)
                v_role_id := 2;
        END;

        -- 4. Generate salt and hash password
        v_salt := SUBSTR(RAWTOHEX(SYS_GUID()), 1, 32);
        v_hashed_pwd := hash_password(p_password, v_salt);

        -- 5. Insert user record
        o_user_id := USER_SEQ.NEXTVAL;
        INSERT INTO USERS (
            user_id, role_id, full_name, email, password_hash, salt, phone, shipping_address, status, created_at, updated_at
        ) VALUES (
            o_user_id, v_role_id, p_full_name, LOWER(p_email), v_hashed_pwd, v_salt, p_phone, p_shipping_address, 'ACTIVE', SYSDATE, SYSDATE
        );

        -- 6. Audit Registration
        INSERT INTO AUDIT_LOGS (log_id, action_type, table_name, record_id, performed_by, action_time, details)
        VALUES (AUDIT_SEQ.NEXTVAL, 'REGISTER', 'USERS', TO_CHAR(o_user_id), p_email, SYSDATE, 'User registered with role: ' || p_role_name);

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'User registered successfully.';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Registration failed: ' || SQLERRM;
    END register_user;

    -- Authenticate user login
    PROCEDURE authenticate_user(
        p_email           IN  VARCHAR2,
        p_password        IN  VARCHAR2,
        o_user_id         OUT NUMBER,
        o_full_name       OUT VARCHAR2,
        o_role_name       OUT VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    ) IS
        v_user_id     NUMBER;
        v_full_name   VARCHAR2(100);
        v_db_hash     VARCHAR2(256);
        v_salt        VARCHAR2(64);
        v_status      VARCHAR2(20);
        v_role_name   VARCHAR2(30);
        v_calc_hash   VARCHAR2(256);
    BEGIN
        SELECT u.user_id, u.full_name, u.password_hash, u.salt, u.status, r.role_name
        INTO v_user_id, v_full_name, v_db_hash, v_salt, v_status, v_role_name
        FROM USERS u
        JOIN ROLES r ON u.role_id = r.role_id
        WHERE LOWER(u.email) = LOWER(p_email);

        IF v_status != 'ACTIVE' THEN
            o_status := 'ERROR';
            o_message := 'Account is ' || v_status || '. Please contact administrator.';
            RETURN;
        END IF;

        v_calc_hash := hash_password(p_password, v_salt);
        IF v_calc_hash = v_db_hash THEN
            o_user_id := v_user_id;
            o_full_name := v_full_name;
            o_role_name := v_role_name;
            o_status := 'SUCCESS';
            o_message := 'Authentication successful.';
            
            -- Audit login
            INSERT INTO AUDIT_LOGS (log_id, action_type, table_name, record_id, performed_by, action_time, details)
            VALUES (AUDIT_SEQ.NEXTVAL, 'LOGIN', 'USERS', TO_CHAR(v_user_id), p_email, SYSDATE, 'User logged in successfully.');
            COMMIT;
        ELSE
            o_status := 'ERROR';
            o_message := 'Invalid email or password.';
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'No account found with this email.';
        WHEN OTHERS THEN
            o_status := 'ERROR';
            o_message := 'Login error: ' || SQLERRM;
    END authenticate_user;

    -- Update profile
    PROCEDURE update_profile(
        p_user_id         IN  NUMBER,
        p_full_name       IN  VARCHAR2,
        p_phone           IN  VARCHAR2,
        p_shipping_address IN VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    ) IS
    BEGIN
        UPDATE USERS
        SET full_name = NVL(p_full_name, full_name),
            phone = NVL(p_phone, phone),
            shipping_address = NVL(p_shipping_address, shipping_address),
            updated_at = SYSDATE
        WHERE user_id = p_user_id;

        IF SQL%ROWCOUNT > 0 THEN
            COMMIT;
            o_status := 'SUCCESS';
            o_message := 'Profile updated successfully.';
        ELSE
            o_status := 'ERROR';
            o_message := 'User ID not found.';
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Profile update failed: ' || SQLERRM;
    END update_profile;

    -- Change password
    PROCEDURE change_password(
        p_user_id         IN  NUMBER,
        p_old_password    IN  VARCHAR2,
        p_new_password    IN  VARCHAR2,
        o_status          OUT VARCHAR2,
        o_message         OUT VARCHAR2
    ) IS
        v_salt      VARCHAR2(64);
        v_db_hash   VARCHAR2(256);
        v_new_salt  VARCHAR2(64);
        v_new_hash  VARCHAR2(256);
    BEGIN
        IF LENGTH(p_new_password) < 6 THEN
            o_status := 'ERROR';
            o_message := 'New password must be at least 6 characters.';
            RETURN;
        END IF;

        SELECT salt, password_hash INTO v_salt, v_db_hash
        FROM USERS WHERE user_id = p_user_id;

        IF hash_password(p_old_password, v_salt) != v_db_hash THEN
            o_status := 'ERROR';
            o_message := 'Current password does not match.';
            RETURN;
        END IF;

        v_new_salt := SUBSTR(RAWTOHEX(SYS_GUID()), 1, 32);
        v_new_hash := hash_password(p_new_password, v_new_salt);

        UPDATE USERS
        SET password_hash = v_new_hash,
            salt = v_new_salt,
            updated_at = SYSDATE
        WHERE user_id = p_user_id;

        COMMIT;
        o_status := 'SUCCESS';
        o_message := 'Password changed successfully.';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            o_status := 'ERROR';
            o_message := 'User not found.';
        WHEN OTHERS THEN
            ROLLBACK;
            o_status := 'ERROR';
            o_message := 'Password change failed: ' || SQLERRM;
    END change_password;

    -- Get profile
    PROCEDURE get_profile(
        p_user_id IN NUMBER,
        o_cursor  OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN o_cursor FOR
            SELECT u.user_id, u.full_name, u.email, u.phone, u.shipping_address, 
                   u.status, u.created_at, r.role_name
            FROM USERS u
            JOIN ROLES r ON u.role_id = r.role_id
            WHERE u.user_id = p_user_id;
    END get_profile;

END USER_MGMT_PKG;
/

PROMPT User Management Package Created Successfully.
