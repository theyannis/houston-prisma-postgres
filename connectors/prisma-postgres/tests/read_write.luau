-- Write connections add execute, which sends a statement allowed to write.
return {
	scenario = {publisher = {}, auth_method = "", auth_config = {}, config = {host = "db.prisma.io", username = "fixture-user", password = "fixture-password"}},
	access = {data = "write"},
	configure = function()
		requests = {}
		db = {query = function(request)
			table.insert(requests, request)
			return fixture.operation({columns = {"id"}, rows = {{id = 42}}, truncated = false, affectedRows = 1})
		end}
	end,
	run = function(exports)
		assert(exports.query and exports.listTables and exports.describeTable, "read operations stay exported")
		local result = exports.execute('UPDATE "Task" SET "done" = true WHERE "id" = $1 RETURNING "id"', {42})
		assert(result.affectedRows == 1 and result.rows[1].id == 42)
		local request = requests[1]
		assert(request.sql == 'UPDATE "Task" SET "done" = true WHERE "id" = $1 RETURNING "id"')
		assert(request.readOnly == false and request.maxRows == 10000)
		assert(#request.params == 1 and request.params[1] == 42)

		exports.query('SELECT count(*) AS n FROM "Task"')
		assert(requests[2].readOnly == true, "query stays read-only on Write connections")

		local ok = pcall(exports.execute, "")
		assert(not ok and #requests == 2)
	end,
}
