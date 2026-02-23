#!/usr/bin/env pwsh
# ============================================
# Test Runner Script - Azure Private Serverless Stack
# ============================================

param(
    [Parameter()]
    [ValidateSet("All", "Unit", "E2E", "Coverage")]
    [string]$TestMode = "All",
    
    [Parameter()]
    [ValidateSet("Normal", "Detailed", "Diagnostic")]
    [string]$Verbosity = "Detailed",
    
    [Parameter()]
    [switch]$CI
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure Private Serverless Stack" -ForegroundColor Cyan
Write-Host "  Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Pester installation
$module = Get-Module -Name Pester -ListAvailable | Select-Object -First 1
if (-not $module) {
    Write-Host "[INFO] Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}

Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

$testPath = "$PSScriptRoot/tests"
$scriptPath = "$PSScriptRoot/scripts/Deploy-AzureServerlessStack.ps1"

switch ($TestMode) {
    "Unit" {
        Write-Host "[UNIT] Running Unit Tests..." -ForegroundColor Green
        $result = Invoke-Pester `
            -Path "$testPath/Deploy-AzureServerlessStack.Tests.ps1" `
            -Output $Verbosity
    }
    "E2E" {
        Write-Host "[E2E] Running End-to-End Tests..." -ForegroundColor Green
        $result = Invoke-Pester `
            -Path "$testPath/E2E-Deploy-AzureServerlessStack.Tests.ps1" `
            -Output $Verbosity
    }
    "Coverage" {
        Write-Host "[COVERAGE] Running Tests with Code Coverage..." -ForegroundColor Green
        $result = Invoke-Pester `
            -Path $testPath `
            -CodeCoverage $scriptPath `
            -CodeCoverageThreshold 0.9 `
            -Output $Verbosity
    }
    "All" {
        Write-Host "[ALL] Running All Tests..." -ForegroundColor Green
        $result = Invoke-Pester `
            -Path $testPath `
            -CodeCoverage $scriptPath `
            -Output $Verbosity
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($result) {
    Write-Host "Total Tests: $($result.TotalCount)" -ForegroundColor White
    Write-Host "Passed: $($result.PassedCount)" -ForegroundColor Green
    Write-Host "Failed: $($result.FailedCount)" -ForegroundColor Red
    Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
    
    if ($result.CodeCoverage) {
        Write-Host "Coverage: $([math]::Round($result.CodeCoverage.CoveragePercent, 2))%" -ForegroundColor $( 
            if ($result.CodeCoverage.CoveragePercent -ge 90) { "Green" }
            else { "Yellow" }
        )
    }
    
    if ($result.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "FAILED TESTS:" -ForegroundColor Red
        $result.Failed | ForEach-Object {
            Write-Host "  - $($_.Name)" -ForegroundColor Red
        }
        exit 1
    }
    
    if ($result.CodeCoverage.CoveragePercent -lt 90) {
        Write-Host ""
        Write-Host "⚠️  Coverage below 90% threshold!" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Test run failed" -ForegroundColor Red
    exit 1
}
