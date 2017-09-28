#################################################
############ created by Jakob ###################
#### variables to changed on line 51 and 52. ####
#################################################

$script = {
param(
    [parameter(mandatory=$true)][string[]]$computers
)

$domain = $env:USERDNSDOMAIN # Don't change
$query  = New-Object System.DirectoryServices.DirectorySearcher
$ldapcon = [adsi]"LDAP://$domain"
$query.SearchRoot = "LDAP://$($domain)" 

$result = @()

foreach($com in $computers){
    $query.Filter= "(cn=$com)"
    $test = $query.FindAll()
    if(!$test){$result += "Could not find computer object $com"; continue}

    $date1 = ($test.Properties).whenchanged
    $date2 = (Get-Date).adddays(-90)


    if($date1 -gt $date2){
        
        $result += "server $com last changed $date1"
         
    }
    else{
        if(Test-Connection -ComputerName "$($com).$($domain)" -Count 1 -ErrorAction SilentlyContinue){
            $result += "server $com last changed $date1 and is online, please check as the AD object has not changed for over 90 days"
        }
        else{
            $result += "server $com last changed $date1 and is not online"
        }

    }
}

[string]$outstr = ""

foreach($out in $result){
    $outstr = "$outstr" + "$out`n"    
}
return $outstr
}

$input = Get-Content C:\Users\ub8ze\Desktop\seti.txt  #computer list file path
$logPath = "C:\Users\ub8ze\Desktop"  #path where the log files will be created


#do not alter the other variables
$RunspaceNum = 20
$RecordNum = $input.Count
$mod = $RecordNum%$RunspaceNum
$arrayNum = ($RecordNum-$mod)/$RunspaceNum
$lastArrayNum = 1
$y = 1
$xInit = 0


for($x=1;$x-le $RunspaceNum; $x++){
    New-Variable -Name "Arr$X" -Value @()
}


for($x=0; $x -le $RecordNum; $x++){
    if(($x-$xInit) -ne $arrayNum -and $lastArrayNum -ne $RunspaceNum){
        if(![string]::IsNullOrEmpty($input[$x])){
            (Get-Variable -Name "Arr$y").Value += $input[$x]
        }
        Else{
            continue
        }
    }    
    elseif(($x-$xInit) -eq $arrayNum -and $lastArrayNum -ne $RunspaceNum){
        $xInit = $x
        $y++
        $lastArrayNum++
        if(![string]::IsNullOrEmpty($input[$x])){
            (Get-Variable -Name "Arr$y").Value += $input[$x]
        }
        Else{
            continue
        }
    }
    elseif($lastArrayNum -eq $RunspaceNum){
        if(![string]::IsNullOrEmpty($input[$x])){
            (Get-Variable -Name "Arr$y").Value += $input[$x]
        }
        Else{
            continue
        }
    }
}

$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$runspacepool = [runspacefactory]::CreateRunspacePool(1,5,$iss,$host)
$runspacepool.Open()

$startTime = Get-Date
$Jobs = @()

for($x = 1; $x -le $RunspaceNum; $x++){
    $Job = [powershell]::Create().AddScript($Script).addParameter("Computers",(Get-Variable -Name "arr$X").Value)
    $Job.RunspacePool = $RunspacePool

    $Jobs += New-Object PSObject -Property @{
      RunNum = $_
      Job = $Job
      Result = $Job.BeginInvoke()
   }

}

Write-Host "Waiting.." -NoNewline
Do {
   Write-Host "." -NoNewline
   Start-Sleep -Seconds 1
} While ( $Jobs.Result.IsCompleted -contains $false) #Jobs.Result is a collection

$tmpstr = @()

foreach($output in $Jobs){
     $tmpstr +="$($output.job.endInvoke($output.result))"
     $output.Job.Dispose()
     $output.result = $null
}
$RunspacePool.close()
$RunspacePool.Dispose()

$tmpstr.split([environment]::newline) | %{
    if(![string]::IsNullOrEmpty($_) -and $_ -match "not online"){
        $_ >> "$($logPath)\Badlist$((get-date -Format hh:mm).Replace(":","-")).txt"
    }
    Elseif(![string]::IsNullOrEmpty($_)){
         $_ >> "$($logPath)\goodlist$((get-date -Format hh:mm).Replace(":","-")).txt"
    }
}

$endTime = Get-Date
$totalSeconds = "{0:N4}" -f ($endTime-$startTime).TotalSeconds
Write-Host "All files created in $totalSeconds seconds"


Remove-Variable -Name Jobs
Remove-Variable -Name Job
Remove-Variable -Name ISS

for($x=1;$x-le $RunspaceNum; $x++){
    remove-Variable -Name "Arr$X"
}
