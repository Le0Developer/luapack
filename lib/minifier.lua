-- Based on https://pastebin.com/raw/dqHRhQi2
--   which comes from https://github.com/SquidDev-CC/Howl/tree/master/howl/lexer
-- Changes:
--   Ported to normal lua, was made for ComputerCraft originally
--		(a minecraft mod)
--   Patched to work with Lua5.3+

local _W
if not getfenv then -- lua 5.3+ compatibility
					-- not real getfenv/setfenv emulation, but works
	function _W(f)
		local loaded = false
		return setmetatable({}, {__index = function(self, key)
			if not loaded then
				loaded = f()
			end
			return loaded[key]
		end, __call = function(self, ...)
			if not loaded then
				loaded = f()
			end
			return loaded(...)
		end})
	end
else
	function _W(f) 
		local e=setmetatable({}, {__index = getfenv()}) 
		return setfenv(f,e)() or e 
	end
end
Utils=_W(function()
return {
	CreateLookup = function(tbl)
		for _, v in ipairs(tbl) do
			tbl[v] = true
		end
		return tbl
	end
}
end)
Constants=_W(function()
--- Lexer constants
-- @module lexer.Constants

createLookup = Utils.CreateLookup

--- List of white chars
WhiteChars = createLookup{' ', '\n', '\t', '\r'}

--- Lookup of escape characters
EscapeLookup = {['\r'] = '\\r', ['\n'] = '\\n', ['\t'] = '\\t', ['"'] = '\\"', ["'"] = "\\'"}

--- Lookup of lower case characters
LowerChars = createLookup{
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
	'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
}

--- Lookup of upper case characters
UpperChars = createLookup{
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
	'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
}

--- Lookup of digits
Digits = createLookup{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}

--- Lookup of hex digits
HexDigits = createLookup{
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'
}

--- Lookup of valid symbols
Symbols = createLookup{'+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#'}

--- Lookup of valid keywords
Keywords = createLookup{
	'and', 'break', 'do', 'else', 'elseif',
	'end', 'false', 'for', 'function', 'goto', 'if',
	'in', 'local', 'nil', 'not', 'or', 'repeat',
	'return', 'then', 'true', 'until', 'while',
}

--- Keywords that end a block
StatListCloseKeywords = createLookup{'end', 'else', 'elseif', 'until'}

--- Unary operators
UnOps = createLookup{'-', 'not', '#'}

return {
	WhiteChars = WhiteChars,
	EscapeLookup = EscapeLookup,
	LowerChars = LowerChars,
	UpperChars = UpperChars,
	Digits = Digits,
	HexDigits = HexDigits,
	Symbols = Symbols,
	Keywords = Keywords,
	StatListCloseKeywords = StatListCloseKeywords,
	UnOps = UnOps
}
end)
Scope=_W(function()
--- Holds variables for one scope
-- This implementation is inefficient. Instead of using hashes,
-- a linear search is used instead to look up variables
-- @module lexer.Scope

local keywords = Constants.Keywords

--- Holds the data for one variable
-- @table Variable
-- @tfield Scope Scope The parent scope
-- @tfield string Name The name of the variable
-- @tfield boolean IsGlobal Is the variable global
-- @tfield boolean CanRename If the variable can be renamed
-- @tfield int References Number of references

--- Holds variables for one scope
-- @type Scope
-- @tfield ?|Scope Parent The parent scope
-- @tfield table Locals A list of locals variables
-- @tfield table Globals A list of global variables
-- @tfield table Children A list of children @{Scope|scopes}

local Scope = {}

--- Add a local to this scope
-- @tparam Variable variable The local object
function Scope:AddLocal(variable)
	table.insert(self.Locals, variable)
end

--- Create a @{Variable} and add it to the scope
-- @tparam string name The name of the local
-- @treturn Variable The created local
function Scope:CreateLocal(name)
	local variable = self:GetLocal(name)
	if variable then return variable end

	variable = {
		Scope = self,
		Name= name,
		IsGlobal = false,
		CanRename = true,
		References = 1,
	}

	self:AddLocal(variable)
	return variable
end

--- Get a local variable
-- @tparam string name The name of the local
-- @treturn ?|Variable The variable
function Scope:GetLocal(name)
	for k, var in pairs(self.Locals) do
		if var.Name == name then return var end
	end

	if self.Parent then
		return self.Parent:GetLocal(name)
	end
end

--- Find an local variable by its old name
-- @tparam string name The old name of the local
-- @treturn ?|Variable The local variable
function Scope:GetOldLocal(name)
	if self.oldLocalNamesMap[name] then
		return self.oldLocalNamesMap[name]
	end
	return self:GetLocal(name)
end

--- Rename a local variable
-- @tparam string|Variable oldName The old variable name
-- @tparam string newName The new variable name
function Scope:RenameLocal(oldName, newName)
	oldName = type(oldName) == 'string' and oldName or oldName.Name
	local found = false
	local var = self:GetLocal(oldName)
	if var then
		var.Name = newName
		self.oldLocalNamesMap[oldName] = var
		found = true
	end
	if not found and self.Parent then
		self.Parent:RenameLocal(oldName, newName)
	end
end

--- Add a global to this scope
-- @tparam Variable name The name of the global
function Scope:AddGlobal(name)
	table.insert(self.Globals, name)
end

--- Create a @{Variable} and add it to the scope
-- @tparam string name The name of the global
-- @treturn Variable The created global
function Scope:CreateGlobal(name)
	local variable = self:GetGlobal(name)
	if variable then return variable end

	variable = {
		Scope = self,
		Name= name,
		IsGlobal = true,
		CanRename = true,
		References = 1,
	}

	self:AddGlobal(variable)
	return variable
end

--- Get a global variable
-- @tparam string name The name of the global
-- @treturn ?|Variable The variable
function Scope:GetGlobal(name)
	for k, v in pairs(self.Globals) do
		if v.Name == name then return v end
	end

	if self.Parent then
		return self.Parent:GetGlobal(name)
	end
end

--- Find a Global by its old name
-- @tparam string name The old name of the global
-- @treturn ?|Variable The variable
function Scope:GetOldGlobal(name)
	if self.oldGlobalNamesMap[name] then
		return self.oldGlobalNamesMap[name]
	end
	return self:GetGlobal(name)
end

--- Rename a global variable
-- @tparam string|Variable oldName The old variable name
-- @tparam string newName The new variable name
function Scope:RenameGlobal(oldName, newName)
	oldName = type(oldName) == 'string' and oldName or oldName.Name
	local found = false
	local var = self:GetGlobal(oldName)
	if var then
		var.Name = newName
		self.oldGlobalNamesMap[oldName] = var
		found = true
	end
	if not found and self.Parent then
		self.Parent:RenameGlobal(oldName, newName)
	end
end

--- Get a variable by name
-- @tparam string name The name of the variable
-- @treturn ?|Variable The found variable
-- @fixme This is a very inefficient implementation, as with @{Scope:GetLocal} and @{Scope:GetGlocal}
function Scope:GetVariable(name)
	return self:GetLocal(name) or self:GetGlobal(name)
end

--- Find an variable by its old name
-- @tparam string name The old name of the variable
-- @treturn ?|Variable The variable
function Scope:GetOldVariable(name)
	return self:GetOldLocal(name) or self:GetOldGlobal(name)
end

--- Rename a variable
-- @tparam string|Variable oldName The old variable name
-- @tparam string newName The new variable name
function Scope:RenameVariable(oldName, newName)
	oldName = type(oldName) == 'string' and oldName or oldName.Name
	if self:GetLocal(oldName) then
		self:RenameLocal(oldName, newName)
	else
		self:RenameGlobal(oldName, newName)
	end
end

--- Get all variables in the scope
-- @treturn table A list of @{Variable|variables}
function Scope:GetAllVariables()
	return self:getVars(true, self:getVars(true))
end

--- Get all variables
-- @tparam boolean top If this values is the 'top' of the function stack
-- @tparam table ret Table to fill with return values (optional)
-- @treturn table The variables
-- @local
function Scope:getVars(top, ret)
	local ret = ret or {}
	if top then
		for k, v in pairs(self.Children) do
			v:getVars(true, ret)
		end
	else
		for k, v in pairs(self.Locals) do
			table.insert(ret, v)
		end
		for k, v in pairs(self.Globals) do
			table.insert(ret, v)
		end
		if self.Parent then
			self.Parent:getVars(false, ret)
		end
	end
	return ret
end

--- Rename all locals to smaller values
-- @tparam string validNameChars All characters that can be used to make a variable name
-- @fixme Some of the string generation happens a lot, this could be looked at
function Scope:ObfuscateLocals(validNameChars)
	-- Use values sorted for letter frequency instead
	local startChars = validNameChars or "etaoinshrdlucmfwypvbgkqjxz_ETAOINSHRDLUCMFWYPVBGKQJXZ"
	local otherChars = validNameChars or "etaoinshrdlucmfwypvbgkqjxz_0123456789ETAOINSHRDLUCMFWYPVBGKQJXZ"

	local startCharsLength, otherCharsLength = #startChars, #otherChars
	local index = 0
	local floor = math.floor
	for _, var in pairs(self.Locals) do
		local name

		repeat
			if index < startCharsLength then
				index = index + 1
				name = startChars:sub(index, index)
			else
				if index < startCharsLength then
					index = index + 1
					name = startChars:sub(index, index)
				else
					local varIndex = floor(index / startCharsLength)
					local offset = index % startCharsLength
					name = startChars:sub(offset, offset)

					while varIndex > 0 do
						offset = varIndex % otherCharsLength
						name = otherChars:sub(offset, offset) .. name
						varIndex = floor(varIndex / otherCharsLength)
					end
					index = index + 1
				end
			end
		until not (keywords[name] or self:GetVariable(name))
		self:RenameLocal(var.Name, name)
	end
end

--- Converts the scope to a string
-- No, it actually just returns '&lt;scope&gt;'
-- @treturn string '&lt;scope&gt;'
function Scope:ToString()
	return '<Scope>'
end

--- Create a new scope
-- @tparam Scope parent The parent scope
-- @treturn Scope The created scope
local function NewScope(parent)
	local scope = setmetatable({
		Parent = parent,
		Locals = { },
		Globals = { },
		oldLocalNamesMap = { },
		oldGlobalNamesMap = { },
		Children = { },
	}, { __index = Scope })

	if parent then
		table.insert(parent.Children, scope)
	end

	return scope
end

return NewScope
end)
TokenList=_W(function()
--- Provides utilities for reading tokens from a 'stream'
-- @module lexer.TokenList

--- Stores a list of tokens
-- @type TokenList
-- @tfield table tokens List of tokens
-- @tfield number pointer Pointer to the current
-- @tfield table savedPointers A save point
local TokenList = {}

--- Get this element in the token list
-- @tparam int offset The offset in the token list
function TokenList:Peek(offset)
	local tokens = self.tokens
	offset = offset or 0
	return tokens[math.min(#tokens, self.pointer+offset)]
end

--- Get the next token in the list
-- @tparam table tokenList Add the token onto this table
-- @treturn Token The token
function TokenList:Get(tokenList)
	local tokens = self.tokens
	local pointer = self.pointer
	local token = tokens[pointer]
	self.pointer = math.min(pointer + 1, #tokens)
	if tokenList then
		table.insert(tokenList, token)
	end
	return token
end

--- Check if the next token is of a type
-- @tparam string type The type to compare it with
-- @treturn bool If the type matches
function TokenList:Is(type)
	return self:Peek().Type == type
end

--- Save position in a stream
function TokenList:Save()
	table.insert(self.savedPointers, self.pointer)
end

--- Remove the last position in the stream
function TokenList:Commit()
	local savedPointers = self.savedPointers
	savedPointers[#savedPointers] = nil
end

--- Restore to the previous save point
function TokenList:Restore()
	local savedPointers = self.savedPointers
	local sPLength = #savedPointers
	self.pointer = savedP[sPLength]
	savedPointers[sPLength] = nil
end

--- Check if the next token is a symbol and return it
-- @tparam string symbol Symbol to check (Optional)
-- @tparam table tokenList Add the token onto this table
-- @treturn[0] ?|token If symbol is not specified, return the token
-- @treturn[1] boolean If symbol is specified, return true if it matches
function TokenList:ConsumeSymbol(symbol, tokenList)
	local token = self:Peek()
	if token.Type == 'Symbol' then
		if symbol then
			if token.Data == symbol then
				self:Get(tokenList)
				return true
			else
				return nil
			end
		else
			self:Get(tokenList)
			return token
		end
	else
		return nil
	end
end

--- Check if the next token is a keyword and return it
-- @tparam string kw Keyword to check (Optional)
-- @tparam table tokenList Add the token onto this table
-- @treturn[0] ?|token If kw is not specified, return the token
-- @treturn[1] boolean If kw is specified, return true if it matches
function TokenList:ConsumeKeyword(kw, tokenList)
	local token = self:Peek()
	if token.Type == 'Keyword' and token.Data == kw then
		self:Get(tokenList)
		return true
	else
		return nil
	end
end

--- Check if the next token matches is a keyword
-- @tparam string kw The particular keyword
-- @treturn boolean If it matches or not
function TokenList:IsKeyword(kw)
	local token = self:Peek()
	return token.Type == 'Keyword' and token.Data == kw
end

--- Check if the next token matches is a symbol
-- @tparam string symbol The particular symbol
-- @treturn boolean If it matches or not
function TokenList:IsSymbol(symbol)
	local token = self:Peek()
	return token.Type == 'Symbol' and token.Data == symbol
end

--- Check if the next token is an end of file
-- @treturn boolean If the next token is an end of file
function TokenList:IsEof()
	return self:Peek().Type == 'Eof'
end

--- Produce a string off all tokens
-- @tparam boolean includeLeading Include the leading whitespace
-- @treturn string The resulting string
function TokenList:Print(includeLeading)
	includeLeading = (includeLeading == nil and true or includeLeading)

	local out = ""
	for _, token in ipairs(self.tokens) do
		if includeLeading then
			for _, whitespace in ipairs(token.LeadingWhite) do
				out = out .. whitespace:Print() .. "\n"
			end
		end
		out = out .. token:Print() .. "\n"
	end

	return out
end

return TokenList
end)
Parse=_W(function()
--- The main lua parser and lexer.
-- LexLua returns a Lua token stream, with tokens that preserve
-- all whitespace formatting information.
-- ParseLua returns an AST, internally relying on LexLua.
-- @module lexer.Parse

local createLookup = Utils.CreateLookup

local lowerChars = Constants.LowerChars
local upperChars = Constants.UpperChars
local digits = Constants.Digits
local symbols = Constants.Symbols
local hexDigits = Constants.HexDigits
local keywords = Constants.Keywords
local statListCloseKeywords = Constants.StatListCloseKeywords
local unops = Constants.UnOps
local setmeta = setmetatable

--- One token
-- @table Token
-- @tparam string Type The token type
-- @param Data Data about the token
-- @tparam string CommentType The type of comment  (Optional)
-- @tparam number Line Line number (Optional)
-- @tparam number Char Character number (Optional)
local Token = {}

--- Creates a string representation of the token
-- @treturn string The resulting string
function Token:Print()
	return "<"..(self.Type .. string.rep(' ', math.max(3, 12-#self.Type))).."  "..(self.Data or '').." >"
end

local tokenMeta = { __index = Token }

--- Create a list of @{Token|tokens} from a Lua source
-- @tparam string src Lua source code
-- @treturn TokenList The list of @{Token|tokens}
local function LexLua(src)
	--token dump
	local tokens = {}

	do -- Main bulk of the work
		--line / char / pointer tracking
		local pointer = 1
		local line = 1
		local char = 1

		--get / peek functions
		local function get()
			local c = src:sub(pointer,pointer)
			if c == '\n' then
				char = 1
				line = line + 1
			else
				char = char + 1
			end
			pointer = pointer + 1
			return c
		end
		local function peek(n)
			n = n or 0
			return src:sub(pointer+n,pointer+n)
		end
		local function consume(chars)
			local c = peek()
			for i = 1, #chars do
				if c == chars:sub(i,i) then return get() end
			end
		end

		--shared stuff
		local function generateError(err)
			error(">> :"..line..":"..char..": "..err, 0)
		end

		local function tryGetLongString()
			local start = pointer
			if peek() == '[' then
				local equalsCount = 0
				local depth = 1
				while peek(equalsCount+1) == '=' do
					equalsCount = equalsCount + 1
				end
				if peek(equalsCount+1) == '[' then
					--start parsing the string. Strip the starting bit
					for _ = 0, equalsCount+1 do get() end

					--get the contents
					local contentStart = pointer
					while true do
						--check for eof
						if peek() == '' then
							generateError("Expected `]"..string.rep('=', equalsCount).."]` near <eof>.", 3)
						end

						--check for the end
						local foundEnd = true
						if peek() == ']' then
							for i = 1, equalsCount do
								if peek(i) ~= '=' then foundEnd = false end
							end
							if peek(equalsCount+1) ~= ']' then
								foundEnd = false
							end
						else
							if peek() == '[' then
								-- is there an embedded long string?
								local embedded = true
								for i = 1, equalsCount do
									if peek(i) ~= '=' then
										embedded = false
										break
									end
								end
								if peek(equalsCount + 1) == '[' and embedded then
									-- oh look, there was
									depth = depth + 1
									for i = 1, (equalsCount + 2) do
										get()
									end
								end
							end
							foundEnd = false
						end

						if foundEnd then
							depth = depth - 1
							if depth == 0 then
								break
							else
								for i = 1, equalsCount + 2 do
									get()
								end
							end
						else
							get()
						end
					end

					--get the interior string
					local contentString = src:sub(contentStart, pointer-1)

					--found the end. Get rid of the trailing bit
					for i = 0, equalsCount+1 do get() end

					--get the exterior string
					local longString = src:sub(start, pointer-1)

					--return the stuff
					return contentString, longString
				else
					return nil
				end
			else
				return nil
			end
		end

		--main token emitting loop
		while true do
			--get leading whitespace. The leading whitespace will include any comments
			--preceding the token. This prevents the parser needing to deal with comments
			--separately.
			local leading = { }
			local leadingWhite = ''
			local longStr = false
			while true do
				local c = peek()
				if c == '#' and peek(1) == '!' and line == 1 then
					-- #! shebang for linux scripts
					get()
					get()
					leadingWhite = "#!"
					while peek() ~= '\n' and peek() ~= '' do
						leadingWhite = leadingWhite .. get()
					end

					table.insert(leading, setmeta({
						Type = 'Comment',
						CommentType = 'Shebang',
						Data = leadingWhite,
						Line = line,
						Char = char
					}, tokenMeta))
					leadingWhite = ""
				end
				if c == ' ' or c == '\t' then
					--whitespace
					--leadingWhite = leadingWhite..get()
					local c2 = get() -- ignore whitespace
					table.insert(leading, setmeta({
						Type = 'Whitespace',
						Line = line,
						Char = char,
						Data = c2
					}, tokenMeta))
				elseif c == '\n' or c == '\r' then
					local nl = get()
					if leadingWhite ~= "" then
						table.insert(leading, setmeta({
							Type = 'Comment',
							CommentType = longStr and 'LongComment' or 'Comment',
							Data = leadingWhite,
							Line = line,
							Char = char,
						}, tokenMeta))
						leadingWhite = ""
					end
					table.insert(leading, setmeta({
						Type = 'Whitespace',
						Line = line,
						Char = char,
						Data = nl,
					}, tokenMeta))
				elseif c == '-' and peek(1) == '-' then
					--comment
					get()
					get()
					leadingWhite = leadingWhite .. '--'
					local _, wholeText = tryGetLongString()
					if wholeText then
						leadingWhite = leadingWhite..wholeText
						longStr = true
					else
						while peek() ~= '\n' and peek() ~= '' do
							leadingWhite = leadingWhite..get()
						end
					end
				else
					break
				end
			end
			if leadingWhite ~= "" then
				table.insert(leading, setmeta(
				{
					Type = 'Comment',
					CommentType = longStr and 'LongComment' or 'Comment',
					Data = leadingWhite,
					Line = line,
					Char = char,
				}, tokenMeta))
			end

			--get the initial char
			local thisLine = line
			local thisChar = char
			local errorAt = ":"..line..":"..char..":> "
			local c = peek()

			--symbol to emit
			local toEmit = nil

			--branch on type
			if c == '' then
				--eof
				toEmit = { Type = 'Eof' }

			elseif upperChars[c] or lowerChars[c] or c == '_' then
				--ident or keyword
				local start = pointer
				repeat
					get()
					c = peek()
				until not (upperChars[c] or lowerChars[c] or digits[c] or c == '_')
				local dat = src:sub(start, pointer-1)
				if keywords[dat] then
					toEmit = {Type = 'Keyword', Data = dat}
				else
					toEmit = {Type = 'Ident', Data = dat}
				end

			elseif digits[c] or (peek() == '.' and digits[peek(1)]) then
				--number const
				local start = pointer
				if c == '0' and peek(1) == 'x' then
					get();get()
					while hexDigits[peek()] do get() end
					if consume('Pp') then
						consume('+-')
						while digits[peek()] do get() end
					end
				else
					while digits[peek()] do get() end
					if consume('.') then
						while digits[peek()] do get() end
					end
					if consume('Ee') then
						consume('+-')
						while digits[peek()] do get() end
					end
				end
				toEmit = {Type = 'Number', Data = src:sub(start, pointer-1)}

			elseif c == '\'' or c == '\"' then
				local start = pointer
				--string const
				local delim = get()
				local contentStart = pointer
				while true do
					local c = get()
					if c == '\\' then
						get() --get the escape char
					elseif c == delim then
						break
					elseif c == '' then
						generateError("Unfinished string near <eof>")
					end
				end
				local content = src:sub(contentStart, pointer-2)
				local constant = src:sub(start, pointer-1)
				toEmit = {Type = 'String', Data = constant, Constant = content}

			elseif c == '[' then
				local content, wholetext = tryGetLongString()
				if wholetext then
					toEmit = {Type = 'String', Data = wholetext, Constant = content}
				else
					get()
					toEmit = {Type = 'Symbol', Data = '['}
				end

			elseif consume('>=<') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = c..'='}
				else
					toEmit = {Type = 'Symbol', Data = c}
				end

			elseif consume('~') then
				if consume('=') then
					toEmit = {Type = 'Symbol', Data = '~='}
				else
					generateError("Unexpected symbol `~` in source.", 2)
				end

			elseif consume('.') then
				if consume('.') then
					if consume('.') then
						toEmit = {Type = 'Symbol', Data = '...'}
					else
						toEmit = {Type = 'Symbol', Data = '..'}
					end
				else
					toEmit = {Type = 'Symbol', Data = '.'}
				end

			elseif consume(':') then
				if consume(':') then
					toEmit = {Type = 'Symbol', Data = '::'}
				else
					toEmit = {Type = 'Symbol', Data = ':'}
				end

			elseif symbols[c] then
				get()
				toEmit = {Type = 'Symbol', Data = c}

			else
				local contents, all = tryGetLongString()
				if contents then
					toEmit = {Type = 'String', Data = all, Constant = contents}
				else
					generateError("Unexpected Symbol `"..c.."` in source.", 2)
				end
			end

			--add the emitted symbol, after adding some common data
			toEmit.LeadingWhite = leading -- table of leading whitespace/comments

			toEmit.Line = thisLine
			toEmit.Char = thisChar
			tokens[#tokens+1] = setmeta(toEmit, tokenMeta)

			--halt after eof has been emitted
			if toEmit.Type == 'Eof' then break end
		end
	end

	--public interface:
	local tokenList = setmetatable({
		tokens = tokens,
		savedPointers = {},
		pointer = 1
	}, {__index = TokenList})

	return tokenList
end

--- Create a AST tree from a Lua Source
-- @tparam TokenList tok List of tokens from @{LexLua}
-- @treturn table The AST tree
local function ParseLua(tok)
	--- Generate an error
	-- @tparam string msg The error message
	-- @raise The produces error message
	local function GenerateError(msg)
		local err = ">> :"..tok:Peek().Line..":"..tok:Peek().Char..": "..msg.."\n"
		--find the line
		local lineNum = 0
		if type(src) == 'string' then
			for line in src:gmatch("[^\n]*\n?") do
				if line:sub(-1,-1) == '\n' then line = line:sub(1,-2) end
				lineNum = lineNum+1
				if lineNum == tok:Peek().Line then
					err = err..">> `"..line:gsub('\t','    ').."`\n"
					for i = 1, tok:Peek().Char do
						local c = line:sub(i,i)
						if c == '\t' then
							err = err..'    '
						else
							err = err..' '
						end
					end
					err = err.."   ^^^^"
					break
				end
			end
		end
		error(err)
	end

	local ParseExpr,
	      ParseStatementList,
	      ParseSimpleExpr,
	      ParsePrimaryExpr,
	      ParseSuffixedExpr

	--- Parse the function definition and its arguments
	-- @tparam Scope.Scope scope The current scope
	-- @tparam table tokenList A table to fill with tokens
	-- @treturn Node A function Node
	local function ParseFunctionArgsAndBody(scope, tokenList)
		local funcScope = Scope(scope)
		if not tok:ConsumeSymbol('(', tokenList) then
			GenerateError("`(` expected.")
		end

		--arg list
		local argList = {}
		local isVarArg = false
		while not tok:ConsumeSymbol(')', tokenList) do
			if tok:Is('Ident') then
				local arg = funcScope:CreateLocal(tok:Get(tokenList).Data)
				argList[#argList+1] = arg
				if not tok:ConsumeSymbol(',', tokenList) then
					if tok:ConsumeSymbol(')', tokenList) then
						break
					else
						GenerateError("`)` expected.")
					end
				end
			elseif tok:ConsumeSymbol('...', tokenList) then
				isVarArg = true
				if not tok:ConsumeSymbol(')', tokenList) then
					GenerateError("`...` must be the last argument of a function.")
				end
				break
			else
				GenerateError("Argument name or `...` expected")
			end
		end

		--body
		local body = ParseStatementList(funcScope)

		--end
		if not tok:ConsumeKeyword('end', tokenList) then
			GenerateError("`end` expected after function body")
		end

		return {
			AstType   = 'Function',
			Scope     = funcScope,
			Arguments = argList,
			Body      = body,
			VarArg    = isVarArg,
			Tokens    = tokenList,
		}
	end

	--- Parse a simple expression
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node the resulting node
	function ParsePrimaryExpr(scope)
		local tokenList = {}

		if tok:ConsumeSymbol('(', tokenList) then
			local ex = ParseExpr(scope)
			if not tok:ConsumeSymbol(')', tokenList) then
				GenerateError("`)` Expected.")
			end

			return {
				AstType = 'Parentheses',
				Inner   = ex,
				Tokens  = tokenList,
			}

		elseif tok:Is('Ident') then
			local id = tok:Get(tokenList)
			local var = scope:GetLocal(id.Data)
			if not var then
				var = scope:GetGlobal(id.Data)
				if not var then
					var = scope:CreateGlobal(id.Data)
				else
					var.References = var.References + 1
				end
			else
				var.References = var.References + 1
			end

			return {
				AstType  = 'VarExpr',
				Name     = id.Data,
				Variable = var,
				Tokens   = tokenList,
			}
		else
			GenerateError("primary expression expected")
		end
	end

	--- Parse some table related expressions
	-- @tparam Scope.Scope scope The current scope
	-- @tparam boolean onlyDotColon Only allow '.' or ':' nodes
	-- @treturn Node The resulting node
	function ParseSuffixedExpr(scope, onlyDotColon)
		--base primary expression
		local prim = ParsePrimaryExpr(scope)

		while true do
			local tokenList = {}

			if tok:IsSymbol('.') or tok:IsSymbol(':') then
				local symb = tok:Get(tokenList).Data
				if not tok:Is('Ident') then
					GenerateError("<Ident> expected.")
				end
				local id = tok:Get(tokenList)

				prim = {
					AstType  = 'MemberExpr',
					Base     = prim,
					Indexer  = symb,
					Ident    = id,
					Tokens   = tokenList,
				}

			elseif not onlyDotColon and tok:ConsumeSymbol('[', tokenList) then
				local ex = ParseExpr(scope)
				if not tok:ConsumeSymbol(']', tokenList) then
					GenerateError("`]` expected.")
				end

				prim = {
					AstType  = 'IndexExpr',
					Base     = prim,
					Index    = ex,
					Tokens   = tokenList,
				}

			elseif not onlyDotColon and tok:ConsumeSymbol('(', tokenList) then
				local args = {}
				while not tok:ConsumeSymbol(')', tokenList) do
					args[#args+1] = ParseExpr(scope)
					if not tok:ConsumeSymbol(',', tokenList) then
						if tok:ConsumeSymbol(')', tokenList) then
							break
						else
							GenerateError("`)` Expected.")
						end
					end
				end

				prim = {
					AstType   = 'CallExpr',
					Base      = prim,
					Arguments = args,
					Tokens    = tokenList,
				}

			elseif not onlyDotColon and tok:Is('String') then
				--string call
				prim = {
					AstType    = 'StringCallExpr',
					Base       = prim,
					Arguments  = { tok:Get(tokenList) },
					Tokens     = tokenList,
				}

			elseif not onlyDotColon and tok:IsSymbol('{') then
				--table call
				local ex = ParseSimpleExpr(scope)
				-- FIX: ParseExpr(scope) parses the table AND and any following binary expressions.
				-- We just want the table

				prim = {
					AstType   = 'TableCallExpr',
					Base      = prim,
					Arguments = { ex },
					Tokens    = tokenList,
				}

			else
				break
			end
		end
		return prim
	end

	--- Parse a simple expression (strings, numbers, booleans, varargs)
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseSimpleExpr(scope)
		local tokenList = {}

		if tok:Is('Number') then
			return {
				AstType = 'NumberExpr',
				Value   = tok:Get(tokenList),
				Tokens  = tokenList,
			}

		elseif tok:Is('String') then
			return {
				AstType = 'StringExpr',
				Value   = tok:Get(tokenList),
				Tokens  = tokenList,
			}

		elseif tok:ConsumeKeyword('nil', tokenList) then
			return {
				AstType = 'NilExpr',
				Tokens  = tokenList,
			}

		elseif tok:IsKeyword('false') or tok:IsKeyword('true') then
			return {
				AstType = 'BooleanExpr',
				Value   = (tok:Get(tokenList).Data == 'true'),
				Tokens  = tokenList,
			}

		elseif tok:ConsumeSymbol('...', tokenList) then
			return {
				AstType  = 'DotsExpr',
				Tokens   = tokenList,
			}

		elseif tok:ConsumeSymbol('{', tokenList) then
			local entryList = {}
			local v = {
				AstType = 'ConstructorExpr',
				EntryList = entryList,
				Tokens  = tokenList,
			}

			while true do
				if tok:IsSymbol('[', tokenList) then
					--key
					tok:Get(tokenList)
					local key = ParseExpr(scope)
					if not tok:ConsumeSymbol(']', tokenList) then
						GenerateError("`]` Expected")
					end
					if not tok:ConsumeSymbol('=', tokenList) then
						GenerateError("`=` Expected")
					end
					local value = ParseExpr(scope)
					entryList[#entryList+1] = {
						Type  = 'Key',
						Key   = key,
						Value = value,
					}

				elseif tok:Is('Ident') then
					--value or key
					local lookahead = tok:Peek(1)
					if lookahead.Type == 'Symbol' and lookahead.Data == '=' then
						--we are a key
						local key = tok:Get(tokenList)
						if not tok:ConsumeSymbol('=', tokenList) then
							GenerateError("`=` Expected")
						end
						local value = ParseExpr(scope)
						entryList[#entryList+1] = {
							Type  = 'KeyString',
							Key   = key.Data,
							Value = value,
						}

					else
						--we are a value
						local value = ParseExpr(scope)
						entryList[#entryList+1] = {
							Type = 'Value',
							Value = value,
						}

					end
				elseif tok:ConsumeSymbol('}', tokenList) then
					break

				else
					--value
					local value = ParseExpr(scope)
					entryList[#entryList+1] = {
						Type = 'Value',
						Value = value,
					}
				end

				if tok:ConsumeSymbol(';', tokenList) or tok:ConsumeSymbol(',', tokenList) then
					--all is good
				elseif tok:ConsumeSymbol('}', tokenList) then
					break
				else
					GenerateError("`}` or table entry Expected")
				end
			end
			return v

		elseif tok:ConsumeKeyword('function', tokenList) then
			local func = ParseFunctionArgsAndBody(scope, tokenList)

			func.IsLocal = true
			return func

		else
			return ParseSuffixedExpr(scope)
		end
	end

	local unopprio = 8
	local priority = {
		['+'] = {6,6},
		['-'] = {6,6},
		['%'] = {7,7},
		['/'] = {7,7},
		['*'] = {7,7},
		['^'] = {10,9},
		['..'] = {5,4},
		['=='] = {3,3},
		['<'] = {3,3},
		['<='] = {3,3},
		['~='] = {3,3},
		['>'] = {3,3},
		['>='] = {3,3},
		['and'] = {2,2},
		['or'] = {1,1},
	}

	--- Parse an expression
	-- @tparam Skcope.Scope scope The current scope
	-- @tparam int level Current level (Optional)
	-- @treturn Node The resulting node
	function ParseExpr(scope, level)
		level = level or 0
		--base item, possibly with unop prefix
		local exp
		if unops[tok:Peek().Data] then
			local tokenList = {}
			local op = tok:Get(tokenList).Data
			exp = ParseExpr(scope, unopprio)

			local nodeEx = {
				AstType = 'UnopExpr',
				Rhs     = exp,
				Op      = op,
				OperatorPrecedence = unopprio,
				Tokens  = tokenList,
			}

			exp = nodeEx
		else
			exp = ParseSimpleExpr(scope)
		end

		--next items in chain
		while true do
			local prio = priority[tok:Peek().Data]
			if prio and prio[1] > level then
				local tokenList = {}
				local op = tok:Get(tokenList).Data
				local rhs = ParseExpr(scope, prio[2])

				local nodeEx = {
					AstType = 'BinopExpr',
					Lhs     = exp,
					Op      = op,
					OperatorPrecedence = prio[1],
					Rhs     = rhs,
					Tokens  = tokenList,
				}

				exp = nodeEx
			else
				break
			end
		end

		return exp
	end

	--- Parse a statement (if, for, while, etc...)
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	local function ParseStatement(scope)
		local stat = nil
		local tokenList = {}
		if tok:ConsumeKeyword('if', tokenList) then
			--setup
			local clauses = {}
			local nodeIfStat = {
				AstType = 'IfStatement',
				Clauses = clauses,
			}
			--clauses
			repeat
				local nodeCond = ParseExpr(scope)

				if not tok:ConsumeKeyword('then', tokenList) then
					GenerateError("`then` expected.")
				end
				local nodeBody = ParseStatementList(scope)
				clauses[#clauses+1] = {
					Condition = nodeCond,
					Body = nodeBody,
				}
			until not tok:ConsumeKeyword('elseif', tokenList)

			--else clause
			if tok:ConsumeKeyword('else', tokenList) then
				local nodeBody = ParseStatementList(scope)
				clauses[#clauses+1] = {
					Body = nodeBody,
				}
			end

			--end
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			nodeIfStat.Tokens = tokenList
			stat = nodeIfStat
		elseif tok:ConsumeKeyword('while', tokenList) then
			--condition
			local nodeCond = ParseExpr(scope)

			--do
			if not tok:ConsumeKeyword('do', tokenList) then
				return GenerateError("`do` expected.")
			end

			--body
			local nodeBody = ParseStatementList(scope)

			--end
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			--return
			stat = {
				AstType = 'WhileStatement',
				Condition = nodeCond,
				Body      = nodeBody,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('do', tokenList) then
			--do block
			local nodeBlock = ParseStatementList(scope)
			if not tok:ConsumeKeyword('end', tokenList) then
				GenerateError("`end` expected.")
			end

			stat = {
				AstType = 'DoStatement',
				Body    = nodeBlock,
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('for', tokenList) then
			--for block
			if not tok:Is('Ident') then
				GenerateError("<ident> expected.")
			end
			local baseVarName = tok:Get(tokenList)
			if tok:ConsumeSymbol('=', tokenList) then
				--numeric for
				local forScope = Scope(scope)
				local forVar = forScope:CreateLocal(baseVarName.Data)

				local startEx = ParseExpr(scope)
				if not tok:ConsumeSymbol(',', tokenList) then
					GenerateError("`,` Expected")
				end
				local endEx = ParseExpr(scope)
				local stepEx
				if tok:ConsumeSymbol(',', tokenList) then
					stepEx = ParseExpr(scope)
				end
				if not tok:ConsumeKeyword('do', tokenList) then
					GenerateError("`do` expected")
				end

				local body = ParseStatementList(forScope)
				if not tok:ConsumeKeyword('end', tokenList) then
					GenerateError("`end` expected")
				end

				stat = {
					AstType  = 'NumericForStatement',
					Scope    = forScope,
					Variable = forVar,
					Start    = startEx,
					End      = endEx,
					Step     = stepEx,
					Body     = body,
					Tokens   = tokenList,
				}
			else
				--generic for
				local forScope = Scope(scope)

				local varList = { forScope:CreateLocal(baseVarName.Data) }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						GenerateError("for variable expected.")
					end
					varList[#varList+1] = forScope:CreateLocal(tok:Get(tokenList).Data)
				end
				if not tok:ConsumeKeyword('in', tokenList) then
					GenerateError("`in` expected.")
				end
				local generators = {ParseExpr(scope)}
				while tok:ConsumeSymbol(',', tokenList) do
					generators[#generators+1] = ParseExpr(scope)
				end

				if not tok:ConsumeKeyword('do', tokenList) then
					GenerateError("`do` expected.")
				end

				local body = ParseStatementList(forScope)
				if not tok:ConsumeKeyword('end', tokenList) then
					GenerateError("`end` expected.")
				end

				stat = {
					AstType      = 'GenericForStatement',
					Scope        = forScope,
					VariableList = varList,
					Generators   = generators,
					Body         = body,
					Tokens       = tokenList,
				}
			end
		elseif tok:ConsumeKeyword('repeat', tokenList) then
			local body = ParseStatementList(scope)

			if not tok:ConsumeKeyword('until', tokenList) then
				GenerateError("`until` expected.")
			end

			cond = ParseExpr(body.Scope)

			stat = {
				AstType   = 'RepeatStatement',
				Condition = cond,
				Body      = body,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('function', tokenList) then
			if not tok:Is('Ident') then
				GenerateError("Function name expected")
			end
			local name = ParseSuffixedExpr(scope, true) --true => only dots and colons

			local func = ParseFunctionArgsAndBody(scope, tokenList)

			func.IsLocal = false
			func.Name    = name
			stat = func
		elseif tok:ConsumeKeyword('local', tokenList) then
			if tok:Is('Ident') then
				local varList = { tok:Get(tokenList).Data }
				while tok:ConsumeSymbol(',', tokenList) do
					if not tok:Is('Ident') then
						GenerateError("local var name expected")
					end
					varList[#varList+1] = tok:Get(tokenList).Data
				end

				local initList = {}
				if tok:ConsumeSymbol('=', tokenList) then
					repeat
						initList[#initList+1] = ParseExpr(scope)
					until not tok:ConsumeSymbol(',', tokenList)
				end

				--now patch var list
				--we can't do this before getting the init list, because the init list does not
				--have the locals themselves in scope.
				for i, v in pairs(varList) do
					varList[i] = scope:CreateLocal(v)
				end

				stat = {
					AstType   = 'LocalStatement',
					LocalList = varList,
					InitList  = initList,
					Tokens    = tokenList,
				}

			elseif tok:ConsumeKeyword('function', tokenList) then
				if not tok:Is('Ident') then
					GenerateError("Function name expected")
				end
				local name = tok:Get(tokenList).Data
				local localVar = scope:CreateLocal(name)

				local func = ParseFunctionArgsAndBody(scope, tokenList)

				func.Name    = localVar
				func.IsLocal = true
				stat = func

			else
				GenerateError("local var or function def expected")
			end
		elseif tok:ConsumeSymbol('::', tokenList) then
			if not tok:Is('Ident') then
				GenerateError('Label name expected')
			end
			local label = tok:Get(tokenList).Data
			if not tok:ConsumeSymbol('::', tokenList) then
				GenerateError("`::` expected")
			end
			stat = {
				AstType = 'LabelStatement',
				Label   = label,
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('return', tokenList) then
			local exList = {}
			if not tok:IsKeyword('end') then
				-- Use PCall as this may produce an error
				local st, firstEx = pcall(function() return ParseExpr(scope) end)
				if st then
					exList[1] = firstEx
					while tok:ConsumeSymbol(',', tokenList) do
						exList[#exList+1] = ParseExpr(scope)
					end
				end
			end
			stat = {
				AstType   = 'ReturnStatement',
				Arguments = exList,
				Tokens    = tokenList,
			}
		elseif tok:ConsumeKeyword('break', tokenList) then
			stat = {
				AstType = 'BreakStatement',
				Tokens  = tokenList,
			}
		elseif tok:ConsumeKeyword('goto', tokenList) then
			if not tok:Is('Ident') then
				GenerateError("Label expected")
			end
			local label = tok:Get(tokenList).Data
			stat = {
				AstType = 'GotoStatement',
				Label   = label,
				Tokens  = tokenList,
			}
		else
			--statementParseExpr
			local suffixed = ParseSuffixedExpr(scope)

			--assignment or call?
			if tok:IsSymbol(',') or tok:IsSymbol('=') then
				--check that it was not parenthesized, making it not an lvalue
				if (suffixed.ParenCount or 0) > 0 then
					GenerateError("Can not assign to parenthesized expression, is not an lvalue")
				end

				--more processing needed
				local lhs = { suffixed }
				while tok:ConsumeSymbol(',', tokenList) do
					lhs[#lhs+1] = ParseSuffixedExpr(scope)
				end

				--equals
				if not tok:ConsumeSymbol('=', tokenList) then
					GenerateError("`=` Expected.")
				end

				--rhs
				local rhs = {ParseExpr(scope)}
				while tok:ConsumeSymbol(',', tokenList) do
					rhs[#rhs+1] = ParseExpr(scope)
				end

				--done
				stat = {
					AstType = 'AssignmentStatement',
					Lhs     = lhs,
					Rhs     = rhs,
					Tokens  = tokenList,
				}

			elseif suffixed.AstType == 'CallExpr' or
				   suffixed.AstType == 'TableCallExpr' or
				   suffixed.AstType == 'StringCallExpr'
			then
				--it's a call statement
				stat = {
					AstType    = 'CallStatement',
					Expression = suffixed,
					Tokens     = tokenList,
				}
			else
				GenerateError("Assignment Statement Expected")
			end
		end

		if tok:IsSymbol(';') then
			stat.Semicolon = tok:Get( stat.Tokens )
		end
		return stat
	end

	--- Parse a a list of statements
	-- @tparam Scope.Scope scope The current scope
	-- @treturn Node The resulting node
	function ParseStatementList(scope)
		local body = {}
		local nodeStatlist   = {
			Scope   = Scope(scope),
			AstType = 'Statlist',
			Body    = body,
			Tokens  = {},
		}

		while not statListCloseKeywords[tok:Peek().Data] and not tok:IsEof() do
			local nodeStatement = ParseStatement(nodeStatlist.Scope)
			--stats[#stats+1] = nodeStatement
			body[#body + 1] = nodeStatement
		end

		if tok:IsEof() then
			local nodeEof = {}
			nodeEof.AstType = 'Eof'
			nodeEof.Tokens  = { tok:Get() }
			body[#body + 1] = nodeEof
		end

		--nodeStatlist.Body = stats
		return nodeStatlist
	end

	return ParseStatementList(Scope())
end

--- @export
return { LexLua = LexLua, ParseLua = ParseLua }
end)
Rebuild=_W(function()
--- Rebuild source code from an AST
-- Does not preserve whitespace
-- @module lexer.Rebuild

local lowerChars = Constants.LowerChars
local upperChars = Constants.UpperChars
local digits = Constants.Digits
local symbols = Constants.Symbols

--- Join two statements together
-- @tparam string left The left statement
-- @tparam string right The right statement
-- @tparam string sep The string used to separate the characters
-- @treturn string The joined strings
local function JoinStatements(left, right, sep)
	sep = sep or ' '
	local leftEnd, rightStart = left:sub(-1,-1), right:sub(1,1)
	if upperChars[leftEnd] or lowerChars[leftEnd] or leftEnd == '_' then
		if not (rightStart == '_' or upperChars[rightStart] or lowerChars[rightStart] or digits[rightStart]) then
			--rightStart is left symbol, can join without seperation
			return left .. right
		else
			return left .. sep .. right
		end
	elseif digits[leftEnd] then
		if rightStart == '(' then
			--can join statements directly
			return left .. right
		elseif symbols[rightStart] then
			return left .. right
		else
			return left .. sep .. right
		end
	elseif leftEnd == '' then
		return left .. right
	else
		if rightStart == '(' then
			--don't want to accidentally call last statement, can't join directly
			return left .. sep .. right
		else
			return left .. right
		end
	end
end

--- Returns the minified version of an AST. Operations which are performed:
--  - All comments and whitespace are ignored
--  - All local variables are renamed
-- @tparam Node ast The AST tree
-- @treturn string The minified string
-- @todo Ability to control minification level
local function Minify(ast)
	local formatStatlist, formatExpr
	local count = 0
	local function joinStatements(left, right, set)
		return JoinStatements(left, right, sep)
	end

	formatExpr = function(expr, precedence)
		local precedence = precedence or 0
		local currentPrecedence = 0
		local skipParens = false
		local out = ""
		if expr.AstType == 'VarExpr' then
			if expr.Variable then
				out = out..expr.Variable.Name
			else
				out = out..expr.Name
			end

		elseif expr.AstType == 'NumberExpr' then
			out = out..expr.Value.Data

		elseif expr.AstType == 'StringExpr' then
			out = out..expr.Value.Data

		elseif expr.AstType == 'BooleanExpr' then
			out = out..tostring(expr.Value)

		elseif expr.AstType == 'NilExpr' then
			out = joinStatements(out, "nil")

		elseif expr.AstType == 'BinopExpr' then
			currentPrecedence = expr.OperatorPrecedence
			out = joinStatements(out, formatExpr(expr.Lhs, currentPrecedence))
			out = joinStatements(out, expr.Op)
			out = joinStatements(out, formatExpr(expr.Rhs))
			if expr.Op == '^' or expr.Op == '..' then
				currentPrecedence = currentPrecedence - 1
			end

			if currentPrecedence < precedence then
				skipParens = false
			else
				skipParens = true
			end
		elseif expr.AstType == 'UnopExpr' then
			out = joinStatements(out, expr.Op)
			out = joinStatements(out, formatExpr(expr.Rhs))

		elseif expr.AstType == 'DotsExpr' then
			out = out.."..."

		elseif expr.AstType == 'CallExpr' then
			out = out..formatExpr(expr.Base)
			out = out.."("
			for i = 1, #expr.Arguments do
				out = out..formatExpr(expr.Arguments[i])
				if i ~= #expr.Arguments then
					out = out..","
				end
			end
			out = out..")"

		elseif expr.AstType == 'TableCallExpr' then
			out = out..formatExpr(expr.Base)
			out = out..formatExpr(expr.Arguments[1])

		elseif expr.AstType == 'StringCallExpr' then
			out = out..formatExpr(expr.Base)
			out = out..expr.Arguments[1].Data

		elseif expr.AstType == 'IndexExpr' then
			out = out..formatExpr(expr.Base).."["..formatExpr(expr.Index).."]"

		elseif expr.AstType == 'MemberExpr' then
			out = out..formatExpr(expr.Base)..expr.Indexer..expr.Ident.Data

		elseif expr.AstType == 'Function' then
			expr.Scope:ObfuscateLocals()
			out = out.."function("
			if #expr.Arguments > 0 then
				for i = 1, #expr.Arguments do
					out = out..expr.Arguments[i].Name
					if i ~= #expr.Arguments then
						out = out..","
					elseif expr.VarArg then
						out = out..",..."
					end
				end
			elseif expr.VarArg then
				out = out.."..."
			end
			out = out..")"
			out = joinStatements(out, formatStatlist(expr.Body))
			out = joinStatements(out, "end")

		elseif expr.AstType == 'ConstructorExpr' then
			out = out.."{"
			for i = 1, #expr.EntryList do
				local entry = expr.EntryList[i]
				if entry.Type == 'Key' then
					out = out.."["..formatExpr(entry.Key).."]="..formatExpr(entry.Value)
				elseif entry.Type == 'Value' then
					out = out..formatExpr(entry.Value)
				elseif entry.Type == 'KeyString' then
					out = out..entry.Key.."="..formatExpr(entry.Value)
				end
				if i ~= #expr.EntryList then
					out = out..","
				end
			end
			out = out.."}"

		elseif expr.AstType == 'Parentheses' then
			out = out.."("..formatExpr(expr.Inner)..")"

		end
		if not skipParens then
			out = string.rep('(', expr.ParenCount or 0) .. out
			out = out .. string.rep(')', expr.ParenCount or 0)
		end
		return out
	end

	local formatStatement = function(statement)
		local out = ''
		if statement.AstType == 'AssignmentStatement' then
			for i = 1, #statement.Lhs do
				out = out..formatExpr(statement.Lhs[i])
				if i ~= #statement.Lhs then
					out = out..","
				end
			end
			if #statement.Rhs > 0 then
				out = out.."="
				for i = 1, #statement.Rhs do
					out = out..formatExpr(statement.Rhs[i])
					if i ~= #statement.Rhs then
						out = out..","
					end
				end
			end

		elseif statement.AstType == 'CallStatement' then
			out = formatExpr(statement.Expression)

		elseif statement.AstType == 'LocalStatement' then
			out = out.."local "
			for i = 1, #statement.LocalList do
				out = out..statement.LocalList[i].Name
				if i ~= #statement.LocalList then
					out = out..","
				end
			end
			if #statement.InitList > 0 then
				out = out.."="
				for i = 1, #statement.InitList do
					out = out..formatExpr(statement.InitList[i])
					if i ~= #statement.InitList then
						out = out..","
					end
				end
			end

		elseif statement.AstType == 'IfStatement' then
			out = joinStatements("if", formatExpr(statement.Clauses[1].Condition))
			out = joinStatements(out, "then")
			out = joinStatements(out, formatStatlist(statement.Clauses[1].Body))
			for i = 2, #statement.Clauses do
				local st = statement.Clauses[i]
				if st.Condition then
					out = joinStatements(out, "elseif")
					out = joinStatements(out, formatExpr(st.Condition))
					out = joinStatements(out, "then")
				else
					out = joinStatements(out, "else")
				end
				out = joinStatements(out, formatStatlist(st.Body))
			end
			out = joinStatements(out, "end")

		elseif statement.AstType == 'WhileStatement' then
			out = joinStatements("while", formatExpr(statement.Condition))
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'DoStatement' then
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'ReturnStatement' then
			out = "return"
			for i = 1, #statement.Arguments do
				out = joinStatements(out, formatExpr(statement.Arguments[i]))
				if i ~= #statement.Arguments then
					out = out..","
				end
			end

		elseif statement.AstType == 'BreakStatement' then
			out = "break"

		elseif statement.AstType == 'RepeatStatement' then
			out = "repeat"
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "until")
			out = joinStatements(out, formatExpr(statement.Condition))

		elseif statement.AstType == 'Function' then
			statement.Scope:ObfuscateLocals()
			if statement.IsLocal then
				out = "local"
			end
			out = joinStatements(out, "function ")
			if statement.IsLocal then
				out = out..statement.Name.Name
			else
				out = out..formatExpr(statement.Name)
			end
			out = out.."("
			if #statement.Arguments > 0 then
				for i = 1, #statement.Arguments do
					out = out..statement.Arguments[i].Name
					if i ~= #statement.Arguments then
						out = out..","
					elseif statement.VarArg then
						out = out..",..."
					end
				end
			elseif statement.VarArg then
				out = out.."..."
			end
			out = out..")"
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'GenericForStatement' then
			statement.Scope:ObfuscateLocals()
			out = "for "
			for i = 1, #statement.VariableList do
				out = out..statement.VariableList[i].Name
				if i ~= #statement.VariableList then
					out = out..","
				end
			end
			out = out.." in"
			for i = 1, #statement.Generators do
				out = joinStatements(out, formatExpr(statement.Generators[i]))
				if i ~= #statement.Generators then
					out = joinStatements(out, ',')
				end
			end
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")

		elseif statement.AstType == 'NumericForStatement' then
			statement.Scope:ObfuscateLocals()
			out = "for "
			out = out..statement.Variable.Name.."="
			out = out..formatExpr(statement.Start)..","..formatExpr(statement.End)
			if statement.Step then
				out = out..","..formatExpr(statement.Step)
			end
			out = joinStatements(out, "do")
			out = joinStatements(out, formatStatlist(statement.Body))
			out = joinStatements(out, "end")
		elseif statement.AstType == 'LabelStatement' then
			out = "::" .. statement.Label .. "::"
		elseif statement.AstType == 'GotoStatement' then
			out = "goto " .. statement.Label
		elseif statement.AstType == 'Comment' then
			-- ignore
		elseif statement.AstType == 'Eof' then
			-- ignore
		else
			error("Unknown AST Type: " .. statement.AstType)
		end
		return out
	end

	formatStatlist = function(statList)
		local out = ''
		statList.Scope:ObfuscateLocals()
		for _, stat in pairs(statList.Body) do
			out = joinStatements(out, formatStatement(stat), ';')
		end
		return out
	end

	return formatStatlist(ast)
end

--- Minify a string
-- @tparam string input The input string
-- @treturn string The minifyied string
local function MinifyString(input)
	local lex = Parse.LexLua(input)

	lex = Parse.ParseLua(lex)

	return Minify(lex)
end

--- Minify a file
-- @tparam string inputFile File to read from
-- @tparam string outputFile File to write to (Defaults to inputFile)
local function MinifyFile(inputFile, outputFile)
	outputFile = outputFile or inputFile

	local input = io.open(inputFile, "r")
	local contents = input:read( "*a" )
	input:close()

	contents = MinifyString(contents)

	local result = io.open(outputFile, "w")
	result:write(contents)
	result:close()
end

--- @export
return {
	JoinStatements = JoinStatements,
	Minify = Minify,
	MinifyString = MinifyString,
	MinifyFile = MinifyFile,
}
end)

return {
	Rebuild = Rebuild
}