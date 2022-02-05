function lex(entrypoint, line)
	local lineno = 1
	while line do
		local sym_start = 1
		local sym_done = false

		local idx = 1

		while idx <= #line do
			cur = line:byte(idx)
			next = line:byte(idx + 1)
			nextnext = line:byte(idx + 2)
			nextnextnext = line:byte(idx + 3)

			if cur == CHARS.DASH then
				if next == CHARS.DASH then
					if nextnext == CHARS.DASH then
						coroutine.yield(symbol(
							SYMBOLS.DOCSTRING, lineno, idx, #line,
							string.sub(line, idx + 3, #line)
						))
						idx = #line
					else
						coroutine.yield(symbol(
							SYMBOLS.COMMENT, lineno, idx, #line,
							string.sub(line, idx + 2, #line)
						))
						idx = #line
					end
				elseif next == CHARS.GT then
					coroutine.yield(symbol(SYMBOLS.ARROW, lineno, idx, idx + 2))
					idx = idx + 1
				else
					die('dash can only be followed by more dashes or >')
				end
			elseif is_num(cur) then
				local num_idx = idx + 1
				local num_cur = line:byte(num_idx)
				while num_idx < #line do
					if not is_num(num_cur) then
						coroutine.yield(symbol(
							SYMBOLS.INT, lineno, idx, num_idx,
							string.sub(line, idx, num_idx - 1)
						))
						idx = num_idx - 1
						break
					else
						num_idx = num_idx + 1
						str_cur = line:byte(num_idx)

						if num_idx >= #line then
							coroutine.yield(symbol(
								SYMBOLS.INT, lineno, idx, num_idx,
								string.sub(line, idx, num_idx - 1)
							))
							idx = num_idx
							break
						end
					end
				end
			elseif cur == CHARS.TILDE then
				if next == CHARS.GT then
					coroutine.yield(symbol(SYMBOLS.SQUIGGLY_ARROW, lineno, idx, idx + 2))
					idx = idx + 1
				else
					die('tilde can only be followed by >')
				end
			elseif cur == CHARS.EQUAL then
				if next == CHARS.GT then
					coroutine.yield(symbol(SYMBOLS.RIGHT_THICC_ARROW, lineno, idx, idx + 2))
					idx = idx + 1
				else
					coroutine.yield(symbol(SYMBOLS.EQUAL, lineno, idx, idx + 1))
				end
			elseif cur == CHARS.LT then
				if next == CHARS.EQUAL then
					if nextnext == CHARS.GT then
						coroutine.yield(symbol(SYMBOLS.HYDRA_THICC_ARROW, lineno, idx, idx + 3))
						idx = idx + 2
					else
						coroutine.yield(symbol(SYMBOLS.LEFT_THICC_ARROW, lineno, idx, idx + 2))
						idx = idx + 1
					end
				else
					coroutine.yield(symbol(SYMBOLS.LT, lineno, idx, idx + 1))
				end
			elseif cur == CHARS.COLON then
				coroutine.yield(symbol(SYMBOLS.COLON, lineno, idx, idx + 1))
			elseif cur == CHARS.SEMICOLON then
				coroutine.yield(symbol(SYMBOLS.SEMICOLON, lineno, idx, idx + 1))
			elseif cur == CHARS.TAB then
				coroutine.yield(symbol(SYMBOLS.INDENT, lineno, idx, idx + 1))
			elseif cur == CHARS.SPACE then
				-- TODO merge consecutive spaces into one entity
				coroutine.yield(symbol(SYMBOLS.SPACES, lineno, idx, idx + 1))
			elseif cur == CHARS.SLASH then
				coroutine.yield(symbol(SYMBOLS.SLASH, lineno, idx, idx + 1))
			elseif cur == CHARS.DOT then
				if next == CHARS.DOT then
					if nextnext == CHARS.DOT then
						coroutine.yield(symbol(SYMBOLS.DOTDOTDOT, lineno, idx, idx + 3))
						idx = idx + 2
					else
						coroutine.yield(symbol(SYMBOLS.DOTDOT, lineno, idx, idx + 2))
						idx = idx + 1
					end
				else
					coroutine.yield(symbol(SYMBOLS.DOT, lineno, idx, idx + 1))
				end
			elseif cur == CHARS.LCBR then
				coroutine.yield(symbol(SYMBOLS.LCBR, lineno, idx, idx + 1))
			elseif cur == CHARS.RCBR then
				coroutine.yield(symbol(SYMBOLS.RCBR, lineno, idx, idx + 1))
			elseif cur == CHARS.LPRN then
				coroutine.yield(symbol(SYMBOLS.LPRN, lineno, idx, idx + 1))
			elseif cur == CHARS.RPRN then
				coroutine.yield(symbol(SYMBOLS.RPRN, lineno, idx, idx + 1))
			elseif cur == CHARS.EXCLAIM then
				if next == CHARS.DASH and nextnext == CHARS.GT then
					-- one-liner FFI reads to EOL only
					if nextnextnext then
						coroutine.yield(symbol(
							SYMBOLS.FFI, lineno, idx, #line,
							string.sub(line, idx + 4, #line)
						))
						idx = #line
					else
						-- look, this is really the parser's job and I'm
						-- reaching out of scope here, but that's on me for
						-- having a tricky to handle FFI syntax, whatever, it's
						-- 2021, rules are fake. since I have no interest in
						-- also parsing lua syntax (at least in the bootstrap
						-- compiler which will run over reasonably trusted
						-- inputs - the real compiler may have some better
						-- understanding of Lua), we're going to just treat it
						-- as a completely opaque blob that includes each
						-- consecutive line at the expected indentation level
						local lineno_og = lineno
						local _, indent_level_begin = line:find("\t*")
						indent_level_exp = indent_level_begin + 1

						contents = ""

						line = entrypoint:read(READ_NEXT_LINE)
						lineno = lineno + 1
						while line do
							local _, indent_level = line:find("\t*")
							if indent_level >= indent_level_exp then
								contents = contents .. string.sub(line, indent_level + 1, #line) .. "\n"
								line = entrypoint:read(READ_NEXT_LINE)
								lineno = lineno + 1
							else
								leaving_ffi = true
								break
							end
						end

						-- trim trailing newline just because it makes debug output ugly
						contents = string.sub(contents, 1, -2)

						coroutine.yield(symbol(SYMBOLS.FFI, lineno_og, idx, -1, contents))
					end
				else
					coroutine.yield(symbol(SYMBOLS.EXCLAIM, lineno, idx, idx + 1))
				end
			elseif cur == CHARS.PIPE then
				if next == CHARS.GT then
					if nextnext == CHARS.GT then
						coroutine.yield(symbol(SYMBOLS.PIPE_LONG, lineno, idx, idx + 3))
						idx = idx + 2
					else
						coroutine.yield(symbol(SYMBOLS.PIPE_SHORT, lineno, idx, idx + 2))
						idx = idx + 1
					end
				else
					die('pipe can only be followed by > or >>')
				end
			elseif cur == CHARS.DQUOTE or cur == CHARS.SQUOTE then
				local last = cur
				local string_idx = idx + 1
				local str_cur = line:byte(string_idx)
				while string_idx < #line do
					if str_cur == cur and not (last == CHARS.BSLSH) then
						coroutine.yield(symbol(
							SYMBOLS.STRING, lineno, idx, string_idx,
							string.sub(line, idx + 1, string_idx - 1)
						))
						idx = string_idx
						break
					else
						last = str_cur
						string_idx = string_idx + 1
						str_cur = line:byte(string_idx)

						if string_idx >= #line then
							coroutine.yield(symbol(
								SYMBOLS.STRING, lineno, idx, string_idx,
								string.sub(line, idx + 1, string_idx - 1)
							))
							idx = string_idx
							break
						end
					end
				end
			else
				-- everything else is assumed to be an identifier
				local ident_idx = idx + 1
				local ident_cur = line:byte(ident_idx)
				while ident_idx <= #line do
					if identifier_breaker(ident_cur) then
						coroutine.yield(symbol(
							SYMBOLS.IDENTIFIER, lineno, idx, ident_idx,
							string.sub(line, idx, ident_idx - 1)
						))
						idx = ident_idx - 1
						break
					else
						ident_idx = ident_idx + 1
						ident_cur = line:byte(ident_idx)

						if ident_idx > #line then
							coroutine.yield(symbol(
								SYMBOLS.IDENTIFIER, lineno, idx, ident_idx,
								string.sub(line, idx, ident_idx - 1)
							))
							idx = ident_idx - 1
							break
						end
					end
				end
			end

			-- sometimes we get into weird states if a file ends with an FFI
			-- block where there's no more lines to read, so just hack around
			-- those
			if not line then break end

			idx = idx + 1
		end

		if leaving_ffi then
			leaving_ffi = false
		elseif line then
			line = coroutine.yield()
			lineno = lineno + 1
		end
	end
end

function print_thing(thing)
	if thing == nil then return end

	if thing.kind == THINGS.IMPORT then
		print(string.format(
			"IMPORT { path = %s; identifiers = %s }",
			join(thing.path, " -> "),
			join(thing.identifiers, ", ")
		))
	end
end

function join(it, joiner)
	if it == nil then return nil end

	ret = ""

	for idx, val in ipairs(it) do
		ret = ret .. val
		if idx < #it then ret = ret .. joiner end
	end

	return ret
end

function candidate_import(existing, candidate)
	if existing == nil and candidate == SYMBOLS.DOT then
		return true, { existing; }
	end

	return false, nil
end

function is_num(byte)
	return byte == CHARS.N0 or
		byte == CHARS.N1 or
		byte == CHARS.N2 or
		byte == CHARS.N3 or
		byte == CHARS.N4 or
		byte == CHARS.N5 or
		byte == CHARS.N6 or
		byte == CHARS.N7 or
		byte == CHARS.N8 or
		byte == CHARS.N9
end

function identifier_breaker(byte)
	return byte == CHARS.SPACE or
		byte == CHARS.TAB or
		byte == CHARS.NEWLINE or
		byte == CHARS.PIPE or
		byte == CHARS.GT or
		byte == CHARS.LT or
		byte == CHARS.EQL or
		byte == CHARS.SQUOTE or
		byte == CHARS.DQUOTE or
		byte == CHARS.LBRC or
		byte == CHARS.RBRC or
		byte == CHARS.LCBR or
		byte == CHARS.RCBR or
		byte == CHARS.COLON or
		byte == CHARS.SEMICOLON or
		byte == CHARS.DOT or
		byte == CHARS.EXCLAIM or
		byte == CHARS.DASH or
		byte == CHARS.TILDE or
		byte == CHARS.EQUAL or
		byte == CHARS.LPRN or
		byte == CHARS.RPRN
end

return {
	lex = lex,
}