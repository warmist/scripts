-- alias expansion logic for the quickfort script query module
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_parse = reqscript('internal/quickfort/parse')
local log = quickfort_common.log

-- special keycode shortcuts inherited from python quickfort.
local special_keys = {
    ['&']='Enter',
    ['!']='Ctrl',
    ['~']='Alt',
    ['@']={'Shift','Enter'},
    ['^']='ESC',
    ['%']='Wait'
}
local special_aliases = {
    ExitMenu='ESC',
    ['r+']={'r','+','Enter'}
}

local alias_stack = {}

function reset_aliases()
    alias_stack = {}
end

-- overwrites metatable of passed-in aliases map
function push_aliases(aliases)
    local prev = alias_stack
    setmetatable(aliases, {prev=prev,
                           __index=function(_, key) return prev[key] end})
    alias_stack = aliases
end

local function pop_aliases()
    alias_stack = getmetatable(alias_stack).prev
end

-- pushes a file of aliases on the stack. aliases are resolved with the
-- definition nearest the top of the stack.
function push_aliases_csv_file(filename)
    local file = io.open(filename)
    if not file then
        log('aliases file not found: "%s"', filename)
        return
    end
    local aliases = {}
    local num_aliases = 0
    for line in file:lines() do
        line = line:gsub('[\r\n]*$', '')
        if quickfort_parse.parse_alias_combined(line, aliases) then
            num_aliases = num_aliases + 1
        end
    end
    log('successfully read in %d aliases from "%s"', num_aliases, filename)
    push_aliases(aliases)
end

local function process_text(text, tokens, depth)
    if depth > 50 then
        qerror(string.format('alias resolution maximum depth exceeded (%d)',
                             depth))
    end
    local i = 1
    while i <= #text do
        local next_char = text:sub(i, i)
        local expansion, repetitions = {}, 1
        if next_char ~= '{' then
            -- token is a special key or a key literal
            expansion[1] = special_keys[next_char] or next_char
        else
            local etoken, params, reps, next_pos =
                quickfort_parse.parse_extended_token(text, i)
            if not special_aliases[etoken] and alias_stack[etoken] then
                push_aliases(params)
                process_text(alias_stack[etoken], expansion, depth+1)
                pop_aliases()
            else
                expansion[1] = special_aliases[etoken] or etoken
            end
            repetitions, i = reps, next_pos - 1
        end
        for j=1,repetitions do
            for k=1, #expansion do
                if type(expansion[k]) == "string" then
                    tokens[#tokens+1] = expansion[k]
                else
                    for _, token in ipairs(expansion[k]) do
                        tokens[#tokens+1] = token
                    end
                end
            end
        end
        i = i + 1
    end
end

-- expands aliases in a string and returns the individual key tokens.
-- if the entirety of text matches an alias, expands the entire text as an alias
-- otherwise, if the text contains a substring like '{alias}', matches the alias
-- between the curly brackets and replaces the substring. Aliases themselves
-- can contain other aliases, but must use the {} format if they do. Literal
-- key names can also appear in curly brackets to allow the parser to recognize
-- multi-character keys, such as '{F10}'. Anything in curly brackets can be
-- followed by a number to indicate repetition. For example, '{Down 5}'
-- indicates 'Down' 5 times. 'Numpad' is treated specially so that '{Numpad 8}'
-- doesn't get expanded to 'Numpad' 8 times, but rather 'Numpad 8' once. You can
-- repeat Numpad keys like this: '{Numpad 8 5}'.
-- returns an array of character key tokens
function expand_aliases(text)
    local tokens = {}
    if special_aliases[text] then
        local special_expansion = special_aliases[text]
        if type(special_expansion) == "table" then
            tokens = special_expansion
        else
            tokens = {special_expansion}
        end
    elseif alias_stack[text] then
        process_text(alias_stack[text], tokens, 1)
    else
        process_text(text, tokens, 1)
    end
    local expanded_text = table.concat(tokens, '')
    if text ~= expanded_text then
        log('expanded keys to: "%s"', table.concat(tokens, ' '))
    end
    return tokens
end
