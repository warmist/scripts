local aliases = reqscript('internal/quickfort/aliases').unit_test_hooks
local quickfort_reader = reqscript('internal/quickfort/reader')

function test.module()
    expect.error_match(dfhack.run_script,
                       'this script cannot be called directly',
                       'internal/quickfort/aliases')
end

function test.push_pop_reset()
    dfhack.with_finalize(
        function() aliases.reset_aliases() end,
        function()
            expect.table_eq({'a','a'}, aliases.expand_aliases('aa'))
            aliases.push_aliases({aa='zz'})
            expect.table_eq({'z','z'}, aliases.expand_aliases('aa'))
            expect.table_eq({'b','b'}, aliases.expand_aliases('bb'))
            aliases.push_aliases({aa='yy', bb='ww'})
            expect.table_eq({'y','y'}, aliases.expand_aliases('aa'))
            expect.table_eq({'w','w'}, aliases.expand_aliases('bb'))
            expect.table_eq({'c','c'}, aliases.expand_aliases('cc'))
            aliases.pop_aliases()
            expect.table_eq({'z','z'}, aliases.expand_aliases('aa'))
            expect.table_eq({'b','b'}, aliases.expand_aliases('bb'))
            aliases.push_aliases({cc='xx'})
            expect.table_eq({'x','x'}, aliases.expand_aliases('cc'))
            aliases.reset_aliases()
            expect.table_eq({'a','a'}, aliases.expand_aliases('aa'))
            expect.table_eq({'b','b'}, aliases.expand_aliases('bb'))
            expect.table_eq({'c','c'}, aliases.expand_aliases('cc'))
        end)
end

MockReader = defclass(MockReader, quickfort_reader.Reader)
MockReader.ATTRS{lines={}, i=0}
function MockReader:reset(lines) self.lines, self.i = lines, 0 end
function MockReader:get_next_row_raw()
    self.i = self.i + 1
    return self.lines[self.i]
end

function test.push_aliases_reader()
    local mock_reader = MockReader{}
    dfhack.with_finalize(
        function() aliases.reset_aliases() end,
        function()
            expect.eq(0, aliases.push_aliases_reader(mock_reader))

            mock_reader:reset({'# comment', '#comment: withcolon', 'aa: zz'})
            expect.eq(1, aliases.push_aliases_reader(mock_reader))
            expect.table_eq({'z','z'}, aliases.expand_aliases('aa'))
        end)
end

function test.process_text()
    dfhack.with_finalize(
        function() aliases.reset_aliases() end,
        function()
            expect.error(aliases.process_text, 'text', {}, 51)

            aliases.push_aliases({aa='{bb}',bb='{aa}'})
            expect.error_match(aliases.process_text, 'recursion', '{aa}', {})

            aliases.reset_aliases()
            aliases.push_aliases({aa='{bb}', bb='x{cc}x', cc='o'})

            local tokens = {}
            aliases.process_text('send!&', tokens)
            expect.table_eq({'s','e','n','d','Ctrl','Enter'}, tokens)

            tokens = {}
            aliases.process_text('!n@', tokens)
            expect.table_eq({'Ctrl','n','Shift','Enter'}, tokens)

            tokens = {}
            aliases.process_text('{Enter 3}{ExitMenu}', tokens)
            expect.table_eq({'Enter','Enter','Enter','ESC'}, tokens)

            tokens = {}
            aliases.process_text('{q 3}{cc 2}{za 2}', tokens)
            expect.table_eq({'q','q','q','o','o','za','za'}, tokens)

            tokens = {}
            aliases.process_text('i{aa 3}', tokens)
            expect.table_eq({'i','x','o','x','x','o','x','x','o','x'}, tokens)

            tokens = {}
            aliases.process_text('{aa bb=q 3}', tokens)
            expect.table_eq({'q','q','q'}, tokens)

            tokens = {}
            aliases.process_text('{aa cc=q 3}', tokens)
            expect.table_eq({'x','q','x','x','q','x','x','q','x'}, tokens)

            tokens = {}
            aliases.process_text('{aa bb=q}{aa cc=u}', tokens)
            expect.table_eq({'q','x','u','x'}, tokens)

            tokens = {}
            aliases.process_text('{aa cc={dd} dd=v}', tokens)
            expect.table_eq({'x','v','x'}, tokens)
        end)
end

function test.expand_aliases()
    dfhack.with_finalize(
        function() aliases.reset_aliases() end,
        function()
            expect.table_eq({'r','+','Enter'}, aliases.expand_aliases('r+'))
            expect.table_eq({'r','+','Enter'}, aliases.expand_aliases('{r+}'))

            aliases.push_aliases({aa='{bb}', bb='x{cc}x', cc='o'})
            expect.table_eq({'o'}, aliases.expand_aliases('cc'))
            expect.table_eq({'x','o','x'}, aliases.expand_aliases('aa'))

            expect.table_eq({'l','i','t'}, aliases.expand_aliases('lit'))
       end)
end
