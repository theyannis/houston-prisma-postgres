---
description: Give agents SQL access to a Prisma Postgres database, read-only unless you allow changes.
---
# Prisma Postgres

Connect agents to a Prisma Postgres database so they can answer questions from
your application's data.

## Explore your data

- Find the tables behind your Prisma models, with their columns, keys and
  relations.
- Look up records, join tables, and summarize results.
- Read JSON columns as structured data.

## Make changes when you allow it

Prisma Postgres credentials always have full access to the database, so Houston
adds the safety. With **Read** access, every statement runs in a read-only
transaction and data and schema cannot change. With **Write** access, agents
can also insert, update and delete rows.

Schema changes are best made through Prisma Migrate in your project, so your
`schema.prisma` stays in step with the database.
