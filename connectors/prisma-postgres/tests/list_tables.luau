-- listTables reads information_schema read-only, filters by schema when asked, and keeps an empty result an array.
return {
	scenario = {publisher = {}, auth_method = "", auth_config = {}, config = {host = "db.prisma.io", username = "fixture-user", password = "fixture-password"}},
	access = {data = "read"},
	configure = function()
		requests = {}
		db = {query = function(request)
			table.insert(requests, request)
			if #requests == 1 then
				return fixture.operation({columns = {"table_schema", "table_name", "table_type"}, rows = {
					{table_schema = "public", table_name = "User", table_type = "BASE TABLE"},
					{table_schema = "public", table_name = "_prisma_migrations", table_type = "BASE TABLE"},
					{table_schema = "reporting", table_name = "ActiveUsers", table_type = "VIEW"},
				}, truncated = false})
			end
			return fixture.operation({columns = {"table_schema", "table_name", "table_type"}, rows = {}, truncated = false})
		end}
	end,
	run = function(exports)
		local all = exports.listTables()
		assert(#all.tables == 3 and all.truncated == false)
		assert(all.tables[1].schema == "public" and all.tables[1].name == "User" and all.tables[1].type == "table")
		assert(all.tables[3].name == "ActiveUsers" and all.tables[3].type == "view")
		local first = requests[1]
		assert(first.readOnly == true and first.maxRows == 1000)
		assert(string.find(first.sql, "information_schema.tables", 1, true))
		assert(json.encode(first.params) == "[null]", "no schema filter sends a JSON null parameter")

		local empty = exports.listTables("archive")
		assert(#empty.tables == 0 and json.encode(empty.tables) == "[]", "empty results stay JSON arrays")
		assert(requests[2].params[1] == "archive" and requests[2].readOnly == true)

		local ok, err = pcall(exports.listTables, "")
		assert(not ok and string.find(tostring(err), "schema must be a nonempty string", 1, true))
		assert(#requests == 2)
	end,
}
