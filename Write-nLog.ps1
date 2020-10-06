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
            Set the Error code for Error & fatal level events. The error code will be displayed in front of the message text for the event.
            

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
        
        .PARAMETER Close
            Removes all script-level variables set while nLog creates while running.

        .INPUTS
            None

        .OUTPUTS
            None

        .NOTES
        VERSION     DATE			NAME						DESCRIPTION
	    ___________________________________________________________________________________________________________
	    1.0			25 May 2020		Warila, Nicholas R.			Initial version
        2.0			28 Aug 2020		Warila, Nicholas R.			Complete rewrite of major portions of the script, significant improvement in script performance (about 48%), and updated log format.

        Credits:
            (1) Script Template: https://gist.github.com/9to5IT/9620683
    #>
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [ValidateSet('Debug','Info','Warning','Error','Fatal')]
        [String]$Type,
        [Parameter(Mandatory=$True,ValueFromPipeline=$False,Position=1)]
        [String[]]$Message,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False,Position=2)][ValidateRange(0,9999)]
        [Int]$ErrorCode = 0,
        [Switch]$WriteHost,
        [Switch]$WriteLog,
        [Switch]$Initialize,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)][ValidateRange(1,5)]
        [Int]$SetLogLevel,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [String]$SetLogFile,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Bool]$SetWriteHost,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [Bool]$SetWriteLog,
        [Switch]$Close
    )

    #Best practices to ensure function works exactly as expected, and prevents adding "-ErrorAction Stop" to so many critical items.
    $Local:ErrorActionPreference = 'Stop'
    Set-StrictMode -Version Latest

    #Allows us to turn on verbose on all powershell commands when adding -verbose
    IF ($PSBoundParameters.ContainsKey('Verbose')) {
        Set-Variable -Name Verbose -Value $True
    } Else {
        Set-Variable -Name Verbose -Value $False
    }

    New-Variable -Name StartTime    -Value ([DateTime]::Now)                                                                       -Force -Verbose:$Verbose -Description "Used to calculate timestamp differences between log calls."
    New-Variable -Name StartTimeUTC -Value ([DateTime]::UtcNow.ToString("s",[System.Globalization.CultureInfo]::InvariantCulture)) -Force -Verbose:$Verbose -Description "Used to for logfile timestamp."

    #Ensure all the required script-level variables are set.
    IF ((-Not (Test-Path variable:Script:nLogInitialize)) -OR $Initialize) {
        New-Variable -Name nLogLevel         -Verbose:$Verbose -Scope Script -Force -Value ([Int]3)
        New-Variable -Name nLogInitialize    -Verbose:$Verbose -Scope Script -Force -Value $True
        New-Variable -Name nLogWriteHost     -Verbose:$Verbose -Scope Script -Force -Value $False
        New-Variable -Name nLogWriteLog      -Verbose:$Verbose -Scope Script -Force -Value $True
        New-Variable -Name nLogDir           -Verbose:$Verbose -Scope Script -Force -Value $Env:TEMP
        New-Variable -Name nLogLastTimeStamp -Verbose:$Verbose -Scope Script -Force -Value $StartTime
        New-Variable -Name nLogFileValid     -Verbose:$Verbose -Scope Script -Force -Value $False
        If ([String]::IsNullOrEmpty([io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.path))) {
            New-Variable -Name nLogFile -Scope Script -Force -Verbose:$Verbose -Value "Untitled.log"
        } Else {
            New-Variable -Name nLogFile -Scope Script -Force -Verbose:$Verbose -Value "$([io.path]::GetFileNameWithoutExtension($script:MyInvocation.MyCommand.path))`.log"
        }
        New-Variable -Name nLogFullName      -Verbose:$Verbose -Scope Script -Force -Value (Join-Path -Path $Script:nLogDir -ChildPath $Script:nLogFile)
        New-Variable -Name nLogLevels        -Verbose:$Verbose -Scope Script -Force -Value $([HashTable]@{
            Debug   = @{ Text = "[DEBUG]  "; LogLevel = [Int]'1'; tForeGroundColor = "Cyan";   }
            Info    = @{ Text = "[INFO]   "; LogLevel = [Int]'2'; tForeGroundColor = "White";  }
            Warning = @{ Text = "[WARNING]"; LogLevel = [Int]'3'; tForeGroundColor = "DarkRed";}
            Error   = @{ Text = "[ERROR]  "; LogLevel = [Int]'4'; tForeGroundColor = "Red";    }
            Fatal   = @{ Text = "[FATAL]  "; LogLevel = [Int]'5'; tForeGroundColor = "Red";    }
        })
    }

    #Initalize of the variables.
    IF ($PSBoundParameters.ContainsKey('SetLogLevel')) {
        Set-Variable -Name nLogLevel     -Verbose:$Verbose -Scope Script -Force -Value $SetLogLevel
    }
    IF ($PSBoundParameters.ContainsKey('SetWriteHost')) {
        Set-Variable -Name nLogWriteHost -Verbose:$Verbose -Scope Script -Force -Value $SetWriteHost
    }
    IF ($PSBoundParameters.ContainsKey('SetWriteLog')) {
        Set-Variable -Name nLogWriteLog  -Verbose:$Verbose -Scope Script -Force -Value $SetWriteLog
    }
    IF ($PSBoundParameters.ContainsKey('SetLogDir')) {
        Set-Variable -Name nLogDir       -Verbose:$Verbose -Scope Script -Force -Value $SetLogDir
        Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $False
    }
    IF ($PSBoundParameters.ContainsKey('SetLogFile')) {
        Set-Variable -Name nLogFile      -Verbose:$Verbose -Scope Script -Force -Value "$($SetLogFile -replace "[$([string]::join('',([System.IO.Path]::GetInvalidFileNameChars())) -replace '\\','\\')]",'_').`log"
        Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $False
    }

    IF ($PSBoundParameters.ContainsKey('WriteHost')) { $tWriteHost = $True } Else { $tWriteHost = $Script:nLogWriteHost }
    IF ($PSBoundParameters.ContainsKey('WriteLog'))  { $tWriteLog  = $True } Else { $tWriteLog  = $Script:nLogWriteLog  }

    #Determine if script log level greater than or equal to current log event level and we actually are configured to write something.
    IF ($Script:nLogLevels[$Type]["LogLevel"] -ge $Script:nLogLevel -AND ($tWriteHost -EQ $True -OR $tWriteLog -EQ $True)) {

        #Code Block if writing out to log file.
        if ($tWriteLog) {
            IF ($Script:nLogFileValid -eq $False) {
                Set-Variable -Name nLogFullName      -Verbose:$Verbose -Scope Script -Force -Value (Join-Path -Path $Script:nLogDir -ChildPath $Script:nLogFile)
                If ([System.IO.File]::Exists($Script:nLogFullName)) {
                    Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $True
                } Else {
                    New-Item -Path $Script:nLogFullName -Force -Verbose:$Verbose
                    Set-Variable -Name nLogFileValid -Verbose:$Verbose -Scope Script -Force -Value $True
                }
            }
            $StreamWriter = [System.IO.StreamWriter]::New($Script:nLogFullName,$True,([Text.Encoding]::UTF8))
            $StreamWriter.WriteLine("$StartTimeUTC||$Env:COMPUTERNAME||$Type||$($ErrorCode.ToString(`"0000`"))||$($MyInvocation.ScriptLineNumber)||$Message")
            $StreamWriter.Close()
        }

        #Code Block if writing out to log host.
        IF ($tWriteHost) {
            Write-Host -ForegroundColor $Script:nLogLevels[$Type]["tForeGroundColor"] -Verbose:$Verbose "$StartTime ($(((New-TimeSpan -Start $Script:nLogLastTimeStamp -End $StartTime -Verbose:$Verbose).Seconds).ToString('0000'))s) $($Script:nLogLevels[$Type]['Text']) [$($ErrorCode.ToString('0000'))] [Line: $($MyInvocation.ScriptLineNumber.ToString('0000'))] $Message"
        }
                
        #Ensure we have the timestamp of the last log execution.
        Set-Variable -Name nLogLastTimeStamp -Scope Script -Value $StartTime -Force -Verbose:$Verbose
    }
    
    #Remove Function Level Variables
    Remove-Variable -Name @("Message","SetLogLevel","SetLogFile","Close","SetWriteLog","SetWriteHost","LineNumber","ErrorCode","tWriteHost","WriteHost","tWriteLog","WriteLog","StartTime") -ErrorAction SilentlyContinue

    IF ($PSBoundParameters.ContainsKey('Close') -or $Type -eq 'Fatal') {
        Remove-Variable -Name @("nLogLastTimeStamp","nLogFileValid","nLogFile","nLogDir","nLogWriteLog","nLogWriteHost","nLogInitialize","nLogLastTimeStamp","nLogLevels","nLogFullName","nLogLevel") -Scope Script -ErrorAction SilentlyContinue
    }

    #Allow us to exit the script from the logging function.
    If ($Type -eq 'Fatal') {
        Exit
    }
}
