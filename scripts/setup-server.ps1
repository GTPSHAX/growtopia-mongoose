#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$CloudflareUrl  = "https://www.cloudflare.com/ips-v4/"
$Port           = 8080
$Protocol       = "TCP"
$RulePrefix     = "Cloudflare-IPv4-TCP${Port}"
$RuleGroup      = "Cloudflare Allowlist"
$RuleDescription = "Auto-generated: allow Cloudflare IP range on TCP $Port"

function Write-Log  { param([string]$Msg) Write-Host "[INFO]  $Msg" -ForegroundColor Cyan }
function Write-Warn { param([string]$Msg) Write-Host "[WARN]  $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red; exit 1 }

function Assert-Admin {
  $current = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($current)
  if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "This script must be run as Administrator."
  }
}

function Get-CloudflareIPs {
  Write-Log "Fetching Cloudflare IPv4 ranges from $CloudflareUrl ..."
  try {
    $response = Invoke-WebRequest -Uri $CloudflareUrl -UseBasicParsing -TimeoutSec 30
    $ips = ($response.Content -split "`n") |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$' }
    return $ips
  }
  catch {
    Write-Fail "Failed to fetch IP list: $_"
  }
}

function Add-FirewallRule {
  param(
    [string]$Cidr
  )

  $ruleName = "${RulePrefix}-${Cidr}"

  # Check if the rule already exists
  $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

  if ($existing) {
    Write-Warn "Rule already exists: '$ruleName' — skipping."
    return
  }

  Write-Log "Creating rule: $ruleName"
  New-NetFirewallRule `
    -DisplayName  $ruleName `
    -Description  $RuleDescription `
    -Group        $RuleGroup `
    -Direction    Inbound `
    -Action       Allow `
    -Protocol     $Protocol `
    -LocalPort    $Port `
    -RemoteAddress $Cidr `
    -Enabled      True `
    | Out-Null
}

Assert-Admin

$ipList = Get-CloudflareIPs

if (-not $ipList -or $ipList.Count -eq 0) {
  Write-Fail "No IP ranges retrieved. Check your internet connection."
}

Write-Log "Retrieved $($ipList.Count) Cloudflare IP range(s):"
$ipList | ForEach-Object { Write-Host "  $_" }

Write-Log "Applying Windows Firewall rules for TCP port $Port ..."

foreach ($cidr in $ipList) {
  Add-FirewallRule -Cidr $cidr
}

Write-Log "All done! $($ipList.Count) rule(s) processed for TCP port $Port."
Write-Log "To review: Get-NetFirewallRule -Group '$RuleGroup' | Format-Table DisplayName, Enabled, Action"
