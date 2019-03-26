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

#
# Invoke-Build Script for ps_log module
#

# Param Block
param(
  [int]$BuildNumber = 0, # Build number for module versioning
  [ValidateRange(0,100)]
  [int]$CodeCoveragePassingPercent = 70, # Percent of code that must be covered by tests.
  [bool]$IsPesterStrict =  $false, # If $true, Pester runs in strict mode.
  [bool]$PSAnalyzerFailOnWarning = $false # If $true, warnings from PSScriptAnalyzer won't fail the build.
)

# Source additional build config
. .\ps_log.conf.ps1

# Synopsis: Run complete build
task . Clean, Analyze, Test

# Synopsis: Clean build area
task Clean {
  Remove-Item 'artifacts' -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path 'artifacts'
}

# Synopsis: Run code health checks
task Analyze RunPSAnalyzer

# Synopsis: Run PSScriptAnalyzer to check code health
task RunPSAnalyzer {

  $analyzer_results = Invoke-ScriptAnalyzer `
      -Path . `
      -Severity @('Error', 'Warning') `
      -Recurse

  if ($analyzer_results -eq $null ) {
    Write-Output 'Congratulations! PSScriptAnalyzer found no issues with the code. Huzzah!'
  }
  else {
    $analyzer_results | ConvertTo-Json | Set-Content ".\artifacts\ScriptAnalysisResults.json"

    Write-Output $analyzer_results

    $script_errors = ($analyzer_results.Severity -eq "Error").Count
    $script_warnings = ($analyzer_results.Severity -eq "Warning").Count

    if ($script_errors -gt 0) {
      throw "Errors were found running PSScriptAnalyzer."
    }

    if ($script_warnings -gt 0) {
      Write-Warning "$script_warnings script warnings were found"
      if($PSAnalyzerFailOnWarning) {
        throw "Failing build since PSAnalyzerFailOnWarning is enabled."
      }
    }
  }
}

# Synopsis: Run entire test suite
task Test RunUnitTests, ConfirmTestsPassed, ConfirmTestCoverage

# Synopsis: Run Pester Unit Tests
task RunUnitTests {

  # Run pester on all unit test; include code coverage stats and output to NUnit XML
  $pester_results = Invoke-Pester `
      -Script "./tests/unit/*" `
      -OutputFile 'artifacts/pester_nunit_results.xml' `
      -OutputFormat NUnitXml `
      -CodeCoverage ps_log.psm1 `
      -PassThru `
      -Strict:$IsPesterStrict

  $pester_results | ConvertTo-Json -Depth 5 | Set-Content ".\artifacts\PesterTestResults.json"

  # Build pretty test report.  Note that script analysis will be included if that task has run.

  # Default report options
  $options = @{
    BuildNumber = 0
    GitRepo = 'ps_log'
    ShowHitCommands = $false
    Compliance = ($CodeCoveragePassingPercent / 100)
    ScriptAnalyzerFile = '.\artifacts\ScriptAnalysisResults.json'
    PesterFile = '.\artifacts\PesterTestResults.json'
    OutputDir = '.\artifacts'
  }

  # Set options from jenkins env variables if available.
  if ($Env:BUILD_NUMBER) {
    $options.BuildNumber = $Env:BUILD_NUMBER
  }
  if ($Env:BUILD_URL) {
    $options.CiURL = $Env:BUILD_URL
  }
  if ($Env:GIT_URL) {
    $options.GitRepoURL = $Env:GIT_URL
  }
  if ($Env:JOB_NAME) {
    $options.GitRepo = $Env:JOB_NAME
  }

   .\third_party\PSTestReport\Invoke-PSTestReport.ps1 @options
}


# Synopsis: Validate tests were sucessful.
task ConfirmTestsPassed {
    # Fail Build if their are any failing test.
    [xml] $xml = Get-Content 'artifacts\pester_nunit_results.xml'
    $numberFails = $xml."test-results".failures
    Assert-Build ($numberFails -eq 0) ('Failed "{0}" unit tests.' -f $numberFails)
}

# Synopsis: Validate code coverage is acceptable.
task ConfirmTestCoverage {
    # Fail Build if Coverage is under requirement
    $json = Get-Content 'artifacts\PesterTestResults.json' | ConvertFrom-Json
    $overallCoverage = [Math]::Floor(($json.CodeCoverage.NumberOfCommandsExecuted /
                                      $json.CodeCoverage.NumberOfCommandsAnalyzed) * 100)
    ("Code Coverage is $overallCoverage% ($CodeCoveragePassingPercent% required to pass)")
    Assert-Build ($OverallCoverage -gt $CodeCoveragePassingPercent)
}
