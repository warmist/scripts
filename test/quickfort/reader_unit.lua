local reader = reqscript('internal/quickfort/reader').unit_test_hooks

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
