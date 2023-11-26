Add-Type -AssemblyName System.Windows.Forms

$form = [System.Windows.Forms.Form]::new()
$form.Text = "Windows Panel"
$form.Size = [System.Drawing.Size]::new(1024, 640)
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false


function AutoStart {

    $regKeyList = New-Object PSObject -Property @{
        MR = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        MRO = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        MWR = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
        MWRO = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
        MS = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
        MSR = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        MS32 = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
        MSS = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
        UR = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        URO = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
        US = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
        USR = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
        USS = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
    }

    $regObjects = New-Object PSObject -Property @{
        
    }

    function Format-Path {
        param ([String]$path)
        $path = $path -replace '(\s-.*$)'
        return $path -replace '"', ''
    }

    function Get-RegItems {
        param ([String]$D, [String]$S)
        $items = @()

        $DataKey = Get-Item -Path ($regKeyList.$D)
        $StatusKey = Get-Item -Path ($regKeyList.$S)

        foreach ($value in $Datakey.GetValueNames()) {
            $path = $DataKey.GetValue($value, $null)
            $type = $DataKey.GetValueKind($value)
            $bin = $StatusKey.GetValue($value, $null)

            if ($null -ne $bin) {
                $data = [System.BitConverter]::ToString($bin) -replace '-'

                $start = $data.Substring(0, 2)

                $status = switch ([Int]$start) {
                    2 { 'On' }
                    6 { 'On' } # Add something to handle different permission levels
                    3 { 'Off' }
                    default { $null }
                }

                if ($null -eq $status) {
                    continue
                }
                if ($status -eq 'off') {
                    $end = $data.Substring(2 + 6)

                    $hex = $start + $end

                    # Convert hex to bytes
                    $bytes = [byte[]]($hex -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })

                    # Convert the byte array to a long (Int64)
                    $filetime = [BitConverter]::ToInt64($bytes, 1) # start from the second byte

                    # Convert the FILETIME (represented as a long) to a DateTime object
                    $time = [DateTime]::FromFileTimeUtc($filetime)
                }
                else {
                    $time = $null
                }
            }

            $object = New-Object PSObject -Property @{
                Name = $value
                Type = $type
                Path = $path
                Status = $status
                Time = $time
            }

            $items += $object
        }
        return $items
    }

    function Toggle-Item {

    }
    function Create-Item {
        if ($yourPath -match '%[a-zA-Z0-9_]+%') {
            # If it contains environment variables, use REG_EXPAND_SZ
            #New-ItemProperty -Path "HKCU:\SOFTWARE\Example" -Name "MyValue" -PropertyType ExpandString -Value $yourPath
        }
        else {
            # If it doesn't contain environment variables, use REG_SZ
            #New-ItemProperty -Path "HKCU:\SOFTWARE\Example" -Name "MyValue" -PropertyType String -Value $yourPath
        }
    }
    function Draw-Item {
        param ([Object]$item)
        function Get-Icon {
            param ([String]$path)
            $path = Format-Path $path
            return [System.Drawing.Icon]::ExtractAssociatedIcon($path)
        }
        function Get-Name {

            param ([String]$path)

            $path = Format-Path $path
            
            $file = Get-ChildItem $path

            $fileDesc = $file.PSObject.Properties.Value.FileDescription

            if ($fileDesc -ne '') {
                return $fileDesc
            }
            else {
                return $file.BaseName
            }
        }

        $itemBox = [System.Windows.Forms.Panel]::new()
        $itemBox.Height = 128
        $itemBox.Width = 245
        $itemBox.Tag = $item.Name
        $itemBox.Add_Click({
            Write-Host "Clicked on $($this.Tag)"
        })

        $lbl = [System.Windows.Forms.Label]::new()
        $lbl.Font = New-Object System.Drawing.Font("Lucida Console",11,[System.Drawing.FontStyle]::Regular)
        $lbl.Width = 200
        $lbl.Height = 32
        $lbl.Text = Get-Name $item.Path
        
        $pbx = [System.Windows.Forms.PictureBox]::new()

        $icon = Get-Icon $item.Path

        $pbx.Width = 64  # Adjust as needed
        $pbx.Height = 64  # Adjust as needed
        $pbx.Location = [System.Drawing.Point]::new(64,32)
        $pbx.Image = $icon.ToBitmap()

        $itemBox.Controls.Add($lbl)
        $itemBox.Controls.Add($pbx)
        $flp.Controls.Add($itemBox)
    }

    $form = $script:form
    $form.Text = "AutoStart"

    $flp = [System.Windows.Forms.FlowLayoutPanel]::new()
    $flp.Dock = 'Fill'
    $form.Controls.Add($flp)

    $GlobalRegItems = Get-RegItems -D 'MR' -S 'MSR'
    $LocalRegItems = Get-RegItems -D 'UR' -S 'USR'

    foreach ($Item in $GlobalRegItems) {
        Draw-Item $Item
    }
    foreach ($Item in $LocalRegItems) {
        Draw-Item $Item
    }

    $form.ShowDialog()



    $LocalRegItems[0]
}

AutoStart


