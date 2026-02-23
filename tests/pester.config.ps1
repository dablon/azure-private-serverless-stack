# Pester Configuration - Azure Private Serverless Stack
# ============================================

@{
    # Run configuration
    Run = @{
        PassThru = $true
        Quiet = $false
    }
    
    # Test configuration
    TestResult = @{
        Enabled = $true
        OutputPath = "./test-results.xml"
        OutputFormat = "NUnitXml"
        TestSuiteName = "Azure Private Serverless Stack"
    }
    
    # Code coverage configuration
    CodeCoverage = @{
        Enabled = $true
        Path = @(
            "$PSScriptRoot/../scripts/Deploy-AzureServerlessStack.ps1"
        )
        OutputPath = "./code-coverage.xml"
        OutputFormat = "JaCoCo"
        MinimumCoveragePercent = 90
    }
    
    # Output configuration
    Output = @{
        Verbosity = "Detailed"
        Color = $true
    }
    
    # Filter configuration
    Filter = @{
        Tag = @()
        ExcludeTag = @()
    }
}

# ============================================
# How to Run Tests
# ============================================
<#
# Install Pester (if not installed):
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser

# Run all tests:
Invoke-Pester -Path ./tests/ -Output Detailed

# Run with coverage:
Invoke-Pester -Path ./tests/ -CodeCoverage -Output Detailed

# Run specific test file:
Invoke-Pester -Path ./tests/Deploy-AzureServerlessStack.Tests.ps1 -Output Detailed

# Run E2E tests only:
Invoke-Pester -Path ./tests/E2E-Deploy-AzureServerlessStack.Tests.ps1 -Output Detailed

# Run with JUnit output (for CI):
Invoke-Pester -Path ./tests/ -OutputFormat JUnitXml -OutputFile ./test-results.xml

# Run with coverage and minimum threshold:
Invoke-Pester -Path ./tests/ -CodeCoverage -CodeCoverageThreshold 0.9
#>
