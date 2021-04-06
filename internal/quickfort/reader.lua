-- encapsulates file I/O (well, really just file I)
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local xlsxreader = require('plugins.xlsxreader')

local function chomp(line)
    return line and line:gsub('[\r\n]*$', '') or nil
end

Reader = defclass(Reader, nil)
Reader.ATTRS{
    -- filesystem path that can be passed to io.open()
    filepath = DEFAULT_NIL,
    -- how many columns to read per row; 0 means all
    max_cols = 0,
}

-- causes the next call to get_next_row to re-return the value from the
-- previous time it was called
function Reader:redo()
    self.redo_requested = true
end

function Reader:get_next_row()
    if self.redo_requested then
        self.redo_requested = false
        return self.prev_row
    end
    self.prev_row = self:get_next_row_raw()
    return self.prev_row
end

CsvReader = defclass(CsvReader, Reader)
CsvReader.ATTRS{
    -- Tokenizer function with the following signature:
    --  (get_next_line_fn, max_cols). Must return a list of strings. Required.
    line_tokenizer = DEFAULT_NIL,
    -- file open function to use
    open_fn = io.open,
}

function CsvReader:init()
    if not self.line_tokenizer then
        error('cannot initialize a CsvReader without a line_tokenizer.')
    end
    self.file = self.open_fn(self.filepath)
    if not self.file then
        qerror(string.format('failed to open "%s"', self.filepath))
    end
end

function CsvReader:cleanup()
    self.file:close()
end

function CsvReader:get_next_row_raw()
    return self.line_tokenizer(
        function() return chomp(self.file:read()) end,
        self.max_cols)
end

XlsxReader = defclass(XlsxReader, Reader)
XlsxReader.ATTRS{
    -- name of xlsx sheet to open, nil means first sheet
    sheet_name = DEFAULT_NIL,
    -- xlsxio reader class to use
    open_fn = xlsxreader.open,
}

function XlsxReader:init()
    self.reader = self.open_fn(self.filepath)
    self.sheet_reader = self.reader:open_sheet(self.sheet_name)
end

function XlsxReader:cleanup()
    self.sheet_reader:close()
    self.reader:close()
end

function XlsxReader:get_next_row_raw()
    local tokens = self.sheet_reader:get_row(self.max_cols)
    if not tokens then return nil end
    -- raw numbers can get turned into floats. let's turn them back into ints
    for i,token in ipairs(tokens) do
        local token = tonumber(token)
        if token then tokens[i] = tostring(math.floor(token)) end
    end
    return tokens
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        chomp=chomp,
        Reader=Reader,
        CsvReader=CsvReader,
        XlsxReader=XlsxReader,
    }
end
