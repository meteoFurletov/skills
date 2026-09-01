# modern-sql-style

An [agent skill](https://agentskills.io) that teaches AI coding assistants your SQL style guide.

When installed, your AI agent will automatically apply these conventions whenever writing or reviewing SQL — both **DML** (queries) and **DDL** (schema definitions). Covers lowercase keywords, river formatting, leading commas, explicit `as` aliases, column-aligned DDL, and more.

Based on [mattmc3's Modern SQL Style Guide](https://gist.github.com/mattmc3/38a85e6a4ca1093816c08d4815fbebfb) for DML, with DDL conventions derived from real-world data engineering practice.

## Install

```bash
npx skills add modern-sql-style
```

Or, to install directly from this repo:

```bash
npx skills add meteoFurletov/modern-sql-style
```

## What It Enforces

### DML

| Rule | Convention |
| --- | --- |
| Keywords | lowercase (`select`, `from`, `where`, …) |
| Formatting | river alignment (right-aligned keywords) |
| Commas | leading (prefix) commas |
| Aliases | always use `as` keyword |
| Joins | `join` / `left join` only; no `right join` |
| Subqueries | prefix alias with `_` |
| Semicolons | on their own line |
| Dates | ISO-8601, UTC storage |

### DDL

| Rule | Convention |
| --- | --- |
| Keywords | lowercase (`create table`, `engine`, …) |
| Naming | PascalCase for databases/tables |
| Columns | double-quoted, `(` / `,` aligned, column-aligned types & comments |
| Commas | leading commas, `,` aligned with `(` |
| Comments | `comment '…'` after every type and table |
| Clauses | `engine` → `order by` → `comment`, no blank lines |

> **Note:** The DDL conventions are written with **ClickHouse** in mind. The formatting principles apply to any SQL database, but engine-specific syntax (`MergeTree`, `order by` as a primary key, etc.) will need to be adapted for PostgreSQL, MySQL, or other dialects.

## Quick Examples

### DML (Queries)

```sql
select p.name as product_name
     , p.color
     , p.list_price
  from production.product as p
 where p.color in ('Blue', 'Red')
   and p.list_price < 800.00
 order by p.name
```

### DDL (Schema)

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

## Supported Agents

Works with any agent that supports the [agent skills spec](https://agentskills.io):

- GitHub Copilot
- Claude Code
- Cursor
- Windsurf
- and more

## License

[CC BY-SA 4.0](LICENSE) — same as the upstream style guide.
