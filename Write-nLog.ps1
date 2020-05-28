Function Write-nLog {
    <#
        .SYNOPSIS
            Standardized & Easy to use logging function.

        .DESCRIPTION
            Easy and highly functional logging function that can be dropped into any script to add logging capability with hindering script performance.

        .PARAMETER type
            Set the event level of the log event. 

            [Options] 
                Info, Warning, Error, Debug
        
        .PARAMETER message
            Set the event level of the log event.

        .INPUTS
            None

        .OUTPUTS
            None

        .NOTES
        VERSION     DATE			NAME						DESCRIPTION
	    ___________________________________________________________________________________________________________
	    1.0         25 May 2020		NRW							Initial version

        Credits:
            (1) Script Template: https://gist.github.com/9to5IT/9620683
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateSet('Debug','Error','Warning','Info')]
        [String]$Type,
        [Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=1)]
        [String[]]$Message,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=2)][ValidateRange(0,9999)]
        [Int]$ErrorCode,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=3)]
        [Switch]$TerminatingError,
        
        #Trigger per-call write-host/write-log 
        [Switch]$WriteHost,
        [Switch]$WriteLog,

        #Variables used to trigger setting global variables.
        [Switch]$Initialize,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][ValidateRange(1,4)]
        [Int]$SetLogLevel,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][ValidateScript({Test-Path $_})]
        [String]$SetLogFile,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Bool]$SetWriteHost,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Bool]$SetWriteLog
    )

    Begin {
        #Get Timestamp from when nLog was called.
        [DateTime]$tTimeStamp = [DateTime]::Now
        [Bool]$tLog = $False

        #Ensure all the default script-level variables are set.
        IF ((-Not (Test-Path variable:Script:nLogInitialize)) -OR $Initialize) {
            New-Variable -Name nLogLevel -Value 3 -Scope Script -Force
            New-Variable -Name nLogInitialize -Value $True -Force -ErrorAction SilentlyContinue -Scope Script
            IF (Test-Path variable:global:psISE) {
                New-Variable -Name nLogWriteHost -Value $True  -Scope Script -Force
                New-Variable -Name nLogWriteLog  -Value $False -Scope Script -Force
            } Else {
                New-Variable -Name nLogWriteHost -Value $False -Scope Script -Force
                New-Variable -Name nLogWriteLog  -Value $True  -Scope Script -Force
            }
            If ([String]::IsNullOrEmpty([io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.path))) {
                New-Variable -Name nLogFile -Scope Script -Force -Value "$env:ALLUSERSPROFILE\NASK\Logs\ISETestScript.log"
            } Else {
                New-Variable -Name nLogFile -Scope Script -Force -Value "$env:ALLUSERSPROFILE\NASK\Logs\$([io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.path))`.log"
            }
        }

        #Initalize of the variables.
        IF ($PSBoundParameters.ContainsKey('SetLogLevel')) {
            Set-Variable -Name nLogLevel -Value $SetLogLevel -Force -Scope Script
        }
        IF ($PSBoundParameters.ContainsKey('SetWriteHost')) {
            Set-Variable -Name nLogWriteHost -Value $SetWriteHost -Force -Scope Script
        }
        IF ($PSBoundParameters.ContainsKey('SetWriteLog')) {
            Set-Variable -Name nLogWriteLog -Value $SetWriteLog -Force -Scope Script
        }
        IF ($PSBoundParameters.ContainsKey('SetLogFile')) {
            Set-Variable -Name nLogWriteLog -Value $SetLogFile -Force -Scope Script
        }

        #Determine log level
        Switch ($Type) {
            {$Type -eq 'Debug'   -AND $Script:nLogLevel -EQ 1} {$tLevel = "[DEBUG]`t`t"; $tForeGroundColor = "Cyan"   ; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Info'    -AND $Script:nLogLevel -LE 2} {$tLevel = "[INFO]`t`t" ; $tForeGroundColor = "White"  ; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Warning' -AND $Script:nLogLevel -LE 3} {$tLevel = "[WARNING]`t"; $tForeGroundColor = "DarkRed"; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Error'   -AND $Script:nLogLevel -LE 4} {$tLevel = "[ERROR]`t`t"; $tForeGroundColor = "Red"    ; $tLog = $True; $tErrorString = "[$($ErrorCode.ToString("0000"))] " }
        }

        #Determine what we should be logging/writing. 
        IF ($WriteHost) { $tWriteHost = $True } Else { $tWriteHost = $Script:nLogWriteHost } 
        IF ($WriteLog)  { $tWriteLog  = $True } Else { $tWriteLog  = $Script:nLogWriteLog  }

        $tTimeStampString = $tTimeStamp.ToString("yyyy-mm-dd hh:mm:ss")
        
        #Ensure we have the timestamp of last entry for debug time differences
        IF (-Not (Test-Path variable:Script:nLogLastTimeStamp)) {
            New-Variable -Name nLogLastTimeStamp -Value $tTimeStamp -Scope Script -Force
        }

        #Calculate the time difference 
        $tDifference = " ($(((New-TimeSpan -Start $Script:nLogLastTimeStamp -End $tTimeStamp).Seconds).ToString(`"0000`"))`s)"

        if ($tWriteLog -and $tLog) {
            If (![System.IO.File]::Exists($Script:nLogFile)) {
                New-Item -Path (Split-path $Script:nLogFile -Parent) -Name (Split-path $Script:nLogFile -Leaf) -Force -ErrorAction Stop
            }
            $tLogWriter = [System.IO.StreamWriter]::New($Script:nLogFile,"Append")
        }
    }

    Process {
        IF ($tLog) {
            IF ($tWriteHost) { 
                Write-Host "$tTimeStampString$tDifference`t$tErrorString$Message" -ForegroundColor $tForeGroundColor
            }
        
            IF ($tWriteLog)  {
                $LogWriter.WriteLine("$tTimeStampString$tDifference`t$tErrorCode$Message")
            }
            #Ensure we have the timestamp of the last log execution.
            Set-Variable -Name nLogLastTimeStamp -Scope Script -Value $tTimeStamp -Force
        }
    }

    End {
        if ($tWriteLog -and $tLog) {
            $tLogWriter.Flush()
            $tLogWriter.Close()
        }

        #Cleanup Used Variables to make ISE development more consistent. 
        Get-Variable -Name * -Scope Local |Where-Object { (@("WriteHost","WriteLog","Type","tTimeStampString","tTimeStamp","tLog","TerminatingError","tDifference","SetLogLevel","SetLogFile","ErrorCode","Message","Initialize","SetWriteHost","SetWriteLog","tWriteLog","tWriteHost","tLogWriter") -contains $_.Name) } |Remove-Variable
        
        #Allow us to exit the script from the logging function.
        If ($TerminatingError) {
            Exit
        }
    }

}
Get-Help Write-nLog -full