-- Deletes corrupted jobs from global job list

local utils = require("utils")

local count = 0

functioning_job_list = {}

for _, job in ipairs(df.global.job_list) do
    if job.id != -1 then 
        functioning_job_list[#functioning_job_list+1] = job
    end 
end

for _, v in ipairs(df.global.world.units.all) do
    if v.job.current_job then 
        if utils.linear_index(functioning_job_list, v.job.current_job) == nil then
        v.job.current_job = nil
        end
    end 
end
