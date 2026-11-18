You need a Prisma Postgres database in the
[Prisma Console](https://console.prisma.io). No developer app is required.

1. In the Prisma Console, open your project and select the database.
2. Select **Connect to your database**, then **Generate new connection string**.
   Generate a new one for Houston rather than reusing your application's, so you
   can revoke it on its own later.
3. Copy the **direct** connection string. It looks like
   `postgres://USERNAME:PASSWORD@db.prisma.io:5432/postgres?sslmode=require`.
4. In Houston, choose the access level. **Read** is recommended: every Prisma
   Postgres credential can change data, so Houston's Read level is what keeps
   agents from doing so.
5. Leave **Connection** on **Direct (recommended)**.
6. Paste the **Username** (between `postgres://` and the first `:`) and the
   **Password** (between that `:` and `@db.prisma.io`).
7. Select **Add connector**.

Your password stays on the Houston server. Houston always connects with TLS and
checks Prisma's certificate.

See Prisma's guide to
[direct connections](https://www.prisma.io/docs/postgres/database/direct-connections)
for more about connection strings.

## Advanced

### Direct or pooled connection

Both use the same username and password. Houston opens a short connection for
each statement, so the direct connection works well. Choose **Pooled** only if
your plan's direct connection limit is reached; pooled statements stop after 10
minutes.

### Revoking access

Generating a connection string doesn't revoke older ones. The Console names them
all `console-connection-string`; tell yours apart by the last four characters of
the password. Delete it in the Console when you remove this connector.

### Troubleshooting

- **"Password authentication failed".** Copy the username and password again
  from a freshly generated connection string. If the password contains `%`
  sequences, it was URL-encoded: enter the decoded characters.
- **"Could not connect".** Check that the database still exists in the Prisma
  Console, and that **Connection** is set to one of Prisma's hosts.
