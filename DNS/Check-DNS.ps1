<#
.SYNOPSIS
    Validates forward (A), reverse (PTR) and CNAME DNS records against expected values.
.DESCRIPTION
    Reads a CSV of expected records (HostName, suffix, expected IP, CNAME, CNAMESuffix)
    and, per row, checks that the A record exists and resolves correctly, that the PTR
    matches, that there are no duplicate/multiple records, and that the CNAME resolves
    to the expected target. Emits one result object per host and exports to CSV.
.PARAMETER InputFile
    CSV of expected DNS records.
.PARAMETER OutputFile
    Destination CSV for the validation results.
.EXAMPLE
    .\Check-DNS.ps1 -InputFile .\expected-dns.csv -OutputFile .\dns-results.csv
.NOTES
    Author : Steven Slocum
    Notes  : Portfolio copy of a real-world script. Lab values and placeholder
             secrets substituted for any originals.
#>

[cmdletbinding()]

param(

[parameter(Mandatory = $true)]
[string]$InputFile,

[parameter(Mandatory = $true)]
[string]$OutputFile

)

$results = @()
$hosts = import-csv $InputFile

foreach ($h in $hosts)
    
    {

        $error.Clear()
        $hostname = ($h.HostName + '.' + $h.suffix)
        $CNAME    = ($h.CNAME + '.' + $h.CNAMESuffix)

        
    
        $A      = @(Resolve-DnsName -dnsonly -QuickTimeout -NoHostsFile -ErrorAction SilentlyContinue -Type A -Name $hostname )

                if ($a.type -eq 'A')

                {
                    $ARecordFound = 'True'
                    Write-Host -ForegroundColor Green Forward Record Returned for $hostname
                       
                }
                else
                {
                    $ARecordFound = 'False'
                    Write-Host -ForegroundColor Red No Forward Record Returned for $hostname
                    $error.clear()
                }
            
                if (($A | Measure-Object).count -gt 1) 

                {
                    $AMulti   = 'True'
                    Write-Host -ForegroundColor Yellow Multiple Forward Records Found for $hostname
                }
                else
                {
                    $Amulti  = 'False'
                }


                if ($a.IPAddress -eq $h.ip)

                {
                    $Acorrect = 'True'
                    Write-Host -ForegroundColor Green Forward Record Matches for $hostname

                }

                else

                {
                    $Acorrect = 'False'
                    Write-Host -ForegroundColor Red Forward Record DOES NOT Match for $hostname

                }

            
        

        $PTR	= @(Resolve-DnsName -dnsonly -QuickTimeout -NoHostsFile -ErrorAction SilentlyContinue -Type PTR -Name ($h.IP))
 
 
        
                if ($PTR.type -eq 'PTR')

                {
                    $PTRRecordFound = 'True'
                    Write-Host -ForegroundColor Green Reverse Record Returned for $hostname
                       
                }
                else
                {
                    $PTRRecordFound = 'False'
                    Write-Host -ForegroundColor Red No Reverse Record Returned for $hostname
                    $error.clear()
                }

                 if (($PTR | Measure-Object).count -gt 1) 

                {
                    $PTRMulti   = 'True'
                    Write-Host -ForegroundColor Yellow Multiple Forward Records Found for $hostname
                }
                else
                {
                    $PTRmulti  = 'False'
                }

               
                if ($ptr.server -eq $hostname)

                {
                    $PTRcorrect = 'True'
                    Write-Host -ForegroundColor Green Reverse Record Matches for $hostname

                }

                else

                {
                    $PTRcorrect = 'False'
                    Write-Host -ForegroundColor Red Reverse Record DOES NOT Match for $hostname

                }

        $CRecord = @(Resolve-DnsName -dnsonly -QuickTimeout -NoHostsFile -ErrorAction SilentlyContinue -Type CNAME -Name $CNAME)
 
 
        
                if ($CRecord.type -eq 'CNAME')

                {
                    $CNAMERecordFound = 'True'
                    Write-Host -ForegroundColor Green CNAME Record Returned for $CNAME
                       
                }
                else
                {
                    $CNAMERecordFound = 'False'
                    Write-Host -ForegroundColor Red No CNAME Record Returned for $CNAME
                    $error.clear()
                }

               
                if ($CRecord.server -eq $hostname)

                {
                    $CNAMEcorrect = 'True'
                    Write-Host -ForegroundColor Green CNAME Record Matches for $CNAME

                }

                else

                {
                    $CNAMEcorrect = 'False'
                    Write-Host -ForegroundColor Red CNAME Record DOES NOT Match for $CNAME

                }



                $obj = [PSCustomObject] @{

                    Hostname                = $hostname
                    ForwardRecordFound      = $ARecordFound
                    ReverseRecordFound      = $PTRRecordFound
                    ForwardRecordCorrect    = $Acorrect
                    ReverseRecordCorrect    = $PTRcorrect
                    MultipleForwardRecord   = $Amulti
                    MultipleReverseRecord   = $PTRmulti
                    CNAME                   = $CNAME
                    CNAMERecordFound        = $CNAMERecordFound
                    CNAMERecordCorrect      = $CNAMEcorrect


 
                } # end [PSCustomObject]

$results += $obj 
    
    }


    $results | export-csv -NoTypeInformation $OutputFile
    $results | ogv
