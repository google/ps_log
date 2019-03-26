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

# SIG # Begin signature block
# MIIcmAYJKoZIhvcNAQcCoIIciTCCHIUCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAOqglk9FhWqvtw
# H4e1KWr0RCoW5YWwyclae8k8tDuPXaCCF6IwggUrMIIEE6ADAgECAhAHcq/st9rz
# 2MLlVowM0FKIMA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNV
# BAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcN
# MTcwNjE1MDAwMDAwWhcNMjAwOTEyMTIwMDAwWjBoMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UEBxMNTW91bnRhaW4gVmlldzEVMBMGA1UE
# ChMMR29vZ2xlLCBJbmMuMRUwEwYDVQQDEwxHb29nbGUsIEluYy4wggEiMA0GCSqG
# SIb3DQEBAQUAA4IBDwAwggEKAoIBAQC03JUpDoeiIPOW4jxh6YlHvSQiCN8t7M+S
# zGehmDwrrGHAU5YaWhrMxQgp14to5N9I31zr4r6mQgHsHvRY3kZv4DmpjsR1X82I
# 4nbv4KCn2KVEGgJu6Hd6570bUyX+LwVtFdaM7OQok3L2SelNwo2rdUuC3w0dP/gf
# EKv+OO0sLKsSZrBQKOYF+UXHhZVt1AcYpNk503akMmTYgURvkgPTphjQaZ6/guWh
# SPU1MDGrveomNEOywo/mGZVTDhrkXpupR6iLVeiGelwd4O6qvnAqYjrUF/o1D7fP
# HHTJFApDGGDvJ/QEj6SSminRx3kINmF7e1dUEMhGgFU/V3xDodjbAgMBAAGjggHF
# MIIBwTAfBgNVHSMEGDAWgBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAdBgNVHQ4EFgQU
# r+zOWYafiSLUbWbhylYOnU0VUGQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMHcGA1UdHwRwMG4wNaAzoDGGL2h0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3JsMDWgM6Axhi9odHRwOi8vY3JsNC5k
# aWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDBMBgNVHSAERTBDMDcG
# CWCGSAGG/WwDATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQA24XAmrV1Z
# OgLhsvu5SreNrsItc4VnUpRU9Onh5IuqrJd5DJwoCdReHtUoLrLsAklSKgBRDGue
# WTgEs/0aRTHs60g7DRlUR3RaERZKTS7BWZNpDPtjhMuGhgnw8V6adRHdWTfRNGjf
# JLe73bp0nC/H888tc6CgCD6ivzERoX6XKKsRaPK1HCrZiUgvkAsiN9MkYqs6VWVG
# HbQI40m7rvLpvZEYMe2QDadh7q9yPxqIbsumVPfcrQBvcmLsXPT8aDQfDkTVwMU7
# dUKKJTiuEgylsLPPLHntrRLT/K/S8cfipgza6bb8gZcJjb2ckPPegfK+Ql6GAEh+
# DTvWAFAP0H76MIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1b5VQCDANBgkqhkiG
# 9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1
# cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgxMDIyMTIwMDAwWjBy
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQg
# SUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC
# AQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLXcep2nQUut4/6kkPA
# pfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSRI5aQd4L5oYQjZhJU
# M1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXiTWAYvqrEsq5wMWYz
# cT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5Ng2Q7+S1TqSp6moK
# q4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8vYWxYoNzQYIH5DiL
# anMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYDVR0TAQH/BAgwBgEB
# /wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMweQYIKwYB
# BQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20w
# QwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9j
# cmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4
# oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJv
# b3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEW
# HGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZIAYb9bAMwHQYDVR0O
# BBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1R
# i6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPzItEVyCx8JSl2qB1d
# HC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRupY5a4l4kgU4QpO4/
# cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKNJK4kxscnKqEpKBo6
# cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmifz0DLQESlE/DmZAwl
# CEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN3fYBIM6ZMWM9CBoY
# s4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKyZqHnGKSaZFHvMIIG
# ajCCBVKgAwIBAgIQAwGaAjr/WLFr1tXq5hfwZjANBgkqhkiG9w0BAQUFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVkIElEIENBLTEw
# HhcNMTQxMDIyMDAwMDAwWhcNMjQxMDIyMDAwMDAwWjBHMQswCQYDVQQGEwJVUzER
# MA8GA1UEChMIRGlnaUNlcnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRpbWVzdGFtcCBS
# ZXNwb25kZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCjZF38fLPg
# gjXg4PbGKuZJdTvMbuBTqZ8fZFnmfGt/a4ydVfiS457VWmNbAklQ2YPOb2bu3cuF
# 6V+l+dSHdIhEOxnJ5fWRn8YUOawk6qhLLJGJzF4o9GS2ULf1ErNzlgpno75hn67z
# /RJ4dQ6mWxT9RSOOhkRVfRiGBYxVh3lIRvfKDo2n3k5f4qi2LVkCYYhhchhoubh8
# 7ubnNC8xd4EwH7s2AY3vJ+P3mvBMMWSN4+v6GYeofs/sjAw2W3rBerh4x8kGLkYQ
# yI3oBGDbvHN0+k7Y/qpA8bLOcEaD6dpAoVk62RUJV5lWMJPzyWHM0AjMa+xiQpGs
# AsDvpPCJEY93AgMBAAGjggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/
# BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCCAb8GA1UdIASCAbYwggGyMIIB
# oQYJYIZIAYb9bAcBMIIBkjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNl
# cnQuY29tL0NQUzCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAg
# AG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBz
# AHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABo
# AGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABo
# AGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBu
# AHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAg
# AGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQBy
# AGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUw
# HwYDVR0jBBgwFoAUFQASKxOYspkH7R7for5XDStnAs0wHQYDVR0OBBYEFGFaTSS2
# STKdSip5GoNL9B6Jwcp9MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMDigNqA0hjJodHRw
# Oi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDB3
# BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0
# LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEQ0EtMS5jcnQwDQYJKoZIhvcNAQEFBQADggEBAJ0lfhsz
# TbImgVybhs4jIA+Ah+WI//+x1GosMe06FxlxF82pG7xaFjkAneNshORaQPveBgGM
# N/qbsZ0kfv4gpFetW7easGAm6mlXIV00Lx9xsIOUGQVrNZAQoHuXx/Y/5+IRQaa9
# YtnwJz04HShvOlIJ8OxwYtNiS7Dgc6aSwNOOMdgv420XEwbu5AO2FKvzj0OncZ0h
# 3RTKFV2SQdr5D4HRmXQNJsQOfxu19aDxxncGKBXp2JPlVRbwuwqrHNtcSCdmyKOL
# ChzlldquxC5ZoGHd2vNtomHpigtt7BIYvfdVVEADkitrwlHCCkivsNRu4PQUCjob
# 4489yq9qjXvc2EQwggbNMIIFtaADAgECAhAG/fkDlgOt6gAK6z8nu7obMA0GCSqG
# SIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFz
# c3VyZWQgSUQgUm9vdCBDQTAeFw0wNjExMTAwMDAwMDBaFw0yMTExMTAwMDAwMDBa
# MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsT
# EHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQg
# Q0EtMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAOiCLZn5ysJClaWA
# c0Bw0p5WVFypxNJBBo/JM/xNRZFcgZ/tLJz4FlnfnrUkFcKYubR3SdyJxArar8te
# a+2tsHEx6886QAxGTZPsi3o2CAOrDDT+GEmC/sfHMUiAfB6iD5IOUMnGh+s2P9gw
# w/+m9/uizW9zI/6sVgWQ8DIhFonGcIj5BZd9o8dD3QLoOz3tsUGj7T++25VIxO4e
# s/K8DCuZ0MZdEkKB4YNugnM/JksUkK5ZZgrEjb7SzgaurYRvSISbT0C58Uzyr5j7
# 9s5AXVz2qPEvr+yJIvJrGGWxwXOt1/HYzx4KdFxCuGh+t9V3CidWfA9ipD8yFGCV
# /QcEogkCAwEAAaOCA3owggN2MA4GA1UdDwEB/wQEAwIBhjA7BgNVHSUENDAyBggr
# BgEFBQcDAQYIKwYBBQUHAwIGCCsGAQUFBwMDBggrBgEFBQcDBAYIKwYBBQUHAwgw
# ggHSBgNVHSAEggHJMIIBxTCCAbQGCmCGSAGG/WwAAQQwggGkMDoGCCsGAQUFBwIB
# Fi5odHRwOi8vd3d3LmRpZ2ljZXJ0LmNvbS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRt
# MIIBZAYIKwYBBQUHAgIwggFWHoIBUgBBAG4AeQAgAHUAcwBlACAAbwBmACAAdABo
# AGkAcwAgAEMAZQByAHQAaQBmAGkAYwBhAHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0
# AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBjAGUAIABvAGYAIAB0AGgAZQAgAEQAaQBn
# AGkAQwBlAHIAdAAgAEMAUAAvAEMAUABTACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBs
# AHkAaQBuAGcAIABQAGEAcgB0AHkAIABBAGcAcgBlAGUAbQBlAG4AdAAgAHcAaABp
# AGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBhAGIAaQBsAGkAdAB5ACAAYQBuAGQAIABh
# AHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBhAHQAZQBkACAAaABlAHIAZQBpAG4AIABi
# AHkAIAByAGUAZgBlAHIAZQBuAGMAZQAuMAsGCWCGSAGG/WwDFTASBgNVHRMBAf8E
# CDAGAQH/AgEAMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4
# MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVk
# SURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMB0GA1UdDgQWBBQVABIrE5iymQftHt+i
# vlcNK2cCzTAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG
# 9w0BAQUFAAOCAQEARlA+ybcoJKc4HbZbKa9Sz1LpMUerVlx71Q0LQbPv7HUfdDjy
# slxhopyVw1Dkgrkj0bo6hnKtOHisdV0XFzRyR4WUVtHruzaEd8wkpfMEGVWp5+Pn
# q2LN+4stkMLA0rWUvV5PsQXSDj0aqRRbpoYxYqioM+SbOafE9c4deHaUJXPkKqvP
# nHZL7V/CSxbkS3BMAIke/MV5vEwSV/5f4R68Al2o/vsHOE8Nxl2RuQ9nRc3Wg+3n
# kg2NsWmMT/tZ4CMP0qquAHzunEIOz5HXJ7cW7g/DvXwKoO4sCFWFIrjrGBpN/Coh
# rUkxg0eVd3HcsRtLSxwQnHcUwZ1PL1qVCCkQJjGCBEwwggRIAgEBMIGGMHIxCzAJ
# BgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5k
# aWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBD
# b2RlIFNpZ25pbmcgQ0ECEAdyr+y32vPYwuVWjAzQUogwDQYJYIZIAWUDBAIBBQCg
# gYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYB
# BAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0B
# CQQxIgQgtjj7B4mcmruaURhSAbyKNAAPuqYDvUTTA2cn2Vbiau4wDQYJKoZIhvcN
# AQEBBQAEggEAFLuS+XYahp7Q1eUvYxeK4rdlGv8WbsI/Rf58lYNoPh46E/a5f6rK
# nF5S1jmofW5uSqlTeKA0skMwYbRwtQevUEemVbhp1gnHCHEAv6uHFbL+UmOHWZT5
# jJWjvu73lQP/bngo8SpnPr1N8GVwJoftr3N+9QhhNrGfebjwBK9GRSViCusHQy9S
# 19SPMjy6zMj2NdPFkt629Bb19+Ynk0KBgaGmiY26VhaX4XuzvDrnaklCn86icULn
# 46KY2Zu9fqQcoti3jpOKURtVc6YVFiwM4a9PqMUwFZbGqfPO7yRA/eGa7JiKgO0y
# 0MUo/hOIN9Zm7cBUL6RL7vTYnnE+YB0h/KGCAg8wggILBgkqhkiG9w0BCQYxggH8
# MIIB+AIBATB2MGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFz
# c3VyZWQgSUQgQ0EtMQIQAwGaAjr/WLFr1tXq5hfwZjAJBgUrDgMCGgUAoF0wGAYJ
# KoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMTcwNjI5MTcx
# MDQ1WjAjBgkqhkiG9w0BCQQxFgQUB3qa0GGpPBE5qe9gjMr0/VA3rI8wDQYJKoZI
# hvcNAQEBBQAEggEAH7tz5bp4Xlb0LcobuwGkb5awU2C9YQvu5pZ3FzFMRh7UHi/U
# qJhhTn9q7s6onP5i4wIMfG6bdybKZI8oXOqDqqfUkHEltlU6zn9HVNQeGIhBLNjD
# PnvgggWwOcDCVMOnpTvQ7g1qEIT7j/smJvxDc6AJJSD3ASZ5VdN+al0du0vDDoe0
# /XOJDhGrCm8gTXLNJAQr8w/IA4ZN5O561jnF4iSsdqQ9sQe0ae7OFmD4Iijvku2k
# O1GFhET3ULnvqSS8KGeDC6RbG2BKtWP92sSDmW28A8tWpp0XbBeyJ4Rs4F7zYfgz
# G71D76S6vrJnnywxfISvxeBppzhjae/wRU9EuA==
# SIG # End signature block
