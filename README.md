# ps\_log PowerShell Module

This collection of log management functions enhances support for logging
  in PowerShell scripts. There are a set of preference variables that can be
  set in your script to modify the behavior of these functions.

This is not an official Google product

### Configuration Flags

Controlling the behavior of ps\_log functions is done by setting the values of the following variables in your PowerShell script:

*   Output Levels: Each of these output channels can be set to a level that
    determines when a message will be logged through that channel. Log levels
    are any of these values: DEBUG, INFO, WARNING, ERROR, FATAL. When you set
    the level of an output channel, you are indicating that any message of that
    severity or greater should be logged on that channel.

    *   $global:PSLogEventLevel
        *   The minimum severity for a message to be logged to the Windows Event
            Log. Defaults to `WARNING`.
    *   $global:PSLogFileLevel
        *   The minimum severity for a message to be logged to a log file.
            Defaults to `WARNING`.
    *   $global:PSLogSerialLevel
        *   The minimum severity for a message to be logged to a serial port.
            Defaults to `$null`.
    *   $global:PSLogVerbosity
        *   The minimum severity for a message to be logged to the conosle.
            Defaults to `INFO`.

*   Output Settings:

    *   $global:PSLogFile
        *   If set to a file path, Out-Log\* functions will append lines here.
    *   $global:PSLogSource
        *   Windows Events will have a Source of this variable's value, if set.
    *   $global:PSLogSerialPort
        *   If set to a port name that exists (e.g., 'COM1'), Out-Log\*
            functions will append lines here.

### Output Functions

The primary functions of the ps\_log module are `Out-LogDebug`, `Out-LogInfo`, `Out-LogWarn`, `Out-LogError`, and `Out-LogFatal`.

```none
PS C:\Windows\system32> Get-Help ps_log | Format-Table Name,Synopsis -AutoSize

Name         Synopsis
----         --------
Write-Log    Writes a string to a log file.
Out-LogWarn  Writes a WARNING message to the event log, and optionally a log file.
Out-LogInfo  Writes a INFO message to the event log, and optionally a log file.
Out-LogFatal Writes a FATAL message to the event log, optionally a log file, and exits.
Out-LogError Writes a ERROR message to the event log, and optionally a log file.
Out-LogDebug Writes a DEBUG message to the event log, and optionally a log file.
```

### Input Parsing

ps\_log output functions will accept strings or lists of strings. `Out-LogError`
and `Out-LogFatal` will also except **ErrorRecord**s. Each string passed to an
output function is parsed for EOL character combinations, and each string and
line within a string is treated as a separate line.

#### ErrorRecord Parsing

Error records will be parsed and output as a single string.

test.ps1

```none
Out-LogError 'This is ERROR'
try {
  Get-Item c:\bogus -ErrorAction Stop
}
catch {
  Out-LogError $_
}
```

test.log

```none
2016-05-19 15:34:45Z    TESTHOST  ps_log:   [E] This is ERROR
2016-05-19 15:34:45Z    TESTHOST  ps_log:   [E] Cannot find path 'C:\bogus' because it does not exist. {-2146233087, C:\test.ps1:3}
```

### Output Formatting

#### PowerShell Console

Output to the console is prefixed with a UTC timestamp, and output through the PowerShell output stream appropriate for the message type.

  * **DEBUG** messages are written to the **Debug** output stream.
  * **INFO** messages are written to the **Verbose** output stream.
  * **WARNING** messages are written to the **Warning** output stream.
  * **ERROR** messages are written to the **Error** output stream.
  * **FATAL** messages are written to the **Error** output stream, and the script is halted.

Examples:

```none
PS C:\Windows\system32> $global:PSLogVerbosity = 'DEBUG'
PS C:\Windows\system32> $foo = @"
>> This is a test message
>> containing multiple lines,
>> to demonstrate how multi-
>> line messages are handled.
>> "@
>>
PS C:\Windows\system32> Out-LogDebug $foo
DEBUG: 2014-10-14 13:36:26Z This is a test message
DEBUG: 2014-10-14 13:36:26Z containing multiple lines,
DEBUG: 2014-10-14 13:36:26Z to demonstrate how multi-
DEBUG: 2014-10-14 13:36:26Z line messages are handled.
PS C:\Windows\system32> Out-LogInfo $foo
VERBOSE: 2014-10-14 13:36:42Z This is a test message
VERBOSE: 2014-10-14 13:36:42Z containing multiple lines,
VERBOSE: 2014-10-14 13:36:42Z to demonstrate how multi-
VERBOSE: 2014-10-14 13:36:42Z line messages are handled.
PS C:\Windows\system32> Out-LogWarn $foo
WARNING: 2014-10-14 13:36:52Z This is a test message
WARNING: 2014-10-14 13:36:52Z containing multiple lines,
WARNING: 2014-10-14 13:36:52Z to demonstrate how multi-
WARNING: 2014-10-14 13:36:52Z line messages are handled.
PS C:\Windows\system32> Out-LogError $foo
Out_Log : 2014-10-14 13:37:00Z This is a test message
containing multiple lines,
to demonstrate how multi-
line messages are handled.
At C:\managed\lib\ps_log\ps_log.psm1:343 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel ERROR -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log

PS C:\Windows\system32> Out-LogFatal $foo
Out_Log : 2014-10-14 13:38:05Z This is a test message
containing multiple lines,
to demonstrate how multi-
line messages are handled.
At C:\managed\lib\ps_log\ps_log.psm1:377 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel FATAL -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log
```

#### Windows Event Log

Output to the Windows Event log is prefixed with a token indicating the message type (**[D]**, **[I]**, **[W]**, **[E]**, **[F]**). Each call of a ps\_log output function results in a single Windows Event to the Application log, regardless of the number of lines. The event's source/provider is set to ps\_log by default, unless $global:PSLogSource is set, or the -Source parameter is provided. The event type is set based on the message level.

  * **DEBUG** messages are written as **Information** events.
  * **INFO** messages are written as **Information** events.
  * **WARNING** messages are written as **Warning** events.
  * **ERROR** messages are written as **Error** events.
  * **FATAL** messages are written as **Error** events, and the script is halted.

Examples:

```none
PS C:\Windows\system32> $global:PSLogEventLevel = 'DEBUG'
PS C:\Windows\system32> $global:PSLogSource = 'example_script'
PS C:\Windows\system32> $bar = 'A simple message'
PS C:\Windows\system32> Out-LogDebug $bar
PS C:\Windows\system32> Out-LogInfo $bar
PS C:\Windows\system32> Out-LogWarn $bar
WARNING: 2014-10-14 13:55:00Z A simple message
PS C:\Windows\system32> Out-LogError $bar
Out_Log : 2014-10-14 13:55:06Z A simple message
At C:\managed\lib\ps_log\ps_log.psm1:343 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel ERROR -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log

PS C:\Windows\system32> Out-LogFatal $bar
Out_Log : 2014-10-14 13:55:12Z A simple message
At C:\managed\lib\ps_log\ps_log.psm1:377 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel FATAL -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log

PS C:\Windows\system32> Get-WinEvent `
>> -FilterHashtable @{LogName='Application';ProviderName='example_script'} `
>> -MaxEvents 5
>>

   ProviderName: example_script

TimeCreated                     Id LevelDisplayName Message
-----------                     -- ---------------- -------
10/14/2014 1:55:12 PM            0 Error            [F] A simple message
10/14/2014 1:55:06 PM            0 Error            [E] A simple message
10/14/2014 1:55:00 PM            0 Warning          [W] A simple message
10/14/2014 1:54:49 PM            0 Information      [I] A simple message
10/14/2014 1:54:42 PM            0 Information      [D] A simple message
```

#### Log Files

Output to log files is tab-delimited, and prefixed by the following fields:

  * Timestamp, in UTC
  * Computer name
  * Message 'Source'. **ps\_log** by default, unless `$global:PSLogSource` is
    set, or the `-Source` parameter was passed.
  * A token indicating the message type (**[D]**, **[I]**, **[W]**, **[E]**, **[F]**)

Examples:

```none
PS C:\Windows\system32> $global:PSLogFile = 'C:\managed\log\ps_log_example.log'
PS C:\Windows\system32> $derp = @('This is an example message',
>> 'presented as a list',
>> "with a newline in one element`nto demonstrate multi-line",
>> 'input parsing and multi-line log file output.')
>>
PS C:\Windows\system32> Out-LogDebug $derp
PS C:\Windows\system32> Out-LogInfo -Message $derp -Source 'a_different_source'
PS C:\Windows\system32> Out-LogWarn -Message $derp -Source 'oh_noes'
WARNING: 2014-10-14 14:54:31Z This is an example message
WARNING: 2014-10-14 14:54:31Z presented as a list
WARNING: 2014-10-14 14:54:31Z with a newline in one element
WARNING: 2014-10-14 14:54:31Z to demonstrate multi-line
WARNING: 2014-10-14 14:54:31Z input parsing and multi-line log file output.
PS C:\Windows\system32> Out-LogError -Message "I'm sorry, I can't do that, Dave" -Source 'hal 9000'
Out_Log : 2014-10-14 14:57:56Z I'm sorry, I can't do that, Dave
At C:\managed\lib\ps_log\ps_log.psm1:343 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel ERROR -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log

PS C:\Windows\system32> Out-LogFatal -Message "404'd!" -Source 'strbd'
Out_Log : 2014-10-14 14:56:59Z 404'd!
At C:\managed\lib\ps_log\ps_log.psm1:377 char:3
+   Out_Log -Message $Message -Source $Source -LogLevel FATAL -LogFile $LogFile
+   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
    + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException,Out_Log

PS C:\Windows\system32> Get-Content $global:PSLogFile
2014-10-14 14:54:06Z    CBF-MSTEST-1    a_different_source:     [I]     This is an example message
2014-10-14 14:54:06Z    CBF-MSTEST-1    a_different_source:     [I]     presented as a list
2014-10-14 14:54:06Z    CBF-MSTEST-1    a_different_source:     [I]     with a newline in one element
2014-10-14 14:54:06Z    CBF-MSTEST-1    a_different_source:     [I]     to demonstrate multi-line
2014-10-14 14:54:06Z    CBF-MSTEST-1    a_different_source:     [I]     input parsing and multi-line log file output.
2014-10-14 14:54:31Z    CBF-MSTEST-1    oh_noes:        [W]     This is an example message
2014-10-14 14:54:31Z    CBF-MSTEST-1    oh_noes:        [W]     presented as a list
2014-10-14 14:54:31Z    CBF-MSTEST-1    oh_noes:        [W]     with a newline in one element
2014-10-14 14:54:31Z    CBF-MSTEST-1    oh_noes:        [W]     to demonstrate multi-line
2014-10-14 14:54:31Z    CBF-MSTEST-1    oh_noes:        [W]     input parsing and multi-line log file output.
2014-10-14 14:57:56Z    CBF-MSTEST-1    hal 9000:       [E]     I'm sorry, I can't do that, Dave
2014-10-14 14:56:59Z    CBF-MSTEST-1    strbd:  [F]     404'd!
```

#### Serial Ports

Output to serial ports is space-delimited, and prefixed by the following fields:

*   Timestamp, in UTC
*   Message 'Source'. **ps\_log** by default, unless `$global:PSLogSource` is
    set, or the `-Source` parameter was passed.
*   A token indicating the message type (**[D]**, **[I]**, **[W]**, **[E]**,
    **[F]**)

Example:

PowerShell

```none
PS C:\Windows\system32> $global:PSLogSource = 'just_this_script'
PS C:\Windows\system32> $global:PSLogSerialPort = 'COM1'
PS C:\Windows\system32> $global:PSLogSerialLevel = 'INFO'
PS C:\Windows\system32> $global:PSLogVerbosity = 'ERROR'
PS C:\Windows\system32> Out-LogDebug 'This is DEBUG'
PS C:\Windows\system32> Out-LogInfo 'This is INFO'
PS C:\Windows\system32> Out-LogWarn 'This is WARN'
PS C:\Windows\system32> Out-LogError 'This is ERROR'
Out_Log : 2016-05-17 22:28:07Z This is ERROR
at <ScriptBlock>, <No file>: line 1
Out-LogError 'This is ERROR'
At C:\Users\benmiller\strongcobra\development\Project\Scripts\PS-Modules\ps_log\ps_log.psm1:416 char:5
+     Out_Log -Message $Message -Source $Source -EventID $EventId -LogL ...
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (:) [Write-Error], Exception
    + FullyQualifiedErrorId : Out-LogError,Out_Log
```

COM1

```none
2016-05-17 22:24:09Z just_this_script: [I] This is INFO
2016-05-17 22:24:10Z just_this_script: [W] This is WARN
2016-05-17 22:24:10Z just_this_script: [E] This is ERROR
```