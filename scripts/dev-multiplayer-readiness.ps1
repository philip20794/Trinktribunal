function Test-WebClientCompilation([string]$OutputLog, [string]$ErrorLog, [string]$Url) {
    if (Test-Path -LiteralPath $ErrorLog) {
        $errors = Get-Content -LiteralPath $ErrorLog -Raw
        if ($errors -and $errors.Contains('Failed to compile application.')) {
            $details = @($errors -split '\r?\n' | Where-Object { $_ -match 'Error:|Failed to compile application\.' }) -join [Environment]::NewLine
            throw "Client-Kompilierung fehlgeschlagen:$([Environment]::NewLine)$details$([Environment]::NewLine)Log: $ErrorLog"
        }
    }
    if (-not (Test-Path -LiteralPath $OutputLog)) { return $false }
    $output = Get-Content -LiteralPath $OutputLog -Raw
    return ($null -ne $output -and $output.Contains("is being served at $Url"))
}
