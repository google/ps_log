<#
Copyright 2019 Google LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
#>

#Requires -Version 3

<#
.SYNOPSIS
  A collection of log management functions.
.DESCRIPTION
  This collection of log management functions enhances support for logging
  in PowerShell scripts. There are a set of preference variables that can be
  set in your script to modify the behavior of these functions.

  Output Levels: Each of these output channels can be set to a level that
  determines when a message will be logged through that channel. Log levels are
  any of these values: DEBUG, INFO, WARNING, ERROR, FATAL. When you set the
  level of an output channel, you are indicating that any message of that
  severity or greater should be logged on that channel.

  $global:PSLogEventLevel
      The minimum severity for a message to be logged to the Windows Event Log.
      Defaults to WARNING.
  $global:PSLogFileLevel
      The minimum severity for a message to be logged to a log file. Defaults
      to WARNING.
  $global:PSLogSerialLevel
      The minimum severity for a message to be logged to a serial port. Defaults
      to $null.
  $global:PSLogVerbosity
      The minimum severity for a message to be logged to the conosle. Defaults
      to INFO.

  Output Settings:

  $global:PSLogFile
      If set to a file path, Out-Log* functions will append lines here.
  $global:PSLogSource
      Windows Events will have a Source of this variable's value, if set.
  $global:PSLogSerialPort
      If set to a port name that exists (e.g., 'COM1'), Out-Log* functions will append lines here.
#>

# Define a list of log levels
Set-Variable -Name LOG_LEVELS -Value @('DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL') -Option Constant
# Set numeric values for log levels
Set-Variable -Name LL_DEBUG -Value 0 -Option Constant
Set-Variable -Name LL_INFO -Value 1 -Option Constant
Set-Variable -Name LL_WARNING -Value 2 -Option Constant
Set-Variable -Name LL_ERROR -Value 3 -Option Constant
Set-Variable -Name LL_FATAL -Value 4 -Option Constant
# Set default levels
if (-not $global:PSLogVerbosity) {
  $global:PSLogVerbosity = $LOG_LEVELS[$LL_WARNING]
}
if (-not $global:PSLogEventLevel) {
  $global:PSLogEventLevel = $LOG_LEVELS[$LL_WARNING]
}
if (-not $global:PSLogFileLevel) {
  $global:PSLogFileLevel = $LOG_LEVELS[$LL_INFO]
}
if (-not $global:PSLogSerialLevel) {
  $global:PSLogSerialLevel = $null
}


function Out_Log {
  <#
  .SYNOPSIS
    Writes a DEBUG message to the event log, and optionally a log file.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message(s) to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to. File will be
    created if it doesn't exist.
  .EXAMPLE
    Out-LogDebug 'This is a simple message.'
  .EXAMPLE
    Out-LogDebug -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [string]$EventLogName = 'Application',
    [int]$EventId,
    [Parameter(Mandatory=$true)]
    [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL')]
    [string]$LogLevel,
    [string]$LogFile
  )

  begin {
    # Map LogLevel to EventLog EntryTypes
    $loglevel_entrytype_map = @{
      DEBUG =   'Information'
      INFO =    'Information'
      WARNING = 'Warning'
      ERROR =   'Error'
      FATAL =   'Error'
    }

    # Define LogLevel prefixes
    $loglevel_tags = @{
      DEBUG =   '[D]'
      INFO =    '[I]'
      WARNING = '[W]'
      ERROR =   '[E]'
      FATAL =   '[F]'
    }
  }

  process {
    # Grab the current time
    $timestamp = Get-Date -Format u

    # Translate LogLevel to a numeric value
    $log_level = Get-Variable -Name "LL_$LogLevel" -ValueOnly

    # Sort out which value we are going to use.
    # Source
    if ($Source) {
      $src = $Source
    }
    elseif ($global:PSLogSource) {
      $src = $global:PSLogSource
    }
    else {
      $src = 'ps_log'
    }
    # Log file
    if ($LogFile) {
      $log_file = $LogFile
    }
    elseif ($global:PSLogFile) {
      $log_file = $global:PSLogFile
    }
    else {
      $log_file = ''
    }
    # Serial port
    if ($global:PSLogSerialLevel) {
      if ($log_level -ge (Get-Variable -Name "LL_$global:PSLogSerialLevel" -ValueOnly)) {
        if ($global:PSLogSerialPort) {
          if (Get_SerialPorts -Name $global:PSLogSerialPort) {
            $com_port = $global:PSLogSerialPort
          }
        }
      }
    }
    else {
      $com_port = $null
    }

    # Break message(s) into individual lines
    $message_list = @()
    foreach ($mess in $Message) {
      # Preserve empty lines, but accomodate different EOL combinations
      $message_list += ,$mess -split '\r?\n'
    }

    # Output to Event Log?
    if ($log_level -ge (Get-Variable -Name "LL_$global:PSLogEventLevel" -ValueOnly)) {
      Write_Event `
          -Message ($loglevel_tags[$LogLevel] + ' ' + ($message_list -join "`n")) `
          -Source $src `
          -EventID $EventID `
          -EntryType $loglevel_entrytype_map[$LogLevel] `
          -EventLogName Application
    }

    # Output to log file?
    if ($log_file) {
      if ($log_level -ge (Get-Variable -Name "LL_$global:PSLogFileLevel" -ValueOnly)) {
        $file_prefix = ($timestamp, $env:computername, "$($src):", $loglevel_tags[$LogLevel]) -join "`t"
        foreach ($mess in $message_list) {
        $file_message = "$file_prefix`t$mess"
          Write-Log -Message $file_message -LogFile $log_file
        }
      }
    }

    # Output to serial port?
    if ($com_port) {
      $serial_prefix = ($timestamp, "$($src):", $loglevel_tags[$LogLevel]) -join ' '
      foreach ($mess in $message_list) {
        $serial_message = "$serial_prefix $mess"
        Write_ToSerialPort -PortName $com_port -Data $serial_message
      }
    }

    # Output to console?
    if ($log_level -ge (Get-Variable -Name "LL_$global:PSLogVerbosity" -ValueOnly)) {
      $console_prefix = $timestamp
      # Write-Error is itself multi-line, structured output, so use a single message
      if ($log_level -ge $LL_ERROR) {
        $console_message = "$console_prefix $($message_list -join "`n")"
        switch ($LogLevel) {
          'ERROR' {
            # Examine the callstack to find where the call to Write-Error was made from
            $caller = (Get-PSCallStack)[2]
            $exception = New-Object System.Exception `
                -ArgumentList (($console_message, $caller, $caller.Position.Text) -join "`n")
            $error_record = New-Object System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, 'Out-LogError', ([System.Management.Automation.ErrorCategory]::NotSpecified), $null
            Write-Error -ErrorRecord $error_record
          }
          'FATAL' {
            # Examine the callstack to find where the call to Write-Fatal was made from
            $caller = (Get-PSCallStack)[2]
            $exception = New-Object System.Exception `
                -ArgumentList (($console_message, $caller, $caller.Position.Text) -join "`n")
            $error_record = New-Object System.Management.Automation.ErrorRecord `
                -ArgumentList $exception, 'Out-LogFatal', ([System.Management.Automation.ErrorCategory]::NotSpecified), $null
            Write-Error -ErrorRecord $error_record
          }
          default {
            throw "I was asked to write '$console_message', but I don't know " +
                'my log level, so now I must die.'
          }
        }
      }
      # All other output streams get one line per line
      else {
        foreach ($mess in $message_list) {
          $console_message = "$console_prefix $mess"
          switch ($LogLevel) {
            'DEBUG' {
              $DebugPreference = 'Continue'
              Write-Debug $console_message
            }
            'INFO' {
              Write-Verbose -Verbose $console_message
            }
            'WARNING' {
              Write-Warning $console_message
            }
            default {
              throw "I was asked to write '$console_message', but I don't know " +
                  'my log level, so now I must die.'
            }
          }
        }
      }
    }
  }
}

function Convert_ErrorToString {
  <#
  .SYNOPSIS
    Converts an ErrorRecord into a string
  .DESCRIPTION
    This is a helper function which prints out error messages in catch

    Based on _WriteToSerialPort from the Google GCE PowerShell module:
      https://raw.githubusercontent.com/GoogleCloudPlatform/compute-image-windows/master/gce/sysprep/gce_base.psm1
  .OUTPUTS
    Error message found during execution is printed out to the console.

  .EXAMPLE
    Convert_ErrorToString $error[0]
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=1)]
    [System.Management.Automation.ErrorRecord[]]$Record
  )

  process {
    try {
      $message = $Record.Exception[0].Message
      $line_no = $Record.InvocationInfo[0].ScriptLineNumber
      $line_info = $Record.InvocationInfo[0].Line
      $hresult = $Record.Exception[0].HResult
      if ($Record.InvocationInfo[0].ScriptName) {
        $calling_script = $Record.InvocationInfo[0].ScriptName
      }
      else {
        $calling_script = 'INTERACTIVE'
      }

      # Format error string
      if ($Record.Exception[0].InnerException) {
        $inner_msg = $Record.Exception[0].InnerException.Message
        $errmsg = "$inner_msg  : $message {Line: $line_no : $line_info, HResult: $hresult, Script: $calling_script}"
      }
      else {
        #$errmsg = "$message {Line: $line_no : $line_info, HResult: $hresult, Script: $calling_script}"
        $errmsg = "$message {$hresult, $calling_script`:$line_no}"
      }
      # Write message to output.
      return $errmsg
    }
    catch {
      Write-Error $_.Exception.GetBaseException().Message
    }
  }
}

function Convert_MessageToString {
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message
  )

  process {
    if ($Message) {
      foreach ($mess in $Message) {
        if ($mess -eq $null) {return}
        switch ($mess.GetType().Name) {
          'ErrorRecord' {
            $m = Convert_ErrorToString -Record $mess
          }
          'String' {
            $m = $mess
          }
          default {
            try {
              $m = $mess.ToString()
            }
            catch [System.Management.Automation.RuntimeException] {
              $m = "<Unable to log message of type $_>"
            }
          }
        }
        $m | Write-Output
      }
    }
  }
}

function Invoke_Exit {
  param (
    [Parameter(Mandatory=$true)]
    [int]$ExitCode
  )

  exit $ExitCode
}

function Out-LogDebug {
  <#
  .SYNOPSIS
    Writes a DEBUG message to the event log, and optionally a log file.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to.
    File will be created if it doesn't exist.
  .EXAMPLE
    Out-LogDebug 'This is a simple message.'
  .EXAMPLE
    Out-LogDebug -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [int]$EventId,
    [string]$LogFile
  )

  process {
    $Message |
        Convert_MessageToString |
        Out_Log -Source $Source -EventID $EventId -LogLevel DEBUG -LogFile $LogFile
  }
}

function Out-LogInfo {
  <#
  .SYNOPSIS
    Writes a INFO message to the event log, and optionally a log file.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to. File will be
    created if it doesn't exist.
  .EXAMPLE
    Out-LogInfo 'This is a simple message.'
  .EXAMPLE
    Out-LogInfo -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [int]$EventID,
    [string]$LogFile
  )

  process {
    $Message |
        Convert_MessageToString |
        Out_Log -Source $Source -EventID $EventId -LogLevel INFO -LogFile $LogFile
  }
}

function Out-LogWarn {
  <#
  .SYNOPSIS
    Writes a WARNING message to the event log, and optionally a log file.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to. File will be
    created if it doesn't exist.
  .EXAMPLE
    Out-LogWarn 'This is a simple message.'
  .EXAMPLE
    Out-LogWarn -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [int]$EventID,
    [string]$LogFile
  )

  process {
    $Message |
        Convert_MessageToString |
        Out_Log -Source $Source -EventID $EventId -LogLevel WARNING -LogFile $LogFile
  }
}

function Out-LogError {
  <#
  .SYNOPSIS
    Writes a ERROR message to the event log, and optionally a log file.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to. File will be
    created if it doesn't exist.
  .EXAMPLE
    Out-LogError 'This is a simple message.'
  .EXAMPLE
    Out-LogError -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [int]$EventID,
    [string]$LogFile
  )

  process {
    $Message |
        Convert_MessageToString |
        Out_Log -Source $Source -EventID $EventId -LogLevel ERROR -LogFile $LogFile
  }
}

function Out-LogFatal {
  <#
  .SYNOPSIS
    Writes a FATAL message to the event log, optionally a log file, and exits.
  .DESCRIPTION
    This function is used to compile a log message, and the output it to the
    event log, and a log file if one has been configured.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Becomes the 'Source' for the
    Event Log event. Value will override $global:PSLogSource.
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .PARAMETER LogFile
    The path to the log file that Message will be appended to. File will be
    created if it doesn't exist.
  .PARAMETER ExitCode
    Out-LogFatal terminates the session after emitting messages. Exit code is 1 by default.
  .EXAMPLE
    Out-LogFatal 'This is a simple message.'
  .EXAMPLE
    Out-LogFatal -Message 'This is a more complex message.' -Source 'NoisyScript' -LogFile 'c:\managed\log\NoisyScript.log'
  #>

  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline=$true, Position=0)]
    [AllowEmptyString()]
    [AllowEmptyCollection()]
    [AllowNull()]
    $Message,
    [string]$Source,
    [int]$EventID,
    [string]$LogFile,
    [int]$ExitCode = 1
  )

  process {
    $Message |
        Convert_MessageToString |
        Out_Log -Source $Source -EventID $EventId -LogLevel FATAL -LogFile $LogFile
  }
  end {
    Invoke_Exit $ExitCode
  }
}

function Write_Event {
  <#
  .SYNOPSIS
    A helper function that writes a message to the Windows Event Log.
  .DESCRIPTION
    This function is used to produce consistant Windows Events.
  .PARAMETER Message
    The message to write/log.
  .PARAMETER Source
    The name of the process calling this function. Used as a "Source" for
    the Windows Events. The source will be created if missing.
  .PARAMETER EventLogName
    The name of the Windows Event Log to record events in.
  .PARAMETER LogLevel
    The severity of the message, choosing from:
        'DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL'. The LogLevel is used
    to derive the approprate EntryType.
  .PARAMETER EventLogIncludeFilter
    A list of LogLevels which will cause a Windows Event to be created.
    Defaults to 'WARNING', 'ERROR', 'FATAL'
  .PARAMETER EventID
    The EventID to be used in a Windows Event. Defaults to 0.
  .EXAMPLE
    Write_Event -Message "Lorem Ipsum" -LogLevel INFO -Source 'MyScript' -EventLogIncludeFilter @(INFO, WARNING, ERROR)
        Console output:
            [I] Lorem Ipsum
        Event created:
            EntryType: Information
            Source: BLAHMON
            InstanceID: 0
            Message: 2014-08-24 17:33:44Z COMPUTERNAME [MyScript] [I] Lorem Ipsum
  .INPUTS
    This function does not accept pipeline input.
  .OUTPUTS
    Creates an EventLog event
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]
    [AllowEmptyString()]
    [string]$Message,
    [Parameter(Mandatory=$true)]
    [string]$Source,
    [ValidateSet('Information', 'Warning', 'Error')]
    [string]$EntryType = 'Information',
    [string]$EventLogName = 'Application',
    [int]$EventID = 0
  )
  $loglevel_entrytype_map = @{
    DEBUG =   'Information'
    INFO =    'Information'
    WARNING = 'Warning'
    ERROR =   'Error'
    FATAL =   'Error'
  }

  $event_recorded = $false
  $event_failed = $false

  try {
    try {
      Write-EventLog `
        -LogName $EventLogName `
        -Source $Source `
        -EntryType $EntryType `
        -EventID $EventID `
        -Message $Message `
        -ErrorAction Stop
      $event_recorded = $true
    }
    catch {
      if (('SecurityException', 'InvalidOperationException') -contains $_.Exception.GetType().Name) {
        try {
          New-EventLog -LogName $EventLogName -Source $Source -ErrorAction Stop
        }
        catch {
          if ($_.Exception.InnerException.GetType().Name -eq 'SecurityException') {
            Write-Warning 'ps_log: Cannot create event source, no Windows Event will be recorded!'
            $event_failed = $true
          }
          else {
            $event_failed = $true
            throw $_
          }
        }
      }
      else {
        $event_failed = $true
        throw $_
      }
    }
  }
  catch {
    throw $_
  }
  finally {
    # If we successfully created the source, then try to write the event once more
    try {
      if ($event_recorded -eq $false -and
          $event_failed -eq $false) {
          Write-EventLog `
              -LogName $EventLogName `
              -Source $Source `
              -EntryType $EntryType `
              -EventID $EventID `
              -Message $Message `
              -ErrorAction Stop
      }
    }
    catch {
      if (('SecurityException', 'InvalidOperationException') -contains $_.Exception.GetType().Name) {
        Write-Warning 'ps_log: Cannot access event log, no Windows Event will be recorded!'
      }
      else {
        throw $_
      }
    }
  }
}

function Get_SerialPorts  {
  <#
  .SYNOPSIS
    Get available serial ports. Check if a port exists, if yes returns $true
  .DESCRIPTION
    This function is used to check if a port exists on this machine.

    Based on _GetCOMPorts from the Google GCE PowerShell module:
      https://raw.githubusercontent.com/GoogleCloudPlatform/compute-image-windows/master/gce/sysprep/gce_base.psm1
  .PARAMETER $Name
    Name of the port you want to check if it exists.
  .OUTPUTS
    [boolean]
  .EXAMPLE
    Get_SerialPorts -Name 'COM1'
  #>

  param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Name
  )

  $exists = $false
  try {
    # Read available Serial ports.
    $com_ports = [System.IO.Ports.SerialPort]::getportnames()
    if ($com_ports -match $Name) {
      $exists = $true
    }
  }
  catch {
    Write-Error $_
  }
  return $exists
}


function Write_ToSerialPort {
  <#
  .SYNOPSIS
    Sending data to serial port.
  .DESCRIPTION
    Use this function to send data to serial port.

    Based on _WriteToSerialPort from the Google GCE PowerShell module:
      https://raw.githubusercontent.com/GoogleCloudPlatform/compute-image-windows/master/gce/sysprep/gce_base.psm1
  .PARAMETER PortName
    Name of port. The port to use (for example, COM1).
  .PARAMETER BaudRate
    The baud rate.
  .PARAMETER Parity
    Specifies the parity bit for a SerialPort object.
    None: No parity check occurs (default).
    Odd: Sets the parity bit so that the count of bits set is an odd number.
    Even: Sets the parity bit so that the count of bits set is an even number.
    Mark: Leaves the parity bit set to 1.
    Space: Leaves the parity bit set to 0.
  .PARAMETER DataBits
    The data bits value.
  .PARAMETER StopBits
    Specifies the number of stop bits used on the SerialPort object.

    None: No stop bits are used. This value is Currently not supported by the
          StopBits.
    One:  One stop bit is used (default).
    Two:  Two stop bits are used.
    OnePointFive: 1.5 stop bits are used.
  .PARAMETER Data
    Data to be sent to serial port.
  .PARAMETER Wait
    Wait for result of data sent.
  .PARAMETER Close
    Remote close connection.
  .EXAMPLE
    Send data to serial port and exit.

    Write_ToSerialPort -PortName COM1 -Data 'Hello World'
  .EXAMPLE
    Send data to serial port and wait for respond.
    Write_ToSerialPort -PortName COM1 -Data 'dir C:\' -Wait
  #>
  [CmdletBinding(supportsshouldprocess=$true)]
  param (
    [parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
    [string]$portname,
    [Int]$BaudRate = 9600,
    [ValidateSet('None', 'Odd', 'Even', 'Mark', 'Space')]
    [string]$Parity = 'None',
    [int]$DataBits = 8,
    [ValidateSet('None', 'One', 'Even', 'Two', 'OnePointFive')]
    [string]$StopBits = 'One',
    [string]$Data,
    [switch]$Wait,
    [switch]$Close
  )

  if ($psCmdlet.shouldProcess($portname , 'Write data to local serial port')) {
    if ($Close) {
      $Data = 'close'
      $Wait = $false
    }
    try {
      # Define a new object to read serial ports.
      $port = New-Object System.IO.Ports.SerialPort $portname, $BaudRate, `
                          $Parity, $DataBits, $StopBits
      $port.Open()
      # Write to the serial port.
      $port.WriteLine($Data)
      # If wait_for_resond is specified.
      if ($Wait) {
        $result = $port.ReadLine()
        $result.Replace('#^#',"`n")
      }
      $port.Close()
    }
    catch {
      Write-Warning "ps_log: Cannot write to $portname! $(Convert_ErrorToString $_)"
    }
  }
}


function Write-Log {
  <#
  .SYNOPSIS
     Writes a string to a log file.
  .DESCRIPTION
     Writes a string to a log file.
  .PARAMETER LogFile
     File to create/append
  .PARAMETER Message
     String to output.
  .EXAMPLE
     Write-Log -Message "Example log string" -LogFile C:\windows\temp\foo.log
  #>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [AllowEmptyString()]
    $Message,
    [string]$LogFile
  )

  # If the LogFile was not specified, fall back to global preference or fail
  if ($LogFile) {
    $log_file = $LogFile
  }
  elseif ($global:PSLogFile) {
    $log_file = $global:PSLogFile
  }
  else {
    Write-Warning ('Unable to write to log file, no log file was specified. ' +
        "Pass -LogFile or set $global:PSLogFile")
    return
  }

  $log_dir = Split-Path $log_file -Parent
  if (Test-Path $log_dir) {
    Add-Content $log_file -value $Message
  }
  else {
    Write-Warning "Unable to write to log file, $log_dir does not exist."
  }
}

# Helper functions use underscores instead of hyphens. Do not export helpers.
Export-ModuleMember -Function *-*
