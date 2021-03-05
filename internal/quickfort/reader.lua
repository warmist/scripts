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
    -- how many columns to read per row; <=0 or nil means all
    max_cols = DEFAULT_NIL,
}

function Reader:assert_file()
    if not self.file then
        qerror(string.format('failed to open %s', self:description()))
    end
end

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
    -- tokenizer function with the following signature:
    --  (get_next_line_fn, max_cols). Required
    line_tokenizer = DEFAULT_NIL,
}

function CsvReader:init()
    self.file = io.open(self.filepath)
    self:assert_file()
end

function CsvReader:description()
    return string.format('.csv file "%s"', self.filepath)
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
}

function XlsxReader:init()
    self.file = xlsxreader.open_xlsx_file(self.filepath)
    self:assert_file()
    if not self.sheet_name then
        for _,sheet_name in ipairs(xlsxreader.list_sheets(self.file)) do
            self.sheet_name = sheet_name
            break
        end
    end
    -- this always succeeds even if the sheet doesn't exist. we'll fail
    -- on the next call to get_next_row_raw, though
    self.sheet = xlsxreader.open_sheet(self.flie, self.sheet_name)
end

function XlsxReader:description()
    return string.format('sheet "%s" in .xlsx file "%s"',
                         self.sheet_name, self.filepath)
end

function XlsxReader:cleanup()
    xlsxreader.close_sheet(self.sheet)
    xlsxreader.close_xlsx_file(self.file)
end

function XlsxReader:get_next_row_raw()
    local tokens = xlsxreader.get_row(self.sheet)
    if not tokens then return nil end
    -- raw numbers can get turned into floats. let's turn them back into ints
    for i,token in ipairs(tokens) do
        local token = tonumber(token)
        if token then tokens[i] = tostring(math.floor(token)) end
    end
    return tokens
end

unit_test_hooks = {
    chomp=chomp,
}
