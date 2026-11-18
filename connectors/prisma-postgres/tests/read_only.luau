-- Read connections expose the read operations alone, and query always asks for a read-only statement.
return {
	scenario = {publisher = {}, auth_method = "", auth_config = {}, config = {host = "db.prisma.io", username = "fixture-user", password = "fixture-password"}},
	access = {data = "read"},
	configure = function()
		requests = {}
		db = {query = function(request)
			table.insert(requests, request)
			return fixture.operation({columns = {"id", "email"}, rows = {{id = 7, email = "ada@example.com"}}, truncated = false})
		end}
	end,
	run = function(exports)
		assert(exports.execute == nil, "Read access must not expose execute")
		assert(exports.query and exports.listTables and exports.describeTable, "read operations must be exported")
		local result = exports.query('SELECT "id", "email" FROM "User" WHERE "role" = $1::"Role"', {"ADMIN"})
		assert(result.rows[1].id == 7 and result.rows[1].email == "ada@example.com" and result.truncated == false)
		local request = requests[1]
		assert(request.sql == 'SELECT "id", "email" FROM "User" WHERE "role" = $1::"Role"')
		assert(#request.params == 1 and request.params[1] == "ADMIN")
		assert(request.readOnly == true and request.maxRows == 10000)

		exports.query("SELECT 1")
		assert(#requests == 2 and requests[2].params == nil and requests[2].readOnly == true)

		local ok, err = pcall(exports.query, "")
		assert(not ok and string.find(tostring(err), "sql must be a nonempty string", 1, true))
		ok, err = pcall(exports.query, "SELECT $1", {{nested = true}})
		assert(not ok and string.find(tostring(err), "params must be an array", 1, true))
		ok, err = pcall(exports.query, "SELECT $1", {name = "x"})
		assert(not ok and string.find(tostring(err), "params must be an array", 1, true))
		assert(#requests == 2, "invalid arguments must not reach the database")
	end,
}
