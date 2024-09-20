# Using Relational Databases

We will see how to use popular libraries for accessing the *sqlite* and *Postgres* (sometimes also called *PostgeSQL*) databases in this chapter. I assume that you are already familiar with *SQL*.

## Database Access for Sqlite

We will use the [sqlite-simple](https://hackage.haskell.org/package/sqlite-simple) library in this section to access Sqlite databases and use the similar library [postgresql-simple](https://hackage.haskell.org/package/postgresql-simple) in the next section for use with Postgres.

There are other good libraries for database connectivity like [Persistent](https://www.stackage.org/package/persistent) but I like sqlite-simple and it has a gentle learning curve so that is what we will use here. You will learn the basics of database connectivity in this and the next section. Setting up and using *sqlite* is easy because the *sqlite-simple* library includes the compiled code for *sqlite* so configuration requires only the file path to the database file.


{lang="haskell",linenos=on}
~~~~~~~~
{-# LANGUAGE OverloadedStrings #-}

module Main where
  
import Database.SQLite.Simple

{-
   Create sqlite database:
     sqlite3 test.db "create table test (id integer primary key, str text);"

   This example is derived from the example at github.com/nurpax/sqlite-simple
-}

main :: IO ()
main = do
  conn <- open "test.db"
  -- start by getting table names in database:
  do
    r <- query_ conn
      "SELECT name FROM sqlite_master WHERE type='table'" :: IO [Only String]
    print "Table names in database test.db:"
    mapM_ (print . fromOnly) r
  
  -- get the metadata for table test in test.db:
  do
    r <- query_ conn
          "SELECT sql FROM sqlite_master WHERE type='table' and name='test'" ::
                IO [Only String]
    print "SQL to create table 'test' in database test.db:"
    mapM_ (print . fromOnly) r
  
  -- add a row to table 'test' and then print out the rows in table 'test':
  do
    execute conn "INSERT INTO test (str) VALUES (?)"
      (Only ("test string 2" :: String))
    r2 <- query_ conn "SELECT * from test" :: IO [(Int, String)]
    print "number of rows in table 'test':"
    print (length r2)
    print "rows in table 'test':"
    mapM_ print  r2
    
  close conn
~~~~~~~~

This Haskell code interacts with an SQLite database named "test.db" using the `Database.SQLite.Simple` library. 

**Functionality:**

1. **Imports `Database.SQLite.Simple`:** Includes necessary functions for working with SQLite databases.

2. **`main` Function:**
   - **Opens a connection to "test.db".**
   - **Retrieves and prints table names:**
     - Executes an SQL query to get table names from the `sqlite_master` table.
     - Prints the table names using `mapM_`.
   - **Retrieves and prints SQL to create 'test' table:**
     - Queries the `sqlite_master` table for the SQL used to create the 'test' table.
     - Prints the SQL statement.
   - **Inserts a row and prints table data:**
     - Inserts a new row with the string "test string 2" into the 'test' table.
     - Selects all rows from the 'test' table.
     - Prints the number of rows and the rows themselves.
   - **Closes the database connection.**

**Key Points:**

- Demonstrates basic database interaction using Haskell and SQLite.
- `query_` is used to execute SELECT queries, and `execute` is used for INSERT queries.
- The code assumes the existence of the "test.db" database and the "test" table with the specified schema.


The type **Only** used in line 20 acts as a container for a single value and is defined in the *simple-sqlite* library. It can also be used to pass values for queries like:


{lang="haskell",linenos=off}
~~~~~~~~
r <- query_ conn "SELECT name FROM customers where id = ?" (Only 4::Int)
~~~~~~~~

To run this example start by creating a sqlite database that is stored in the file *test.db*:

{linenos=off}
~~~~~~~~
sqlite3 test.db "create table test (id integer primary key, str text);"
~~~~~~~~

Then build and run the example:

{linenos=off}
~~~~~~~~
stack build --exec TestSqLite1
~~~~~~~~


## Database Access for Postgres

Setting up and using a database in the last section was easy because the *sqlite-simple* library includes the compiled code for *sqlite* so configuration only requires the file path the the database file. The Haskel examples for Postgres will be similar to those for Sqlite. There is some complication in setting up Postgres if you do not already have it installed and configured.

In any case, you will need to have Postgres installed and set up with a user account for yourself. When I am installing and configuring Postgres on my Linux laptop, I create a database role **markw**. You will certainly create a different role/account name  so subsitute your role name for **markw** in the following code examples.

If you are using Ubuntu you can install Postgres and create a role using:

{linenos=off}
~~~~~~~~
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib postgresql-server-dev-9.5
sudo -u postgres createuser --interactive
Enter name of role to add: markw
Shall the new role be a superuser? (y/n) y
~~~~~~~~


We will need to install postgresql-server-dev-9.5 in order to use the Haskell Postgres bindings. Note that your version of Ubuntu Linux may have a different version of the server dev package which you can find using:

{linenos=off}
~~~~~~~~
aptitude search postgresql-dev
~~~~~~~~

If you are using Mac OS X you can then install Postgres as an application which is convenient for development. A role is automatically created with the same name as your OS X "short name." You can use the "Open psql" button on the interface to open a command line shell that functions like the *psql* command on Ubuntu (or other Linux distributions).

We will need to install postgresql-server-dev-9.5 in order to use the Haskell Postgres bindings. Note that your version of Ubuntu Linux may have a different version of the server dev package which you can find using:

{linenos=off}
~~~~~~~~
aptitude search postgresql-dev
~~~~~~~~

You will then want to create a database named **haskell** and set the password for role/account **markw** to **test1** for running the example in this section:

{linenos=off}
~~~~~~~~
createdb haskell
sudo -u postgres psql
postgres=# alter user markw encrypted password 'test1';
postgres=# \q

psql -U markw haskell
psql (9.5.4)
Type "help" for help.

haskell=# create table customers (id int, name text, email text);
CREATE TABLE
haskell=#  insert into customers values (1, 'Acme Cement', 'info@acmecement.com');
INSERT 0 1
haskell=# \q
~~~~~~~~

If you are not familiar with using Postgres then take a minute to experiment with using the *psql* command line utility to connect to the database you just created and peform practice queries:

{lang="sql",linenos=off}
~~~~~~~~
markw=# \c haskell
You are now connected to database "haskell" as user "markw".
haskell=# \d
         List of relations
 Schema |   Name    | Type  | Owner 
--------+-----------+-------+-------
 public | customers | table | markw
 public | links     | table | markw
 public | products  | table | markw
(3 rows)

haskell=# select * from customers;
 id |      name       |        email        
----+-----------------+---------------------
  1 | Acme Cement     | info@acmecement.com
  2 | Biff Home Sales | info@biff.com
  3 | My Pens         | info@mypens.com
(3 rows)

haskell=# select * from products;
 id |     name      | cost 
----+---------------+------
  1 | Cement bag    |  2.5
  2 | Cheap Pen     |  1.5
  3 | Expensive Pen | 14.5
(3 rows)

haskell=# select * from links;
 id | customer_id | productid 
----+-------------+-----------
  1 |           1 |         1
  2 |           3 |         2
  3 |           3 |         3
(3 rows)

haskell=# 
~~~~~~~~

You can change default database settings using **ConnectInfo**:

{lang="haskell",linenos=off}
~~~~~~~~
ConnectInfo	 
  connectHost :: String
  connectPort :: Word16
  connectUser :: String
  connectPassword :: String
  connectDatabase :: String
~~~~~~~~

In the following example on lines 9-10 I use **defaultConnectInfo** that lets me override just some settings, leaving the rest set at default values. The code to access a database using *simple-postgresql* is similar to that in the last section, with a few API changes.

{lang="haskell",linenos=on}
~~~~~~~~
{-# LANGUAGE OverloadedStrings #-}

module Main where
  
import Database.PostgreSQL.Simple

main :: IO ()
main = do
  conn <- connect defaultConnectInfo { connectDatabase = "haskell",
                                       connectUser = "markw" }
  -- start by getting table names in database:
  do
    r <- query_ conn "SELECT name FROM customers" :: IO [(Only String)]
    print "names and emails in table 'customers' in database haskell:"
    mapM_ (print . fromOnly) r
  
  -- add a row to table 'test' and then print out the rows in table 'test':
  do
    let rows :: [(Int, String, String)]
        rows = [(4, "Mary Smith", "marys@acme.com")]
    executeMany conn
      "INSERT INTO customers (id, name, email) VALUES (?,?,?)" rows
    r2 <- query_ conn "SELECT * from customers" :: IO [(Int, String, String)]
    print "number of rows in table 'customers':"
    print (length r2)
    print "rows in table 'customers':"
    mapM_ print  r2
    
  close conn
~~~~~~~~


Certainly, let's break down the provided Haskell code and generate its Markdown description.

**Markdown Description**

**Functionality**

This Haskell code interacts with a PostgreSQL database named "haskell". It utilizes the `Database.PostgreSQL.Simple` library to establish a connection, retrieve and insert data into a "customers" table.

**Code Breakdown**

1. **Import `Database.PostgreSQL.Simple`**:  Imports necessary functions for working with PostgreSQL databases.

2. **`main` Function**:
   * **Establishes a connection**: 
     - Connects to the "haskell" database using the default connection information.
     - The connection specifies the username as "markw".

   * **Retrieves and prints data from the "customers" table**:
     - Executes an SQL query to fetch names from the "customers" table.
     - Prints the retrieved names.

   * **Inserts a row and prints table data**:
     - Prepares a list of tuples `rows` representing the new data to be inserted.
     - Executes an SQL INSERT query to add the new row to the "customers" table.
     - Selects all rows from the "customers" table.
     - Prints the number of rows and the rows themselves.

   * **Closes the database connection**: 
     - Terminates the established connection.

**Key Points**

- The code assumes a "customers" table with columns: `id` (integer), `name` (string), and `email` (string).
- `query_` is used for SELECT queries, and `executeMany` is used for bulk INSERT queries.
- The code provides a basic illustration of database interaction in Haskell using the `Database.PostgreSQL.Simple` library.


The type **Only** used in line 20 acts as a container for a single value and is defined in the *simple-postgresql* library. It can also be used to pass values for queries like:

{lang="haskell",linenos=off}
~~~~~~~~
r <- query_ conn "SELECT name FROM customers where id = ?" (Only 4::Int)
~~~~~~~~

The monad mapping function **mapM\_** using in line 22 is like **mapM** but is used when we do not need the resulting collection from executing the map operation. **mapM\_** is used for side effects, in this case extracting the value for a collection of **Only** values and printing them. I removed some output from building the example in the following listing:

{lang="haskell",linenos=off}
~~~~~~~~
$ Database-postgres git:(master) > stack build --exec TestPostgres1
TestDatabase-0.1.0.0: build
Preprocessing executable 'TestPostgres1' for TestDatabase-0.1.0.0...
[1 of 1] Compiling Main             ( TestPostgres1.hs, 

"names and emails in table 'customers' in database haskell:"
"Acme Cement"
"Biff Home Sales"
"My Pens"
"number of rows in table 'customers':"
4
"rows in table 'customers':"
(1,"Acme Cement","info@acmecement.com")
(2,"Biff Home Sales","info@biff.com")
(3,"My Pens","info@mypens.com")
(4,"Mary Smith","marys@acme.com")
~~~~~~~~

Postgres is my default database and I use it unless there is a compelling reason not to. While work for specific customers has mandated using alternative data stores (e.g., BigTable while working at Google and MongoDB at Compass Labs), Postgres supports relational tables, free text search, and structured data like JSON.

