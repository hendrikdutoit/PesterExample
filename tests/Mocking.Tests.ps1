﻿Describe "Test with Mocked Environment Variables" {
    BeforeAll {
        # Save the current value to restore later
        $originalValue = $env:MY_VARIABLE
        $env:MY_VARIABLE = "MockedValue"
    }

    It "Should use the mocked environment variable" {
        # Your test code here
        $env:MY_VARIABLE | Should -Be "MockedValue"
    }

    AfterAll {
        # Restore the original environment variable
        $env:MY_VARIABLE = $originalValue
    }
}

# https://pester.dev/docs/commands/Mock
Describe "Mock Examples from Pester Docs" {
    BeforeAll {
        function New-TempStructure {
            param (
                [Parameter(Mandatory = $true)]
                [string]$Prefix
            )
            $TempDir = Join-Path -Path $env:TEMP -ChildPath ($Prefix + "_" + [Guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $TempDir | Out-Null
            Set-Content -Path (Join-Path -Path $TempDir -ChildPath "File1.txt") -Value "File1.txt"
            Set-Content -Path (Join-Path -Path $TempDir -ChildPath "File2.txt") -Value "File2.txt"
            return $TempDir
        }
        $TempDir = New-TempStructure -Prefix "PesterExample"
    }
    Context "Get-ChildItem Example" {
        Context "Simple examples" {
            It "Should call original command" {
                $result = Get-ChildItem -Path $TempDir
                $fullPaths = $result | ForEach-Object { Split-Path $_ -Leaf }
                $fullPaths | Should -Be @("File1.txt", "File2.txt")
            }
            It "Should call mock command" {
                Mock Get-ChildItem { return @{FullName = "MockFile.txt" } }
                $result = Get-ChildItem -Path $TempDir
                $result.FullName | Should -Be "MockFile.txt"
            }
        }
        Context "ParameterFilter examples" {
            Context "Single Mock Setup" {
                BeforeAll {
                    Mock Get-ChildItem { return @{FullName = "MockFile.txt" } } -ParameterFilter {
                        $Path.StartsWith($env:TEMP + "\PesterExample")
                    }
                }
                It "Should call original command" {
                    $AlternativeDir = New-TempStructure -Prefix "Pester"
                    $result = Get-ChildItem -Path $AlternativeDir
                    $fullPaths = $result | ForEach-Object { Split-Path $_ -Leaf }
                    $fullPaths | Should -Be @("File1.txt", "File2.txt")
                    Remove-Item -Path $AlternativeDir -Recurse -Force
                }
                It "Should call mock command" {
                    $result = Get-ChildItem -Path $TempDir
                    $result.FullName | Should -Be "MockFile.txt"
                }
            }
            Context "Multi Mock Setup" {
                BeforeEach {
                    $AlternativeDir = New-TempStructure -Prefix "Alternative"
                    Mock Get-ChildItem { return @{FullName = "MockFile.txt" } } -ParameterFilter { $Path.StartsWith($env:TEMP + "\PesterExample") }
                    Mock Get-ChildItem { return @{FullName = "Alternative.txt" } } -ParameterFilter { $Path.StartsWith($env:TEMP + "\Alternative") }
                    $WrongDir = New-TempStructure -Prefix "Wrong"
                }
                It "Should call original command" {
                    $result = Get-ChildItem -Path $WrongDir
                    $fullPaths = $result | ForEach-Object { Split-Path $_ -Leaf }
                    $fullPaths | Should -Be @("File1.txt", "File2.txt")
                }
                It "Should call mock command" {
                    $result = Get-ChildItem -Path $TempDir
                    $result.FullName | Should -Be "MockFile.txt"
                }
                It "Should call alternative mock command" {
                    $result = Get-ChildItem -Path $AlternativeDir
                    $result.FullName | Should -Be "Alternative.txt"
                }
                AfterEach {
                    Remove-Item -Path $AlternativeDir -Recurse -Force
                    Remove-Item -Path $WrongDir -Recurse -Force
                }
            }
        }
    }
    AfterAll {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}

Context "Mock Module Tests" {
    BeforeAll {
        if (Get-Module -Name "MyModule") { Remove-Module -Name "MyModule" }
        if (Get-Module -Name "AnotherModule") { Remove-Module -Name "AnotherModule" }
        Import-Module "$PSScriptRoot\..\src\MyModule.psm1"
        Import-Module "$PSScriptRoot\..\src\AnotherModule.psm1"
    }
    It "Test MyModule\Get-Hello" {
        Mock MyModule\Get-Hello { return "Mocked Get-Hello from MyModule" }
        MyModule\Get-Hello | Should -Be "Mocked Get-Hello from MyModule"
    }
    It "Test AnotherModule\Get-Hello" {
        Mock AnotherModule\Get-Hello { return "Mocked Get-Hello from AnotherModule" }
        AnotherModule\Get-Hello | Should -Be "Mocked Get-Hello from AnotherModule"
    }
    It "Test Invoke-CalledFunction" {
        Mock -ModuleName MyModule -CommandName Invoke-CalledFunction { Write-Output "Mocked call to Invoke-CalledFunction" }

        $Output = MyModule\Get-Hello

        $Output[0] | Should -Be "Hello from MyModule.psm1\Get-Hello"
        $Output[1] | Should -Be "Mocked call to Invoke-CalledFunction"
        Assert-MockCalled -Scope It -ModuleName MyModule -CommandName Invoke-CalledFunction -Times 1 -Exactly
    }
}

Context "Mock Parametrised" {
    It "Call original Invoke-WebRequest" {
        $Result = Invoke-WebRequest "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/MyTest.txt"
        $Result = [System.Text.Encoding]::UTF8.GetString($Result.Content).Trim()
        $Result | Should -Be "MyTest"
    }
    It "Call mock Invoke-WebRequest" {
        Mock Invoke-WebRequest { "MockTest" } -ParameterFilter { $Uri -eq "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/MyTest.txt" }
        $Result = Invoke-WebRequest "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/MyTest.txt"
        $Result | Should -Be "MockTest"
    }
    It "Call specific Invoke-WebRequest" {
        Mock Invoke-WebRequest { return "AnotherMockTest" } -ParameterFilter { $Uri -eq "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/AnotherTest.txt" }
        Mock Invoke-WebRequest { return "MyMockTest" } -ParameterFilter { $Uri -eq "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/MyTest.txt" }
        $MyResult = Invoke-WebRequest "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/MyTest.txt"
        $AnotherResult = Invoke-WebRequest "https://github.com/hendrikdutoit/PesterExample/releases/download/1.2.0/AnotherTest.txt"
        $MyResult | Should -Be 'MyMockTest'
        $AnotherResult | Should -Be 'AnotherMockTest'
    }
    Context "Handle console input" {
        Context "Local Call"{
            It "Single Read-Host" {
                Mock Read-Host { "Mocked input from the console" } -ParameterFilter { $Prompt -eq "Console input" }
                $Result = Read-Host -Prompt "Console input"
                $Result | Should -Be "Mocked input from the console"
            }
            It "For loop Read-Host" {
                Mock Read-Host {
                    return "Expected1"
                } -ParameterFilter { $Prompt -eq "Prompt1 for value" }
                Mock Read-Host {
                    return "Expected2"
                } -ParameterFilter { $Prompt -eq "Prompt2 for value" }

                $variableSet = @(
                    @("Prompt1", "Expected1"),
                    @("Prompt2", "Expected2")
                )
                foreach ($variable in $variableSet) {
                    $prompt = $variable[0] + " for value"
                    $MyResult = Read-Host -Prompt $prompt
                    $MyResult | Should -Be $variable[1]
                }
            }
        }
        Context "Function Call" {
            BeforeAll {
                if (Get-Module -Name "MyModule") { Remove-Module -Name "MyModule" }
                Import-Module "$PSScriptRoot\..\src\MyModule.psm1"
                Mock -ModuleName MyModule Read-Host {
                    return "Mocked input from the console"
                } -ParameterFilter { $Prompt -eq "Console input" }
            }
            It "Single Read-Host" {
                $Result = Get-ConsoleInput -textPrompt "Console input"
                $Result | Should -Be "Mocked input from the console"
            }
        }
    }
}

