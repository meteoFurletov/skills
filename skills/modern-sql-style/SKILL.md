---
name: modern-sql-style
description: Use this skill whenever writing, reviewing, editing, or generating SQL code of any kind — DML (SELECT, INSERT, UPDATE, DELETE, CTEs, subqueries) or DDL (CREATE TABLE, ALTER TABLE, DROP, schema definitions). Apply this skill even when SQL is embedded inside other code (Python, dbt models, stored procedures, migration scripts). Triggers include any mention of SQL, queries, database tables, schemas, writing a query, creating a table, fixing a query, reviewing SQL, or code that interacts with a relational database. This defines the team's mandatory SQL formatting and naming conventions for both DML and DDL. Always follow these rules unless the user explicitly requests a different style.
---

# Modern SQL Style Guide

Based on [mattmc3's Modern SQL Style Guide](https://gist.github.com/mattmc3/38a85e6a4ca1093816c08d4815fbebfb).

## Quick Reference Example

```sql
select p.name as product_name
     , p.product_number
     , pm.name as product_model_name
     , p.color
     , p.list_price
  from production.product as p
  join production.product_model as pm
    on p.product_model_id = pm.product_model_id
 where p.color in ('Blue', 'Red')
   and p.list_price < 800.00
   and pm.name like '%frame%'
 order by p.name
```

## Core Rules

### 1. Casing

- **All SQL keywords must be lowercase**: `select`, `from`, `where`, `join`, `on`, `and`, `or`, `group by`, `order by`, `insert into`, `update`, `delete`, `case`, `when`, `then`, `else`, `end`, `as`, `in`, `is`, `not`, `null`, `between`, `like`, `exists`, `union`, `except`, `intersect`, etc.
- Never use UPPERCASE or Title Case for keywords.
- Modern editors color-code keywords; SHOUTCASE is unnecessary and harder to read.

### 2. River Formatting (Preferred)

Right-align keywords to form a vertical "river" that separates keywords from implementation. The river makes queries easy to scan visually.

```sql
-- river at column 7
select p.color
     , p.list_price
     , p.name as product_name
  from production.product as p
  join production.product_model as pm
    on p.product_model_id = pm.product_model_id
 where p.list_price < 1000.00
   and p.color in ('Black', 'Red')
 order by p.name
```

If river formatting is not practical, use **4-space indent formatting** with major keywords on their own line:

```sql
select
    p.color
    ,p.list_price
    ,p.name as product_name
from
    production.product as p
    join production.product_model as pm
        on p.product_model_id = pm.product_model_id
where
    p.list_price < 1000.00
    and p.color in ('Black', 'Red')
order by
    p.name
```

### 3. Commas

- **Use leading (prefix) commas**, not trailing commas.
- The comma should border the river on the keyword side.
- This prevents accidental aliasing bugs from missing trailing commas and makes it easy to add/remove/comment columns at the end.

**GOOD:**
```sql
select name
     , list_price
     , color
```

**BAD:**
```sql
select name,
       list_price
       color,  -- oops, missing comma made an accidental alias
```

### 4. Aliases

- Always use the `as` keyword for aliases — never implicit aliasing.
- Alias names should relate to the object (e.g., first letter of each word).
- Always alias aggregates, derived columns, and function-wrapped columns.
- Always use table alias prefixes when querying more than one table.
- Prefix subquery aliases with `_` to differentiate from outer query aliases.

```sql
select prdct.color as product_color
     , cat.name as category_name
     , count(*) as product_count
  from production.product as prdct
  join production.product_category as cat
    on prdct.category_id = cat.category_id
```

### 5. Naming

- Use `underscore_separated` or `PascalCase` but **do not mix** styles.
- Prefer plural table names (e.g., `employees` over `employee`).
- Do not use object prefixes like `tbl_`, `vw_`, `sp_`, `fn_`.
- Do not use reserved words for table or column names.
- Avoid generic column names like `name` or `description` — use descriptive prefixes (e.g., `product_name`).
- Favor descriptive names over terse abbreviations.

### 6. FROM and JOINs

- Only one table in the `from` clause. Never use comma-separated from-joins.
- Omit `inner` and `outer` keywords — use plain `join` and `left join`.
- Put `on` conditions on their own indented line.
- Start with `join` (inner) first, then `left join`. Do not intermingle.
- Avoid `right join` — rewrite as `left join`.
- Multi-condition joins: additional conditions go on new indented lines.
- Order `on` clause with joining aliases referencing tables top-to-bottom.

```sql
   select *
     from human_resources.employee as emp
     join person.person as per
       on emp.business_entity_id = per.business_entity_id
left join human_resources.department_history as edh
       on emp.business_entity_id = edh.business_entity_id
left join human_resources.department as dep
       on edh.department_id = dep.department_id
      and dep.name <> dep.group_name
```

### 7. WHERE Clause

- Each condition on its own line, aligned to the river.
- Always use parentheses when mixing `and` and `or`.
- Put semicolons on their own line to prevent dangerous bugs.

```sql
 where p.weight > 2.5
   and p.list_price < 1500.00
   and p.color in ('Blue', 'Black', 'Red')
;
```

### 8. SELECT Clause Details

- First column on the same line as `select`.
- If ≤3 short, unaliased columns: may share one line.
- With `distinct` or `top`: put the first column on its own line.
- Do not bracket-escape names unless they collide with keywords.

### 9. GROUP BY / HAVING / ORDER BY

- `group by` column order should match `select` column order.
- `having` follows the same rules as `where`.
- Do not use superfluous `asc` — ascending is the default.
- Ordering by column number is okay but not preferred.

```sql
  select poh.employee_id
       , poh.vendor_id
       , count(*) as order_count
       , avg(poh.sub_total) as avg_sub_total
    from purchasing.purchase_order_header as poh
group by poh.employee_id
       , poh.vendor_id
  having count(*) > 1
     and avg(poh.sub_total) > 3000.00
```

### 10. CASE Statements

Align `when`, `then`, and `else` inside `case` / `end`:

```sql
select dep.name as department_name
     , case when dep.name in ('Engineering', 'Tool Design', 'Information Services')
            then 'Information Technology'
            else dep.group_name
       end as new_group_name
  from human_resources.department as dep
```

### 11. Window Functions

Split long window functions across multiple lines, one per clause. Always alias them.

```sql
select p.product_id
     , p.name as product_name
     , row_number() over (partition by p.product_line
                              order by right(p.product_number, 4) desc) as sequence_num
  from production.product as p
```

### 12. CTEs (WITH clauses)

Indent one level deeper inside parentheses and follow the same conventions:

```sql
with stg_table_name as (
    select id as table_id
         , name
         , created_at
         , updated_at
      from sample_table
)
select *
  from stg_table_name
```

### 13. Whitespace

- No tabs — use spaces.
- Prefer indenting to the river, not fixed increments.
- No trailing whitespace.
- No more than two blank lines between statements.
- No empty lines in the middle of a single statement.
- One final newline at the end of a file.

### 14. Comments

- Comments should explain **intent**, not mechanics.
- Place comments at the top of queries or scripts.
- Comment non-obvious things: why a filter exists, why an optimization was needed.

### 15. Other Guidance

- Store `datetime` in UTC unless using timezone-aware types.
- Use ISO-8601 format for date/time literals (`YYYY-MM-DD HH:MM:SS`).
- Tables should have `created_at` and `updated_at` metadata columns.
- Prefer single-column auto-increment surrogate keys for primary keys.

---

## DDL Rules

### DDL Quick Reference Example

```sql
create table Inventory.Product
( "ProductId"    Int64       comment 'Unique product identifier'
, "ProductName"  String      comment 'Display name'
, "CategoryCode" String      comment 'Category reference code'
, "Price"        Float64     comment 'Unit price'
, "IsActive"     Bool        comment 'Whether the product is active'
, "Tags"         Array(JSON) comment 'Arbitrary metadata tags'
)
engine = MergeTree()
order by ("CategoryCode", "ProductId")
comment 'Product catalogue'
```

### 16. DDL Keyword Case

- All DDL keywords must be **lowercase**: `create table`, `alter table`, `drop table`, `on cluster`, `engine`, `order by`, `comment`, `partition by`, `primary key`, `if exists`, `if not exists`, etc.
- Same rule as DML — no UPPERCASE or Title Case.

### 17. Database & Table Naming

- Database and table names use **PascalCase** (no underscores), separated by a dot.
- Do not quote database or table identifiers unless absolutely necessary.

```sql
-- GOOD
create table Inventory.ProductCategory

-- BAD
create table inventory.product_category
create table "Inventory"."ProductCategory"
```

### 18. Column Quoting

- All column names in DDL must be surrounded by **double quotes** (`"ColumnName"`).
- This allows mixed-case or reserved words without ambiguity.
- Database and table names are **not** quoted.

```sql
create table Inventory.Product
( "ProductId"   Int64  comment 'Unique product identifier'
, "ProductName" String comment 'Display name'
)
```

### 19. Column Indentation & Alignment

- The opening parenthesis `(` starts a new line, immediately followed by the first column definition.
- Subsequent columns start with `, ` on new lines, aligned with `(`.
- Column names, data types, and `comment` clauses are **column-aligned**: each column starts **one space** after the longest value in the preceding column.
- For example, if the longest column name is `"CategoryCode"`, then all data types start one space after that width. If the longest type is `Array(JSON)`, then all `comment` keywords start one space after that width.

```sql
create table Inventory.Product
( "ProductId"    Int64       comment 'Unique product identifier'
, "ProductName"  String      comment 'Display name'
, "CategoryCode" String      comment 'Category reference code'
, "Tags"         Array(JSON) comment 'Arbitrary metadata tags'
)
```

### 20. DDL Comma Placement

- Use **leading commas** — the first column line starts with `(`, subsequent columns start with `,`.
- The `,` is aligned with `(` in the same column.
- No trailing commas; the last column before `)` has no comma after it.

```sql
create table Inventory.Product
( "ProductId"   Int64  comment 'Unique product identifier'
, "ProductName" String comment 'Display name'
, "Price"       Float64 comment 'Unit price'
)
```

### 21. Column Comments

- Every column should have a `comment '…'` clause **after the data type**.
- Comments use single-quoted strings.
- Write comments in the project's language (Russian or your team's language is fine).
- The table itself also gets a `comment` after the closing parenthesis.

```sql
, "ProductName" String comment 'Display name'
)
comment 'Product catalogue'
```

### 22. Engine & Ordering Clauses

- After the closing parenthesis, place each clause on its own line with **no blank lines** between them.
- Order: `engine`, then `order by`, then `comment`.
- `order by` uses a **parenthesised list** of columns, quoted the same way as in the column definitions.

```sql
)
engine = MergeTree()
order by ("CategoryCode", "ProductId")
comment 'Product catalogue'
```

### 23. DDL Whitespace & Layout

- No blank lines between clauses (`engine`, `order by`, `comment`).
- Each clause starts on a new line.
- No inline comments inside the column list.
- One final newline at the end of the file.
