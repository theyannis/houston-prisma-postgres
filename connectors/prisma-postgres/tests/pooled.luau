-- The pooled host is an accepted Connection choice and serves the same operations.
return {
	scenario = {publisher = {}, auth_method = "", auth_config = {}, config = {host = "pooled.db.prisma.io", username = "fixture-user", password = "fixture-password"}},
	configure = function()
		requests = {}
		db = {query = function(request)
			table.insert(requests, request)
			return fixture.operation({columns = {"ok"}, rows = {{ok = 1}}, truncated = false})
		end}
	end,
	run = function(exports)
		assert(exports.execute == nil, "access defaults to Read")
		assert(exports.query("SELECT 1 AS ok").rows[1].ok == 1 and #requests == 1)
		assert(requests[1].readOnly == true)
	end,
}
