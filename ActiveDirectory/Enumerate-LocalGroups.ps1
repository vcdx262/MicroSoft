<#
.SYNOPSIS
    Enumerates local groups and their members on the current machine.
.DESCRIPTION
    Walks every local group and emits one object per group membership (group name,
    member name/class), suitable for Export-Csv. Useful for local-privilege auditing.
.NOTES
    Author : Steven Slocum
    Notes  : Portfolio copy of a real-world script. Lab values and placeholder
             secrets substituted for any originals.
#>

$LocalGroups         = Get-LocalGroup
$results             = @()


foreach ($g in $localgroups)

    {

        $GroupMembers        =                 $null                   
        $GroupName           =                 $g.name
        $GroupMembers        =                 Get-LocalGroupMember -Group $g

            foreach ($m in $GroupMembers )
            
            
            {       
    
                $obj = $null 
                $obj = [PsCustomobject] @{


                    GroupName           =                 $GroupName
                    MemberName          =                 $m.Name  
                    SID                 =                 $m.SID                   

                                            }
            
            $results += $obj

            }


    
    }

