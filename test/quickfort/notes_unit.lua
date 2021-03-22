local notes = reqscript('internal/quickfort/notes')

function test.module()
    expect.error_match(dfhack.run_script,
                       'this script cannot be called directly',
                       'internal/quickfort/notes')
end

function test.do_run()
    local grid = {[20]={[10]={cell='A1', text='row1'}},
                  [22]={[10]={cell='A3', text='row3'}}}
    local ctx = {messages={}}
    notes.do_run(nil, grid, ctx)
    expect.table_eq({'row1\n\nrow3'}, ctx.messages)
end

function test.do_orders()
    expect.nil_(notes.do_orders())
end

function test.do_undo()
    expect.nil_(notes.do_undo())
end
