Function Write-nLog {
    <#
        .SYNOPSIS
            Standardized & Easy to use logging function.

        .DESCRIPTION
            Easy and highly functional logging function that can be dropped into any script to add logging capability without hindering script performance.

        .PARAMETER type
            Set the event level of the log event. 

            [Options]
                Info, Warning, Error, Debug
        
        .PARAMETER message
            Set the message text for the event.


        .PARAMETER ErrorCode
            Set the Error code for Error & fatal level events. The error code will be displayed in front of 
            the message text for the event.

        .PARAMETER WriteHost
            Force writing to host reguardless of SetWriteLog setting for this specific instance.

        .PARAMETER WriteLog
            Force writing to log reguardless of SetWriteLog setting for this specific instance.

        .PARAMETER SetLogLevel
            Set the log level for the nLog function for all future calls. When setting a log level all logs at 
            the defined level will be logged. If you set the log level to warning (default) warning messages 
            and all events above that such as error and fatal will also be logged. 

            (1) Debug: Used to document events & actions within the script at a very detailed level. This level 
            is normally used during script debugging or development and is rarely set once a script is put into
            production

            (2) Information: Used to document normal application behavior and milestones that may be useful to 
            keep track of such. (Ex. File(s) have been created/removed, script completed successfully, etc)

            (3) Warning: Used to document events that should be reviewed or might indicate there is possibly
            unwanted behavior occuring.

            (4) Error: Used to document non-fatal errors indicating something within the script has failed.

            (5) Fatal: Used to document errors significant enough that the script cannot continue. When fatal
            errors are called with this function the script will terminate. 
        
            [Options]
                1,2,3,4,5

        .PARAMETER SetLogFile
            Set the fully quallified path to the log file you want used. If not defined, the log will use the 
            "$Env:SystemDrive\ProgramData\Scripts\Logs" directory and will name the log file the same as the 
            script name. 

        .PARAMETER SetWriteHost
            Configure if the script should write events to the screen. (Default: $False)

            [Options]
                $True,$False
        
        .PARAMETER SetWriteLog
            Configure if the script should write events to the screen. (Default: $True)

            [Options]
                $True,$False
        
        .INPUTS
            None

        .OUTPUTS
            None

        .NOTES
        VERSION     DATE			NAME						DESCRIPTION
	    ___________________________________________________________________________________________________________
	    1.0         25 May 2020		HellBomb					Initial version

        Credits:
            (1) Script Template: https://gist.github.com/9to5IT/9620683
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateSet('Debug','Info','Warning','Error','Fatal')]
        [String]$Type,
        [Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=1)]
        [String[]]$Message,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=2)][ValidateRange(0,9999)]
        [Int]$ErrorCode,
        
        #Trigger per-call write-host/write-log 
        [Switch]$WriteHost,
        [Switch]$WriteLog,

        #Variables used to trigger setting global variables.
        [Switch]$Initialize,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][ValidateRange(1,5)]
        [Int]$SetLogLevel,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
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
                New-Variable -Name nLogFile -Scope Script -Force -Value "$env:ALLUSERSPROFILE\Scripts\Logs\ISETestScript.log"
            } Else {
                New-Variable -Name nLogFile -Scope Script -Force -Value "$env:ALLUSERSPROFILE\Script\Logs\$([io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.path))`.log"
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
            Set-Variable -Name nLogFile -Value $SetLogFile -Force -Scope Script
        }

        #Determine log level
        Switch ($Type) {
            {$Type -eq 'Debug'   -AND $Script:nLogLevel -EQ 1} {$tLevel = "[DEBUG]`t`t"; $tForeGroundColor = "Cyan"   ; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Info'    -AND $Script:nLogLevel -LE 2} {$tLevel = "[INFO]`t`t" ; $tForeGroundColor = "White"  ; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Warning' -AND $Script:nLogLevel -LE 3} {$tLevel = "[WARNING]`t"; $tForeGroundColor = "DarkRed"; $tLog = $True; $tErrorString = [String]::Empty }
            {$Type -eq 'Error'   -AND $Script:nLogLevel -LE 4} {$tLevel = "[ERROR]`t`t"; $tForeGroundColor = "Red"    ; $tLog = $True; $tErrorString = "[$($ErrorCode.ToString("0000"))] " }
            {$Type -eq 'Fatal'   -AND $Script:nLogLevel -LE 5} {$tLevel = "[FATAL]`t`t"; $tForeGroundColor = "Red"    ; $tLog = $True; $tErrorString = "[$($ErrorCode.ToString("0000"))] " }
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
            If (-NOT [System.IO.File]::Exists($Script:nLogFile)) {
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
                $tLogWriter.WriteLine("$tTimeStampString$tDifference`t$tErrorCode$Message")
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
        If ($Type -eq 'Fatal') {
            Exit
        }
    }
}
