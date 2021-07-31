config.mode = 'fortress'

local p = reqscript('prioritize').unit_test_hooks

function test.parse_commandline()
    expect.table_eq({help=true}, p.parse_commandline{'help'})
    expect.table_eq({help=true}, p.parse_commandline{'-h'})
    expect.table_eq({help=true}, p.parse_commandline{'--help'})

    expect.table_eq({action=p.status, job_types={}}, p.parse_commandline{})
    expect.table_eq({action=p.boost, job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'Suture'})
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.status, job_types={}},
                            p.parse_commandline{'XSutureX'})
        end)
    expect.printerr_match('Ignoring unknown job type',
        function()
            expect.table_eq({action=p.boost,
                             job_types={[df.job_type['Suture']]=true}},
                            p.parse_commandline{'XSutureX', 'Suture'})
        end)

    expect.table_eq({action=p.status, job_types={}, quiet=true},
                    p.parse_commandline{'-q'})
    expect.table_eq({action=p.status, job_types={}, quiet=true},
                    p.parse_commandline{'--quiet'})

    expect.table_eq({action=p.boost_and_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-a', 'Suture'})
    expect.table_eq({action=p.boost_and_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--add', 'Suture'})

    expect.table_eq({action=p.remove_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-d', 'Suture'})
    expect.table_eq({action=p.remove_watch,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--delete', 'Suture'})

    expect.table_eq({action=p.print_current_jobs, job_types={}},
                    p.parse_commandline{'-j'})
    expect.table_eq({action=p.print_current_jobs,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'-j', 'Suture'})
    expect.table_eq({action=p.print_current_jobs,
                     job_types={[df.job_type['Suture']]=true}},
                    p.parse_commandline{'--jobs', 'Suture'})

    expect.table_eq({action=p.print_registry, job_types={}},
                    p.parse_commandline{'-r'})
    expect.table_eq({action=p.print_registry, job_types={}},
                    p.parse_commandline{'--registry'})
end
