# PostgreSQL Database Example

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Using Relational Databases](https://leanpub.com/read/haskell-cookbook/using-relational-databases)

Demonstrates connecting to and querying a PostgreSQL database from Haskell using the `postgresql-simple` library. The example works with a simple e-commerce schema (customers, products, and links between them).

## Prerequisites

A running PostgreSQL server with a test database. Set up the schema:

```sql
CREATE DATABASE haskell;
\c haskell

CREATE TABLE customers (id int, name text, email text);
INSERT INTO customers VALUES (1, 'Acme Cement', 'info@acmecement.com');
INSERT INTO customers VALUES (2, 'Biff Home Sales', 'info@biff.com');
INSERT INTO customers VALUES (3, 'My Pens', 'info@mypens.com');

CREATE TABLE products (id int, name text, cost float);
INSERT INTO products VALUES (1, 'Cement bag', 2.5);
INSERT INTO products VALUES (2, 'Cheap Pen', 1.5);
INSERT INTO products VALUES (3, 'Expensive Pen', 14.5);

CREATE TABLE links (id int, customer_id int, productid int);
INSERT INTO links VALUES (1, 1, 1);
INSERT INTO links VALUES (2, 3, 2);
INSERT INTO links VALUES (3, 3, 3);
```

## Run

```bash
stack build --exec TestPostgres1
```

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
