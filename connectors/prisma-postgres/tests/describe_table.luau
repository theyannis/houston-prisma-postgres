-- describeTable merges columns with primary and foreign keys, defaults to public, and reports a missing table.
return {
	scenario = {publisher = {}, auth_method = "", auth_config = {}, config = {host = "db.prisma.io", username = "fixture-user", password = "fixture-password"}},
	access = {data = "read"},
	configure = function()
		requests = {}
		db = {query = function(request)
			table.insert(requests, request)
			local isKeys = string.find(request.sql, "pg_constraint", 1, true) ~= nil
			if request.params[2] == "Missing" then
				return fixture.operation({columns = {}, rows = {}, truncated = false})
			end
			if isKeys then
				return fixture.operation({columns = {"column_name", "kind", "ref_schema", "ref_table", "ref_column"}, rows = {
					{column_name = "authorId", kind = "f", ref_schema = "public", ref_table = "User", ref_column = "id"},
					{column_name = "id", kind = "p"},
				}, truncated = false})
			end
			return fixture.operation({columns = {"column_name", "data_type", "udt_name", "is_nullable", "column_default"}, rows = {
				{column_name = "id", data_type = "integer", udt_name = "int4", is_nullable = "NO", column_default = "nextval('\"Post_id_seq\"'::regclass)"},
				{column_name = "title", data_type = "text", udt_name = "text", is_nullable = "NO"},
				{column_name = "status", data_type = "USER-DEFINED", udt_name = "Status", is_nullable = "YES"},
				{column_name = "tags", data_type = "ARRAY", udt_name = "_text", is_nullable = "NO"},
				{column_name = "authorId", data_type = "integer", udt_name = "int4", is_nullable = "NO"},
			}, truncated = false})
		end}
	end,
	run = function(exports)
		local result = exports.describeTable("Post")
		assert(result.schema == "public" and result.table == "Post" and #result.columns == 5)
		local id, title, status, tags, author = table.unpack(result.columns)
		assert(id.name == "id" and id.type == "integer" and id.primaryKey == true and id.nullable == false)
		assert(id.default == "nextval('\"Post_id_seq\"'::regclass)" and id.references == nil)
		assert(title.primaryKey == false and title.default == nil)
		assert(status.type == "Status" and status.nullable == true)
		assert(tags.type == "_text")
		assert(author.references.schema == "public" and author.references.table == "User" and author.references.column == "id")

		assert(#requests == 2)
		for _, request in requests do
			assert(request.readOnly == true)
			assert(request.params[1] == "public" and request.params[2] == "Post")
		end
		assert(string.find(requests[1].sql, "information_schema.columns", 1, true))

		exports.describeTable("Report", "analytics")
		assert(requests[3].params[1] == "analytics" and requests[3].params[2] == "Report")

		local ok, err = pcall(exports.describeTable, "Missing")
		assert(not ok and string.find(tostring(err), "public.Missing was not found", 1, true))
		assert(#requests == 5, "a missing table stops before the key query")
		ok, err = pcall(exports.describeTable, "")
		assert(not ok and string.find(tostring(err), "name must be a nonempty string", 1, true))
		assert(#requests == 5)
	end,
}
