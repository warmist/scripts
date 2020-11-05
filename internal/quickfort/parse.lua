-- file parsing logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local xlsxreader = require('plugins.xlsxreader')
local quickfort_common = reqscript('internal/quickfort/common')

function quote_if_has_spaces(str)
    if str:find(' ') then return '"' .. str .. '"' end
    return str
end

local function trim_token(token)
    _, _, token = token:find('^%s*(.-)%s*$')
    return token
end

-- returns the next token and the start position of the following token
-- or nil if there are no tokens
local function get_next_csv_token(line, pos, get_next_line_fn, sep)
    local sep = sep or ','
    local c = string.sub(line, pos, pos)
    if c == '' then return nil end
    if c == '"' then
        -- quoted value (ignore separators within)
        local txt = ''
        repeat
            local startp, endp = string.find(line, '^%b""', pos)
            while not startp do
                -- handle multi-line quoted string
                local next_line = get_next_line_fn()
                if not next_line then
                    dfhack.printerr('unterminated quoted string')
                    return nil
                end
                line = line .. '\n' .. next_line
                startp, endp = string.find(line, '^%b""', pos)
            end
            txt = txt .. string.sub(line, startp+1, endp-1)
            pos = endp + 1
            -- check first char AFTER quoted string, if it is another
            -- quoted string without separator, then append it
            -- this is the way to "escape" the quote char in a quote.
            -- example: "blub""blip""boing" -> blub"blip"boing
            c = string.sub(line, pos, pos)
            if (c == '"') then txt = txt .. '"' end
        until c ~= '"'
        if line:sub(pos, pos) == sep then pos = pos + 1 end
        return trim_token(txt), pos
    end
    -- no quotes used, just look for the first separator
    local startp, endp = string.find(line, sep, pos)
    if startp then
        return trim_token(string.sub(line, pos, startp-1)), startp+1
    end
    -- no separator found -> use rest of string
    return trim_token(string.sub(line, pos)), #line+1
end

local function get_next_line(file)
    local line = file:read()
    if not line then return nil end
    return string.gsub(line, '[\r\n]*$', '')
end

-- adapted from example on http://lua-users.org/wiki/LuaCsv
-- returns a list of strings corresponding to the text in the cells in the row
local function tokenize_next_csv_line(file, first_col_only)
    local get_next_line_fn = function() return get_next_line(file) end
    local line = get_next_line_fn()
    if not line then return nil end
    local tokens = {}
    local sep = ','
    local token, pos = get_next_csv_token(line, 1, get_next_line_fn, sep)
    while token do
        table.insert(tokens, token)
        if first_col_only then break end
        token, pos = get_next_csv_token(line, pos, get_next_line_fn)
    end
    return tokens
end

local function parse_label(modeline, start_pos, filename, marker_values)
    local _, label_str_end, label_str =
            string.find(modeline, '^%s+label(%b())', start_pos)
    if not label_str then
        return false, start_pos
    end
    local _, _, label = string.find(label_str, '^%(%s*(%a.-)%s*%)$')
    if not label or #label == 0 then
        print(string.format(
            'error while parsing "%s": labels must start with a letter: "%s"',
            filename, modeline))
    else
        marker_values.label = label
    end
    return true, label_str_end + 1
end

local function parse_start(modeline, start_pos, filename, marker_values)
    local _, start_str_end, start_str =
            string.find(modeline, '^%s+start(%b())', start_pos)
    if not start_str or #start_str == 0 then return false, start_pos end
    local _, _, startx, starty, start_comment =
            string.find(start_str,
                        '^%(%s*(%d+)%s*[;, ]%s*(%d+)%s*[;, ]?%s*(.*)%)$')
    if startx and starty then
        marker_values.startx = startx
        marker_values.starty = starty
        marker_values.start_comment = #start_comment>0 and start_comment or nil
    else
        -- the whole thing is a comment
        _, _, start_comment = string.find(start_str, '^%(%s*(.-)%s*%)$')
        marker_values.start_comment = start_comment
    end
    return true, start_str_end + 1
end

local function parse_hidden(modeline, start_pos, filename, marker_values)
    local _, hidden_str_end, hidden_str =
            string.find(modeline, '^%s+hidden(%b())', start_pos)
    if not hidden_str or #hidden_str == 0 then return false, start_pos end
    marker_values.hidden = true
    return true, hidden_str_end + 1
end

local function parse_message(modeline, start_pos, filename, marker_values)
    local _, message_str_end, message_str =
            string.find(modeline, '^%s+message(%b())', start_pos)
    if not message_str then
        return false, start_pos
    end
    local _, _, message = string.find(message_str, '^%(%s*(.-)%s*%)$')
    marker_values.message = message
    return true, message_str_end + 1
end

local marker_fns = {parse_label, parse_start, parse_hidden, parse_message}

-- parses all markers in any order
-- returns table of found values:
-- {label, startx, starty, start_comment, hidden, message}
local function parse_markers(modeline, start_pos, filename)
    local remaining_marker_fns = copyall(marker_fns)
    local marker_values = {}
    while #remaining_marker_fns > 0 do
        local matched = false
        for i,marker_fn in ipairs(remaining_marker_fns) do
            matched, start_pos =
                    marker_fn(modeline, start_pos, filename, marker_values)
            if matched then
                table.remove(remaining_marker_fns, i)
                break
            end
        end
        if not matched then break end
    end
    return marker_values, start_pos
end

--[[
parses a modeline
example: '#dig label(dig1) start(4;4;center of stairs) dining hall'
where all elements other than the initial #mode are optional (though if the
'label' part exists, a label must be specified, and if the 'start' part exists,
the offsets must also exist). If a label is not specified, the modeline_id is
used as the label.
returns a table in the format:
  {mode, label, startx, starty, start_comment, comment}
or nil if the modeline is invalid
]]
local function parse_modeline(modeline, filename, modeline_id)
    if not modeline then return nil end
    local _, mode_end, mode = string.find(modeline, '^#([%l]+)')
    if not mode or not quickfort_common.valid_modes[mode] then
        return nil
    end
    local modeline_data, comment_start =
            parse_markers(modeline, mode_end+1, filename)
    local _, _, comment = string.find(modeline, '^%s*(.*)', comment_start)
    modeline_data.mode = mode
    modeline_data.comment = #comment > 0 and comment or nil
    modeline_data.label = modeline_data.label or tostring(modeline_id)
    return modeline_data
end

local function get_col_name(col)
  if col <= 26 then
    return string.char(string.byte('A') + col - 1)
  end
  local div, mod = math.floor(col / 26), math.floor(col % 26)
  if mod == 0 then
      mod = 26
      div = div - 1
  end
  return get_col_name(div) .. get_col_name(mod)
end

local function make_cell_label(col_num, row_num)
    return get_col_name(col_num) .. tostring(math.floor(row_num))
end

local function read_csv_line(ctx, first_col_only)
    return tokenize_next_csv_line(ctx.csv_file, first_col_only)
end

local function cleanup_csv_ctx(ctx)
    ctx.csv_file:close()
end

local function reset_csv_ctx(ctx)
    ctx.csv_file:close()
    ctx.csv_file = io.open(ctx.filepath)
end

local function read_xlsx_line(ctx)
    return xlsxreader.get_row(ctx.xlsx_sheet)
end

local function cleanup_xslx_ctx(ctx)
    xlsxreader.close_sheet(ctx.xlsx_sheet)
    xlsxreader.close_xlsx_file(ctx.xlsx_file)
end

-- only resets the sheet, not the entire file
local function reset_xlsx_ctx(ctx)
    xlsxreader.close_sheet(ctx.xlsx_sheet)
    ctx.xlsx_sheet = xlsxreader.open_sheet(ctx.xlsx_file, ctx.sheet_name)
end

local function init_reader_ctx(filepath, sheet_name, first_col_only)
    local reader_ctx = {filepath=filepath}
    if string.find(filepath:lower(), '[.]csv$') then
        local file = io.open(filepath)
        if not file then
            qerror(string.format('failed to open blueprint file: "%s"',
                                 filepath))
        end
        reader_ctx.csv_file = file
        reader_ctx.get_row_tokens =
                function(ctx) return read_csv_line(ctx, first_col_only) end
        reader_ctx.cleanup = cleanup_csv_ctx
        reader_ctx.reset = reset_csv_ctx
    else
        local xlsx_file = xlsxreader.open_xlsx_file(filepath)
        if not xlsx_file then
            qerror(string.format('failed to open blueprint file: "%s"',
                                 filepath))
        end
        if not sheet_name then
            for _, sheet in ipairs(xlsxreader.list_sheets(xlsx_file)) do
                sheet_name = sheet
                break
            end
        end
        -- open_sheet succeeds even if the sheet cannot be found
        reader_ctx.xlsx_file = xlsx_file
        reader_ctx.sheet_name = sheet_name
        reader_ctx.xlsx_sheet =
                xlsxreader.open_sheet(reader_ctx.xlsx_file, sheet_name)
        reader_ctx.get_row_tokens = read_xlsx_line
        reader_ctx.cleanup = cleanup_xslx_ctx
        reader_ctx.reset = reset_xlsx_ctx
    end
    return reader_ctx
end

-- returns a grid representation of the current level, the number of lines
-- read from the input, and the next z-level modifier, if any. See process_file
-- for grid format.
local function process_level(reader_ctx, start_line_num, start_coord)
    local grid = {}
    local y = start_coord.y
    while true do
        local row_tokens = reader_ctx.get_row_tokens(reader_ctx)
        if not row_tokens then return grid, y-start_coord.y end
        for i, v in ipairs(row_tokens) do
            if i == 1 then
                if v == '#<' then return grid, y-start_coord.y, 1 end
                if v == '#>' then return grid, y-start_coord.y, -1 end
                if parse_modeline(v, reader_ctx.filepath) then
                    return grid, y-start_coord.y
                end
            end
            if string.find(v, '^#') then break end
            if not string.find(v, '^[`~%s]*$') then
                -- cell has actual content, not just spaces or comment chars
                if not grid[y] then grid[y] = {} end
                local x = start_coord.x + i - 1
                local line_num = start_line_num + y - start_coord.y
                grid[y][x] = {cell=make_cell_label(i, line_num), text=v}
            end
        end
        y = y + 1
    end
end

local function process_levels(reader_ctx, label, start_cursor_coord)
    local section_data_list = {}
    -- scan down to the target label
    local cur_line_num, modeline_id = 1, 1
    local row_tokens, modeline = nil, nil
    local first_line = true
    while not modeline or (label and modeline.label ~= label) do
        row_tokens = reader_ctx.get_row_tokens(reader_ctx)
        if not row_tokens then
            local label_str = 'no data'
            if label then label_str = string.format('label "%s" not', label) end
            if reader_ctx.sheet_name then
                qerror(string.format(
                        '%s found in sheet "%s" in file "%s"',
                        label_str, reader_ctx.sheet_name, reader_ctx.filepath))
            else
                qerror(string.format('%s found in file "%s"',
                                     label_str, reader_ctx.filepath))
            end
        end
        cur_line_num = cur_line_num + 1
        modeline = parse_modeline(row_tokens[1], reader_ctx.filepath,
                                  modeline_id)
        if first_line then
            if not modeline then
                modeline = {mode='dig', label="1"}
                reader_ctx.reset(reader_ctx) -- we need to reread the first line
            end
            first_line = false
        end
        if modeline then modeline_id = modeline_id + 1 end
    end
    local x = start_cursor_coord.x - (modeline.startx or 1) + 1
    local y = start_cursor_coord.y - (modeline.starty or 1) + 1
    local z = start_cursor_coord.z
    while true do
        local grid, num_section_rows, zmod =
                process_level(reader_ctx, cur_line_num, xyz2pos(x, y, z))
        table.insert(section_data_list,
                     {modeline=modeline, zlevel=z, grid=grid})
        if zmod == nil then break end
        cur_line_num = cur_line_num + num_section_rows + 1
        z = z + zmod
    end
    return section_data_list
end

local function get_sheet_modelines(reader_ctx)
    local modelines = {}
    local row_tokens = reader_ctx.get_row_tokens(reader_ctx)
    local first_line = true
    while row_tokens do
        local modeline = nil
        if #row_tokens > 0 then
            modeline = parse_modeline(row_tokens[1], reader_ctx.filepath,
                                      #modelines+1)
        end
        if first_line then
            if not modeline then
                modeline = {mode='dig', label="1"}
            end
            first_line = false
        end
        if modeline and modeline.mode ~= 'ignore' then
            table.insert(modelines, modeline)
        end
        row_tokens = reader_ctx.get_row_tokens(reader_ctx)
    end
    return modelines
end

-- returns a list of modeline tables
function get_modelines(filepath, sheet_name)
    local reader_ctx = init_reader_ctx(filepath, sheet_name, true)
    return dfhack.with_finalize(
        function() reader_ctx.cleanup(reader_ctx) end,
        function() return get_sheet_modelines(reader_ctx) end
    )
end

--[[
returns a list of {modeline, zlevel, grid} tables
Where the structure of modeline is defined as per parse_modeline and grid is a:
  map of target y coordinate ->
    map of target map x coordinate ->
      {cell=spreadsheet cell, text=text from spreadsheet cell}
Map keys are numbers, and the keyspace is sparse -- only cells that have content
are non-nil.
]]
function process_section(filepath, sheet_name, label, start_cursor_coord)
    local reader_ctx = init_reader_ctx(filepath, sheet_name, false)
    return dfhack.with_finalize(
        function() reader_ctx.cleanup(reader_ctx) end,
        function()
            return process_levels(reader_ctx, label, start_cursor_coord)
        end
    )
end

-- throws on invalid token
-- returns the contents of the extended token
local function get_extended_token(text, startpos)
    -- extended token must start with a '{' and be at least 3 characters long
    if text:sub(startpos, startpos) ~= '{' or #text < startpos + 2 then
        qerror(
            string.format('invalid extended token: "%s"', text:sub(startpos)))
    end
    -- construct a modified version of the string so we can search for the
    -- matching closing brace, ignoring initial '{' and '}' characters that
    -- should be treated as literals
    local etoken_mod = ' {' .. text:sub(startpos + 2)
    local b, e = etoken_mod:find(' %b{}')
    if not b then
        qerror(string.format(
                'invalid extended token: "%s"; did you mean "{{}"?',
                text:sub(startpos)))
    end
    return text:sub(startpos + b - 1, startpos + e - 1)
end

-- returns the token (i.e. the alias name or keycode) and the start position
-- of the next element in the etoken
local function get_token(etoken)
    local _, e, token = etoken:find('^{(.[^}%s]*)%s*')
    if token == 'Numpad' then
        _, e, num = etoken:find('^%s*Numpad%s+(%d)%s*')
        if not num then
            qerror(string.format(
                    'invalid extended token: "%s"; missing Numpad number?',
                    etoken))
        end
        token = string.format('%s %d', token, num)
    end
    return token, e + 1
end

local function no_next_line()
    return nil
end

local function get_next_param(etoken, start)
    local _, pos, name = etoken:find('%s*([%w-_][%w-_]+)=.', start)
    return name, pos
end

-- returns the specified param map and the start position of the next element
-- in the etoken
local function get_params(etoken, start)
    -- trim off the last '}' from the etoken so the csv parser doesn't read it
    etoken = etoken:sub(1, -2)
    local params, next_pos = {}, start
    -- param names follow the same naming rules as aliases -- at least two
    -- alphanumerics
    local name, pos = get_next_param(etoken, start)
    while name do
        local val, next_param_start = nil, nil
        if etoken:sub(pos, pos) == '{' then
            _, next_param_start, val = etoken:find('(%b{})', pos)
            next_param_start = next_param_start + 1
        else
            val, next_param_start =
                    get_next_csv_token(etoken, pos, no_next_line, ' ')
        end
        if not val then
            qerror(string.format(
                    'invalid extended token param: "%s"', etoken:sub(pos)))
        end
        params[name] = val
        next_pos = next_param_start
        name, pos = get_next_param(etoken, next_param_start)
    end
    return params, next_pos
end

-- returns the specified repetitions, or 1 if not specified, and the position
-- of the next element in etoken
-- throws if specified repetitions is < 1
local function get_repetitions(etoken, start)
    local _, e, repetitions = etoken:find('%s*(%d+)%s*}', start)
    return repetitions or 1, e or start
end

-- parses the sequence starting with '{' and ending with the matching '}' that
-- delimit an extended token of the form:
--   {token params repetitions}
-- where token is an alias name or a keycode, and both params and repetitions
-- are optional. if the first character of token is '{' or '}', it is treated as
-- a literal and not a syntax element.
-- params are in one of the following formats:
--   param_name=param_val
--   param_name="param val with spaces"
--   param_name={token params repetitions}
-- if the params within the extended token within the params require quotes,
-- .csv-style doubled double quotes are required:
--   param_name="{somealias var=""with spaces"" 5}"
-- combining literals with extended tokens is not currently supported to keep
-- the implementation simple, though we can add it if there is demand. That is,
-- the following is not supported: param_name=literal{somealias}. The
-- workaround is just to put the literal in a regularly-defined alias and call
-- that alias.
-- if repetitions is not specified, the value 1 is returned
-- returns token as string, params as map, repetitions as number, start position
-- of the next element after the etoken in text as number
function parse_extended_token(text, startpos)
    startpos = startpos or 1
    local etoken = get_extended_token(text, startpos)
    local token, params_start = get_token(etoken)
    local params, repetitions_start = get_params(etoken, params_start)
    local repetitions, last_pos = get_repetitions(etoken, repetitions_start)
    if last_pos ~= #etoken then
        qerror(string.format('invalid extended token format: "%s"', etoken))
    end
    local next_token_pos = startpos + #etoken
    return token, params, repetitions, next_token_pos
end
