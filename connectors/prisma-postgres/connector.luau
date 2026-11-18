-- Prisma Postgres over Houston's verified-TLS connection to db.prisma.io. Credentials stay on Houston.
type Params = {string | number | boolean}
type Result = {columns: {string}, rows: {{[string]: any}}, truncated: boolean, affectedRows: number?}
type Table = {schema: string, name: string, type: string}
type Column = {
	name: string,
	type: string,
	nullable: boolean,
	default: string?,
	primaryKey: boolean,
	references: {schema: string, table: string, column: string}?,
}

local MAX_ROWS = 10000
local MAX_TABLES = 1000

local function requireText(value: any, name: string): string
	if type(value) ~= "string" or value == "" then
		error(name .. " must be a nonempty string", 2)
	end
	return value
end

local function checkParams(params: any): Params?
	if params == nil then
		return nil
	end
	if type(params) ~= "table" then
		error("params must be an array of strings, numbers or booleans", 2)
	end
	local count = 0
	for key, value in params do
		count += 1
		local kind = type(value)
		if type(key) ~= "number" or (kind ~= "string" and kind ~= "number" and kind ~= "boolean") then
			error("params must be an array of strings, numbers or booleans", 2)
		end
	end
	if count ~= #params then
		error("params must be an array without gaps", 2)
	end
	return params
end

local function run(sql: string, params: Params?, readOnly: boolean, maxRows: number): Result
	return await(db.query({sql = sql, params = params, maxRows = maxRows, readOnly = readOnly}))
end

local function query(sql: string, params: Params?): Result
	return run(requireText(sql, "sql"), checkParams(params), true, MAX_ROWS)
end

local function execute(sql: string, params: Params?): Result
	return run(requireText(sql, "sql"), checkParams(params), false, MAX_ROWS)
end

local TABLES_SQL = [[SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
  AND table_schema NOT LIKE 'pg\_%'
  AND ($1::text IS NULL OR table_schema = $1::text)
ORDER BY table_schema, table_name]]

local function listTables(schema: string?): {tables: {Table}, truncated: boolean}
	if schema ~= nil then
		requireText(schema, "schema")
	end
	local filter: any = if schema then schema else json.decode("null")
	local result = run(TABLES_SQL, {filter}, true, MAX_TABLES)
	local tables: {Table} = json.decode("[]")
	for _, row in result.rows do
		table.insert(tables, {
			schema = row.table_schema,
			name = row.table_name,
			type = if row.table_type == "VIEW" then "view" else "table",
		})
	end
	return {tables = tables, truncated = result.truncated}
end

local COLUMNS_SQL = [[SELECT column_name, data_type, udt_name, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = $1 AND table_name = $2
ORDER BY ordinal_position]]

local KEYS_SQL = [[SELECT a.attname AS column_name, con.contype::text AS kind,
  fn.nspname AS ref_schema, fc.relname AS ref_table, fa.attname AS ref_column
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
CROSS JOIN LATERAL unnest(con.conkey) WITH ORDINALITY AS k(attnum, ord)
JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = k.attnum
LEFT JOIN pg_class fc ON fc.oid = con.confrelid
LEFT JOIN pg_namespace fn ON fn.oid = fc.relnamespace
LEFT JOIN pg_attribute fa ON fa.attrelid = con.confrelid AND fa.attnum = con.confkey[k.ord]
WHERE n.nspname = $1 AND c.relname = $2 AND con.contype IN ('p', 'f')
ORDER BY con.contype, con.conname, k.ord]]

local function describeTable(name: string, schema: string?): {schema: string, table: string, columns: {Column}}
	requireText(name, "name")
	local schemaName = if schema == nil then "public" else requireText(schema, "schema")
	local columnRows = run(COLUMNS_SQL, {schemaName, name}, true, MAX_ROWS).rows
	if #columnRows == 0 then
		error(`Table {schemaName}.{name} was not found; names are case-sensitive, so check listTables()`, 2)
	end
	local primary: {[string]: boolean} = {}
	local references: {[string]: {schema: string, table: string, column: string}} = {}
	for _, row in run(KEYS_SQL, {schemaName, name}, true, MAX_ROWS).rows do
		if row.kind == "p" then
			primary[row.column_name] = true
		elseif row.kind == "f" and references[row.column_name] == nil then
			references[row.column_name] = {schema = row.ref_schema, table = row.ref_table, column = row.ref_column}
		end
	end
	local columns: {Column} = json.decode("[]")
	for _, row in columnRows do
		table.insert(columns, {
			name = row.column_name,
			type = if row.data_type == "USER-DEFINED" or row.data_type == "ARRAY" then row.udt_name else row.data_type,
			nullable = row.is_nullable == "YES",
			default = row.column_default,
			primaryKey = primary[row.column_name] == true,
			references = references[row.column_name],
		})
	end
	return {schema = schemaName, table = name, columns = columns}
end

local exports: {[string]: any} = {query = query, listTables = listTables, describeTable = describeTable}
if houston.allows("data:write") then
	exports.execute = execute
end

local HELP: {[string]: string} = {
	listTables = [[listTables(schema?) -> {tables = {{schema, name, type}}, truncated}
  Lists tables and views (type "table" or "view"), sorted by schema and name,
  optionally in one schema. System schemas are left out. At most 1,000 entries.
  Example: prisma.listTables("public")]],
	describeTable = [[describeTable(name, schema?) -> {schema, table, columns}
  Describes one table or view; schema defaults to "public". Each column is
  {name, type, nullable, default?, primaryKey, references?}, in table order;
  references is {schema, table, column} for a foreign key. Enum and array
  columns report their PostgreSQL type name, such as "Role" or "_text".
  Names are case-sensitive: Prisma models usually map to quoted names like "User".
  Raises an error when the table does not exist.
  Example: prisma.describeTable("User")]],
	query = [[query(sql, params?) -> {columns, rows, truncated}
  Runs one statement in a read-only transaction. Bind values with $1, $2, ...
  in sql and pass them in order as params (strings, numbers, booleans).
  Parameters take their type from context; cast where needed, as in $1::jsonb.
  Prisma creates case-sensitive names, so double-quote them: SELECT "id",
  "createdAt" FROM "User". Prisma enums are PostgreSQL enum types; compare
  them as text or cast, as in "role" = $1::"Role". The _prisma_migrations
  table records applied migrations.
  rows are objects keyed by column name, in columns order; NULL columns are
  absent. Booleans, integers, floats and json/jsonb columns become Lua values;
  integers beyond 2^53 and every other type keep PostgreSQL's text form, such as
  '2026-01-31 09:30:00+00' for timestamptz or '\x0102' for bytea.
  At most 10,000 rows or 4 MiB are returned; truncated tells when more exist,
  so add LIMIT, filters or aggregation. Give duplicate column names an alias.
  Example: prisma.query('SELECT "id", "email" FROM "User" WHERE "role" = $1::"Role" LIMIT 50', {"ADMIN"})]],
	execute = [[execute(sql, params?) -> {affectedRows, columns, rows, truncated}
  Runs one statement that may change data, outside any transaction, with the
  same parameters as query. affectedRows counts the inserted, updated or deleted
  rows; rows hold any RETURNING values. A failed or interrupted call may already
  have applied its change, so check before running it again. Schema changes made
  here bypass Prisma Migrate and will drift from the project's schema.prisma.
  Example: prisma.execute('UPDATE "Task" SET "done" = true WHERE "id" = $1 RETURNING "id"', {42})]],
}

function exports.help(): string
	local sections = {
		"prisma-postgres: SQL on one Prisma Postgres database. Each call is one statement on its own connection. "
			.. "Connector calls return values directly; do not await them. "
			.. "Start with listTables() and describeTable(name) to find the right quoted names.",
	}
	for _, name in {"listTables", "describeTable", "query", "execute"} do
		if exports[name] then
			table.insert(sections, HELP[name])
		end
	end
	return table.concat(sections, "\n\n")
end

return exports
