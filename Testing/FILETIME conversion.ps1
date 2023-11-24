$keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"

$key = Get-Item -Path $keyPath

$item = $key.GetValueNames()[0]

$bin = $key.GetValue($item, $null)

$data = [System.BitConverter]::ToString($bin) -replace '-'

$start = $data.Substring(0, 2)
$end = $data.Substring(2 + 6)

$hex = $start + $end

# Convert the REG_BINARY value to a byte array
$bytes = [byte[]]($hex -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })

# Convert the byte array to a long (Int64)
$filetime = [BitConverter]::ToInt64($bytes, 1) # start from the second byte

# Convert the FILETIME (represented as a long) to a DateTime object
$dateTime = [DateTime]::FromFileTimeUtc($filetime)

# Output the DateTime object
$dateTime.ToLocalTime()

if ([Int]$start -eq 2 -or [Int]$start -eq 6) {
    Write-Host "Program is on"
} 
elseif([Int]$start -eq 3) {
    Write-Host "Program is off"
}
else {
    Write-Host "Can't resolve status"
}
