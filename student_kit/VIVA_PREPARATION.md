# 🎓 PL/SQL Mini Project: Complete Viva Preparation Guide

Yeh guide specially **college viva, oral examination aur lab evaluation** ke liye banayi gayi hai.
Isme **PL/SQL ke core concepts**, aapke **project ka code flow**, aur **examiner ke favorite questions + unke exact answers** diye gaye hain.

---

## 🌟 PART 1: Project Ka Quick 2-Minute Explanation (Viva Opening)

Examiner jab bolega: *"Tell me about your project"* ya *"Explain what you have built"*, toh yeh bolna hai:

> **English Answer:**  
> *"Good morning Sir/Madam. My project is an 'Online Bookstore Management System' developed using Oracle PL/SQL. The main objective of this project is to manage book inventory, user registration, shopping cart operations, and atomic order processing on the database level. I have implemented core PL/SQL concepts including Stored Procedures, Functions, Cursors, Triggers, and Exception Handling to ensure data integrity and ACID compliance."*

> **Hinglish Samajhne Ke Liye:**  
> Humne ek Online Bookstore banaya hai jisme user register kar sakta hai, books browse kar sakta hai, cart me add kar sakta hai aur order place kar sakta hai. Iska poora business logic humne **Oracle Database ke andar PL/SQL (Procedures, Functions, Triggers, Cursors)** ke through implement kiya hai taaki stock management aur transactions 100% accurate rahein.

---

## 📚 PART 2: Core PL/SQL Concepts (Jo Examiner 100% Puchega)

### 1. PL/SQL Kya Hota Hai? (SQL vs PL/SQL)
* **SQL:** Declarative language hai (hum batate hain *kya chahiye*, par *kaise karna hai* yeh nahi batate). Isme loops ya if-else nahi hota.
* **PL/SQL (Procedural Language / SQL):** Oracle ka extension hai jo SQL ke sath **Programming constructs** (like `IF-THEN-ELSE`, `FOR/WHILE Loops`, `Variables`, `Exceptions`) allow karta hai.
* **Advantage:** SQL me har query alag se server pe jaati hai (network traffic badhta hai). PL/SQL me **poora block ek saath database server pe execute hota hai**, jisse speed bohot fast ho jaati hai.

---

### 2. Stored Procedure vs Function (Examiner Ka Favorite!)

| Feature | Stored Procedure | Stored Function |
| :--- | :--- | :--- |
| **Return Value** | Value return karna compulsory nahi hai (0 ya multiple OUT parameters de sakta hai). | **Hamesha exactly 1 value RETURN karni padti hai** (`RETURN data_type`). |
| **SQL Query Me Use** | SQL `SELECT` statement ke andar direct call nahi ho sakta. | `SELECT` statement me direct call ho sakta hai (e.g. `SELECT get_cart_total(1) FROM DUAL;`). |
| **Primary Purpose** | Business action/process perform karna (e.g., `place_order`, `register_user`). | Calculation ya check perform karke result dena (e.g., `check_book_stock`, `get_cart_total`). |

**Aapke Project Me Example:**
* **Procedure:** `place_order(p_user_id)` ➔ Order insert karta hai, stock ghatata hai, cart clear karta hai.
* **Function:** `check_book_stock(book_id, qty)` ➔ Check karta hai aur `TRUE` ya `FALSE` return karta hai.

---

### 3. Cursor Kya Hota Hai? (Implicit vs Explicit)
* **Definition:** Cursor database ka ek **private memory area (work area)** hota hai jisme multi-row SQL query ka result store hota hai.
* **Implicit Cursor:** Oracle khud banata hai jab aap simple `INSERT`, `UPDATE`, `DELETE` ya single-row `SELECT` chalate ho (attributes: `SQL%FOUND`, `SQL%ROWCOUNT`).
* **Explicit Cursor:** Programmer khud declare karta hai jab query se **multiple rows** ek-ek karke process karni ho.

**Cursor Ke 4 Steps:**
1. `DECLARE` ➔ Cursor ka naam aur query define karna.
2. `OPEN` ➔ Query execute hoti hai aur memory allocate hoti hai.
3. `FETCH` ➔ Ek-ek row ko memory se fetch karke variables me daalna.
4. `CLOSE` ➔ Memory release karna.

**Aapke Project Me Kahan Use Hua?**
* [`display_all_books`](file:///c:/Rishabh%20Shakya/pl,sql/mini_project/student_kit/bookstore_student.sql#L206-L230): Saari books ek-ek karke fetch karke display karne ke liye cursor loop use kiya hai.
* [`place_order`](file:///c:/Rishabh%20Shakya/pl,sql/mini_project/student_kit/bookstore_student.sql#L154-L203): Cart ke har book ko padh kar `ORDER_ITEMS` me daalne aur stock deduct karne ke liye `c_cart` cursor use kiya hai.

---

### 4. Trigger Kya Hota Hai?
* **Definition:** Trigger ek special stored program hota hai jo database me kisi **event (INSERT, UPDATE, DELETE)** ke hone par **automatically FIRE (execute)** hota hai. Isko manually call nahi karna padta.
* **Row-Level Trigger:** `FOR EACH ROW` lagane se har row ke change hone par chalta hai. Isme `:OLD` aur `:NEW` values milti hain.

**Aapke Project Ke 2 Triggers:**
1. **`trg_check_stock` (BEFORE INSERT OR UPDATE ON BOOKS):**
   * *Kaam:* Check karta hai ki stock kabhi negative ($< 0$) na ho. Agar koi stock $-1$ karne ki koshish kare, toh `RAISE_APPLICATION_ERROR` fekta hai.
2. **`trg_restore_stock_on_cancel` (AFTER UPDATE ON ORDERS):**
   * *Kaam:* Jaise hi order ka status `'CANCELLED'` hota hai, yeh trigger automatically `ORDER_ITEMS` se book aur quantity nikal kar `BOOKS` table me stock wapas add (+ quantity) kar deta hai!

---

### 5. Exception Handling Kya Hai?
* **Definition:** Run-time errors ko gracefully handle karna taaki program crash na ho.
* **Predefined Exceptions:**
  * `NO_DATA_FOUND`: Jab query koi row nahi laati.
  * `DUP_VAL_ON_INDEX`: Unique constraint violate hone par (jaise same email se 2 baar register karna).
  * `OTHERS`: Baaki saare unhandled errors ke liye.
* **User-Defined Exception / RAISE_APPLICATION_ERROR:**
  * Oracle me `-20000` se `-20999` tak custom error codes hote hain (jaise humne negative stock par `-20001` use kiya).

---

### 6. Transactions aur ACID Properties
* **Commit:** Data ko permanently save karna.
* **Rollback:** Agar order place karte waqt koi error aaye, toh saari changes wapas undo kar dena (taaki adha-adhura order na ban jaye).
* **Atomic Transaction:** `place_order` me agar kisi book ka stock kam pad gaya, toh poora order rollback ho jata hai, paise nahi katte aur cart waise hi rehti hai.

---

## 🎯 PART 3: Top 15 Viva Questions with Direct Answers

#### Q1. What is the execution block structure of PL/SQL?
> **Answer:** PL/SQL block has 3 main sections:
> 1. `DECLARE` (Optional) - Variables, cursors, constants declare karne ke liye.
> 2. `BEGIN` (Mandatory) - Executable SQL aur procedural statements likhne ke liye.
> 3. `EXCEPTION` (Optional) - Errors handle karne ke liye.
> 4. `END;` (Mandatory) - Block khatam karne ke liye.

#### Q2. What are `:OLD` and `:NEW` qualifiers in Triggers?
> **Answer:** Row-level triggers me `:OLD` update/delete se pehle ki purani value batata hai, aur `:NEW` insert/update ke baad ki nayi value batata hai. Jaise humne check kiya: `IF :NEW.order_status = 'CANCELLED' AND :OLD.order_status != 'CANCELLED'`.

#### Q3. Why did you use Sequences in your tables?
> **Answer:** Primary keys (jaise `user_id`, `book_id`, `order_id`) ko auto-increment unique numbers dene ke liye humne `CREATE SEQUENCE` aur `NEXTVAL` use kiya hai.

#### Q4. What happens when an order is cancelled in your system?
> **Answer:** Humara database trigger `trg_restore_stock_on_cancel` automatically fire hota hai. Woh `ORDER_ITEMS` table se ordered quantity nikal kar `BOOKS` table ke stock me wapas add kar deta hai.

#### Q5. Can a function perform DML (INSERT/UPDATE/DELETE) in SQL statements?
> **Answer:** Agar function `SELECT` query ke andar call ho raha hai, toh woh database me DML (insert/update) nahi kar sakta (read-only purity rule). Isliye humne calculation ke liye Function banaya aur DML operations ke liye Procedure banaya.

#### Q6. What is `SET SERVEROUTPUT ON`?
> **Answer:** Yeh SQL*Plus aur SQL Developer ka environment command hai jo `DBMS_OUTPUT.PUT_LINE` ke output ko screen par print karne ke liye buffer enable karta hai.

#### Q7. What is `RAISE_APPLICATION_ERROR`?
> **Answer:** Yeh Oracle ka built-in procedure hai jo custom error messages throw karta hai (error numbers between -20000 and -20999).

#### Q8. What is the difference between `%TYPE` and `%ROWTYPE`?
> **Answer:**
> * `%TYPE`: Kisi single column ka data type copy karta hai (e.g., `v_price BOOKS.price%TYPE`).
> * `%ROWTYPE`: Ek poori table ya cursor ke structure ka complete record create karta hai (e.g., `v_rec book_cur%ROWTYPE`).

#### Q9. How do you prevent duplicate user registrations?
> **Answer:** `USERS` table me `email` column par `UNIQUE` constraint lagaya hai. Agar duplicate email aati hai, toh PL/SQL me `DUP_VAL_ON_INDEX` exception handle hota hai.

#### Q10. What is an IN, OUT, and IN OUT parameter in PL/SQL?
> **Answer:**
> * `IN`: Procedure ko input value deta hai (read-only).
> * `OUT`: Procedure se result bahar caller ko wapas deta hai.
> * `IN OUT`: Value input bhi leta hai aur modify karke wapas bhi deta hai.

---

## 📋 PART 4: Tables Summary Table (Viva Cheat-Sheet)

| Table Name | Primary Key | Foreign Key | Purpose |
| :--- | :--- | :--- | :--- |
| **`USERS`** | `user_id` | - | Customer aur Admin ka account store karta hai. |
| **`BOOKS`** | `book_id` | - | Book title, author, price, aur current stock. |
| **`CART`** | `cart_id` | `user_id`, `book_id` | User ke cart ke active items track karta hai. |
| **`ORDERS`** | `order_id` | `user_id` | Placed order header, total amount, status. |
| **`ORDER_ITEMS`** | `item_id` | `order_id`, `book_id` | Order ke andar kaunsi book kitni quantity me thi. |

Yeh sab prepare kar lo, viva me examiners isse bahar kuch nahi puchenge!
