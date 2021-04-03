local reader = reqscript('internal/quickfort/reader').unit_test_hooks

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/reader') end)
end

function test.chomp()
    expect.nil_(reader.chomp(nil))

    expect.eq('', reader.chomp(''))
    expect.eq('a', reader.chomp('a'))
    expect.eq('', reader.chomp('\r'))
    expect.eq('', reader.chomp('\n\r'))
    expect.eq('', reader.chomp('\r\n'))
    expect.eq('', reader.chomp('\n'))
    expect.eq('\r ', reader.chomp('\r \n'))
    expect.eq('  message  ', reader.chomp('  message  \n'))
    expect.eq(' \t message  ', reader.chomp(' \t message  \n'))
end

MockReader = defclass(MockReader, reader.Reader)
MockReader.ATTRS{i=0}
function MockReader:get_next_row_raw()
    self.i = self.i + 1
    return {string.format('row %d', self.i)}
end

function test.Reader()
    local mock_reader = MockReader{filepath='mock'}

    expect.table_eq({'row 1'}, mock_reader:get_next_row())
    expect.table_eq({'row 2'}, mock_reader:get_next_row())
    mock_reader:redo()
    expect.table_eq({'row 2'}, mock_reader:get_next_row())
    expect.table_eq({'row 3'}, mock_reader:get_next_row())
end

MockFile = defclass(MockFile, nil)
MockFile.ATTRS{i=0,fname=DEFAULT_NIL}
function MockFile:close()
    self.close_called = (self.close_called or 0) + 1
end
function MockFile:read()
    self.i = self.i + 1
    return string.format('line %d\n', self.i)
end

function test.CsvReader()
    local mock_tokenizer = function(line_fn, _) return line_fn() end

    expect.error_match('without a line_tokenizer',
                       function() reader.CsvReader{} end)
    expect.error_match('failed to open "f"',
                       function()
                            reader.CsvReader{
                                filepath='f',
                                line_tokenizer=mock_tokenizer,
                                open_fn=function(fname) return nil end}
                       end)

    mock_file = MockFile{fname='f'}
    csvreader = reader.CsvReader{
        filepath='f',
        line_tokenizer=mock_tokenizer,
        open_fn=function() return mock_file end}

    expect.eq('line 1', csvreader:get_next_row_raw())
    expect.eq('line 2', csvreader:get_next_row_raw())

    csvreader:cleanup()
    expect.eq(1, mock_file.close_called)
end

MockXlsxioReader = defclass(MockXlsxioReader, nil)
MockXlsxioReader.ATTRS{i=0,lines={},filepath=DEFAULT_NIL}
function MockXlsxioReader:open_sheet() return self end
function MockXlsxioReader:get_row()
    self.i = self.i + 1
    return self.lines[self.i]
end
function MockXlsxioReader:reset(lines) self.i, self.lines = 0, lines end
function MockXlsxioReader:close()
    self.close_called = (self.close_called or 0) + 1
end
local function open_mock_xlsxio_reader(filepath)
    return MockXlsxioReader{filepath=filepath}
end

function test.XlsxReader()
    local xlsxreader = reader.XlsxReader{open_fn=open_mock_xlsxio_reader}

    xlsxreader.reader:reset({})
    expect.nil_(xlsxreader:get_next_row_raw())

    xlsxreader.reader:reset({{'a','b1','b1.0','1c','1.0c','1','1.0'}})
    expect.table_eq({'a','b1','b1.0','1c','1.0c','1','1'},
                    xlsxreader:get_next_row_raw())

    -- expect close to be called 2 times since the mock is impersonating both
    -- the top-level reader and the sheet reader
    xlsxreader:cleanup()
    expect.eq(2, xlsxreader.reader.close_called)
end
