<#
.SYNOPSIS
    Inventories scheduled tasks on the current machine with last/next run times.
.DESCRIPTION
    Enumerates every scheduled task and emits one object per task (name, state, path,
    author, description, triggers, last/next run time), suitable for Export-Csv. Useful
    for persistence review and change auditing.
.NOTES
    Author : Steven Slocum
    Notes  : Portfolio copy of a real-world script. Lab values and placeholder
             secrets substituted for any originals.
#>

$SchTasks            = Get-ScheduledTask
$results             = @()


foreach ($s in $SchTasks)

    {

        $TaskName            =                 $s.TaskName
        $TaskInfo            =                 $s | Get-ScheduledTaskInfo


                $obj = [PsCustomobject] @{


                    TaskName            =               $TaskName
                    State               =               $s.State  
                    TaskPath            =               $s.TaskPath
                    Author              =               $s.Author
                    Description         =               $s.Description
                    Triggers            =               $s.Triggers
                    LastRunTime         =               $TaskInfo.LastRunTime
                    LastTaskResult      =               $TaskInfo.LastTaskResult
                    NextRunTime         =               $TaskInfo.NextRunTime
                    NumberOfMIssedRuns  =               $TaskInfo.NumberOfMissedRuns            


                                            }
            
            $results += $obj
    
    }