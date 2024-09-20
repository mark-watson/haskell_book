# Natural Language Interface for Databases

You learned how to use impure Haskell code to access Sqlite and Postgres databases in the first tutorial part of this book. In this chapter we explore some ideas for writing a natural language processing (NLP) interface to databases. For example, instead of a user having to type in an SQL query like:


```{line-numbers: false}
select * from products where products.cost < 10;
```

users of your programs can type:

```{line-numbers: false}
show all products that cost less than $10
```

Here is a more complex example:

```{line-numbers: false}
select customers.name, products.name from customers join links on links.customer_id = customers.id join products on products.id = links.productId where products.cost > 10.00;
```

```{line-numbers: false}
show all customers with products costing more than $10
```

I have been experimenting with NLP database interfaces for over 20 years. In this chapter I try to both make the examples easy enough to understand and modify, yet complex enough so that you are motivated to use these ideas and code in your own applications.

