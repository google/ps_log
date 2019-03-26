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

Import-Module -Name (Join-Path $PSScriptRoot '../../ps_log') -Force -ErrorAction Stop
#endregion

InModuleScope ps_log {
  # ps_log calls these functions to produce output
  $output_functions = @(
    'Write-Progress',
    'Write-Debug',
    'Write-Information',
    'Write-Verbose',
    'Write-Host',
    'Write-Warning',
    'Write-Error',
    'Write-EventLog',
    'Write-Log',
    'Out-File',
    'Add-Content',
    'Write_ToSerialPort'
  )

  Describe 'Convert_MessageToString' {
    Context 'When called without arguments'   {
      It 'runs without errors' {
        { Convert_MessageToString } | Should Not Throw
      }
      It 'does not return anything'     {
        Convert_MessageToString | Should BeNullOrEmpty
      }
    }
    Context 'When passed ErrorRecords' {
      It 'runs without errors' {
        {
          try { throw 'Really useful error message!' }
          catch { Convert_MessageToString $global:Error[0] }
        } | Should Not Throw
      }
      It 'calls Convert_ErrorToString' {
        Mock Convert_ErrorToString {}
          try { throw 'Really useful error message!' }
          catch { Convert_MessageToString $global:Error[0] }
        Assert-MockCalled -CommandName Convert_ErrorToString -Exactly 1 -Scope It
      }
    }
    Context 'When passed an assortment of object types' {
      # Create an ErrorRecord to play with
      try { throw 'Really useful error message!' }
      catch { $err = $global:Error[0] }
      # Collection of objects to use as input
      $messages = (12345, 'Oh, the huge manatee!', $err)

      It 'runs without errors' {
        {
          Convert_MessageToString $messages
        } | Should Not Throw
      }

      $result = Convert_MessageToString $messages
      It 'returns only strings' {
        $result | Should BeOfType string
      }
      It 'expands collections, returning one string per object' {
        $result.Count | Should BeExactly 3
      }
    }
  }

  Describe 'Out-Log*' {
    # Set ps_log global parameters to DEBUG verbosity
    $global:PSLogEventLevel = 'DEBUG'
    $global:PSLogFileLevel = 'DEBUG'
    $global:PSLogSerialLevel = 'DEBUG'
    $global:PSLogVerbosity = 'DEBUG'
    $global:PSLogFile = 'c:\bogus\path\to\log.log'
    $global:PSLogSource = 'PESTER'
    $global:PSLogSerialPort = 'COM1'

    # Mock output functions
    $output_functions | ForEach-Object { Mock $_ {} }
    # Allow testing for the log file to succeed
    Mock Test-Path {return $true}
    # Don't permit Out-LogFatal to exit
    Mock Invoke_Exit {}

    Context 'When called without arguments' {
      It 'runs without errors' {
        { Out-LogDebug } | Should Not Throw
        { Out-LogInfo } | Should Not Throw
        { Out-LogWarn } | Should Not Throw
        { Out-LogError } | Should Not Throw
        { Out-LogFatal } | Should Not Throw
      }
      It 'does not return anything' {
        Out-LogDebug | Should BeNullOrEmpty
        Out-LogInfo | Should BeNullOrEmpty
        Out-LogWarn | Should BeNullOrEmpty
        Out-LogError | Should BeNullOrEmpty
        Out-LogFatal | Should BeNullOrEmpty
      }
      $output_functions | ForEach-Object {
          It "does not produce output via $_" {
            Out-LogDebug
            Out-LogInfo
            Out-LogWarn
            Out-LogError
            Out-LogFatal
            Assert-MockCalled -CommandName $_ -Exactly 0 -Scope It
          }
      }
    }

    Context 'When called with a simple string parameter' {
      $message = 'This is a test message'
      It 'runs without errors' {
        { Out-LogDebug $message } | Should Not Throw
        { Out-LogInfo $message } | Should Not Throw
        { Out-LogWarn $message } | Should Not Throw
        { Out-LogError $message } | Should Not Throw
        { Out-LogFatal $message } | Should Not Throw
      }
      It 'does not return anything' {
        Out-LogDebug $message | Should BeNullOrEmpty
        Out-LogInfo $message | Should BeNullOrEmpty
        Out-LogWarn $message | Should BeNullOrEmpty
        Out-LogError $message | Should BeNullOrEmpty
        Out-LogFatal $message | Should BeNullOrEmpty
      }
      It 'produces a single message via each output channel' {
        Out-LogDebug $message
        Out-LogInfo $message
        Out-LogWarn $message
        Out-LogError $message
        Out-LogFatal $message

        # Pipeline streams
        Assert-MockCalled -CommandName Write-Debug -Exactly 1 -Scope It
        Assert-MockCalled -CommandName Write-Verbose -Exactly 1 -Scope It
        Assert-MockCalled -CommandName Write-Warning -Exactly 1 -Scope It
        # Out-LogError and Out-LogFatal use the Error stream
        Assert-MockCalled -CommandName Write-Error -Exactly 2 -Scope It

        # Other channels, once per Out-Log*
        Assert-MockCalled -CommandName Write-EventLog -Exactly 5 -Scope It
        Assert-MockCalled -CommandName Write-Log -Exactly 5 -Scope It
        Assert-MockCalled -CommandName Write_ToSerialPort -Exactly 5 -Scope It
      }
    }

    Context 'When called in a pipeline' {
      $message = 'This is a test message'
      It 'runs without errors' {
        { $message | Out-LogDebug } | Should Not Throw
        { $message | Out-LogInfo } | Should Not Throw
        { $message | Out-LogWarn } | Should Not Throw
        { $message | Out-LogError } | Should Not Throw
        { $message | Out-LogFatal } | Should Not Throw
      }
      It 'does not return anything' {
        $message | Out-LogDebug | Should BeNullOrEmpty
        $message | Out-LogInfo | Should BeNullOrEmpty
        $message | Out-LogWarn | Should BeNullOrEmpty
        $message | Out-LogError | Should BeNullOrEmpty
        $message | Out-LogFatal | Should BeNullOrEmpty
      }
      It 'produces a single message via each output channel' {
        $message | Out-LogDebug
        $message | Out-LogInfo
        $message | Out-LogWarn
        $message | Out-LogError
        $message | Out-LogFatal

        # Pipeline streams
        Assert-MockCalled -CommandName Write-Debug -Exactly 1 -Scope It
        Assert-MockCalled -CommandName Write-Verbose -Exactly 1 -Scope It
        Assert-MockCalled -CommandName Write-Warning -Exactly 1 -Scope It
        # Out-LogError and Out-LogFatal use the Error stream
        Assert-MockCalled -CommandName Write-Error -Exactly 2 -Scope It

        # Other channels, once per Out-Log*
        Assert-MockCalled -CommandName Write-EventLog -Exactly 5 -Scope It
        Assert-MockCalled -CommandName Write-Log -Exactly 5 -Scope It
        Assert-MockCalled -CommandName Write_ToSerialPort -Exactly 5 -Scope It
      }
    }
  }

  Describe 'Out-LogFatal' {
    # Set ps_log global parameters to DEBUG verbosity
    $global:PSLogEventLevel = 'DEBUG'
    $global:PSLogFileLevel = 'DEBUG'
    $global:PSLogSerialLevel = 'DEBUG'
    $global:PSLogVerbosity = 'DEBUG'
    $global:PSLogFile = 'c:\bogus\path\to\log.log'
    $global:PSLogSource = 'PESTER'
    $global:PSLogSerialPort = 'COM1'

    # Mock output functions
    $output_functions | ForEach-Object { Mock $_ {} }
    # Allow testing for the log file to succeed
    Mock Test-Path {return $true}
    # Don't permit Out-LogFatal to exit
    Mock Invoke_Exit {}

    # Create an ErrorRecord to play with
    try { throw 'Really useful error message!' }
    catch { $err = $global:Error[0] }
    # Collection of objects to use as input
    $messages = (12345, 'Oh, the huge manatee!', $err)

    Context 'When called with a collection of messages' {
      It 'logs all messages before exiting' {
        Out-LogFatal -Message $messages
        Assert-MockCalled -CommandName Write-Error -Exactly 3 -Scope It
      }
      It 'exits with the correct exit code' {
        Out-LogFatal -Message $messages -ExitCode 42
        Assert-MockCalled -CommandName Invoke_Exit -ParameterFilter {$ExitCode -eq 42} -Exactly 1 -Scope It
      }
    }

    Context 'When called in a pipeline' {
      It 'logs all messages before exiting' {
        $messages | Out-LogFatal
        Assert-MockCalled -CommandName Write-Error -Exactly 3 -Scope It
      }
      It 'exits with the correct exit code' {
        $messages | Out-LogFatal -ExitCode 42
        Assert-MockCalled -CommandName Invoke_Exit -ParameterFilter {$ExitCode -eq 42} -Exactly 1 -Scope It
      }
    }
  }

  Describe 'Write-Log' {
    Context 'TODO'   {
      It 'TODO' {}
    }
  }

  Describe 'Out_Log' {
    Context 'TODO'   {
      It 'TODO' {}
    }
  }

  Describe 'Convert_ErrorToString' {
    Context 'TODO'   {
      It 'TODO' {}
    }
  }

  Describe 'Write_Event' {
    Context 'TODO'   {
      It 'TODO' {}
    }
    Context 'When the current user cannot find the desired Event source' {
      It 'runs without errors' {
        Mock Write-EventLog {
          throw [System.Security.SecurityException]'The source was not found, but some or all event logs could not be searched.  Inaccessible logs: Security.'
        }
        Mock New-EventLog {}
        {Write_Event `
          -Message 'test message' `
          -Source ([guid]::NewGuid().Guid) `
          -EventID 1 `
          -EntryType 'Information' `
          -EventLogName ([guid]::NewGuid().Guid)} | Should Not Throw
      }
      It 'creates the desired Event source if it has permissions to do so' {
        Write_Event `
          -Message 'test message' `
          -Source ([guid]::NewGuid().Guid) `
          -EventID 1 `
          -EntryType 'Information' `
          -EventLogName ([guid]::NewGuid().Guid)
        Assert-MockCalled -CommandName New-EventLog -Exactly 1 -Scope It
      }
      # TODO: Implement this
      It 'falls back to a default Event source if creating the desired Event source fails' {}
      # TODO: Implement this
      It 'remembers if the source does not exist' {}
    }
  }

  Describe 'Get_SerialPorts' {
    Context 'TODO'   {
      It 'TODO' {}
    }
  }

  Describe 'Write_ToSerialPort' {
    Context 'When the attempt to write to the serial port fails'   {
      Mock New-Object {throw 'This exception should be displayed as a warning!'}
      It 'runs without errors' {
        {Write_ToSerialPort -PortName 'COM9' -Data 'This is a test'} | Should Not Throw
      }
    }
  }
}
