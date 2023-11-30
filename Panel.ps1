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
            $vtype = $DataKey.GetValueKind($value)
            $bin = $StatusKey.GetValue($value, $null)

            if ($null -ne $bin) {
                $data = [System.BitConverter]::ToString($bin) -replace '-'

                $start = $data.Substring(0, 2)

                $end = $data.Substring(2 + 6)

                $status = switch ([Int]$start) {
                    2 { $true }
                    6 { $true } # Add something to handle different permission levels
                    3 { $false }
                    default { $null }
                }

                if ($null -eq $status) {
                    continue
                }
                if ($status -eq $false -or $end -ge 1) {

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
                ItemType = 'reg'
                ValueType = $vtype
                DataKey = $D
                StatusKey = $S
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

        $pnl = [System.Windows.Forms.Panel]::new()
        $pnl.Height = 128
        $pnl.Width = 245
        $pnl.Name = 'pnl_'+$item.Name

        $lblName = [System.Windows.Forms.Label]::new()
        $lblName.Font = New-Object System.Drawing.Font("Lucida Console", 11, [System.Drawing.FontStyle]::Regular)
        $lblName.Width = 200
        $lblName.Height = 32
        $lblName.Name = 'lbl_Name_'+$item.Name
        $lblName.Text = Get-Name $item.Path
        
        $icon = Get-Icon $item.Path

        $pbx = [System.Windows.Forms.PictureBox]::new()
        $pbx.Width = 32  # Adjust as needed
        $pbx.Height = 32  # Adjust as needed
        $pbx.Location = [System.Drawing.Point]::new(64, 32)
        $pbx.Name = $item.Name
        $pbx.Image = $icon.ToBitmap()

        $cbx = [System.Windows.Forms.Checkbox]::new()
        $cbx.Location = [System.Drawing.Point]::new(30, 72)
        $cbx.Name = 'cbx_Status_' + $item.Name
        $cbx.Text = If ($item.Status) {'ON'} Else {'OFF'}
        $cbx.Checked = $item.Status
        $cbx.Add_CheckedChanged({
            switch ($cbx.Checked) {
                $true {
                    $cbx.Text = 'ON'
                    Write-Host 'SET KEY' $item.Name 'TO ON'
                }
                $false {
                    $cbx.Text = 'OFF'
                    Write-Host 'SET KEY' $item.Name 'TO OFF'
                }
            }
        }.GetNewClosure())



        $pnl.Controls.Add($lblName)
        $pnl.Controls.Add($pbx)
        $pnl.Controls.Add($cbx)

        $flp.Controls.Add($pnl)
    }


    $form = $script:form
    $form.Text = "AutoStart"

    $flp = [System.Windows.Forms.FlowLayoutPanel]::new()
    $flp.Dock = 'Fill'
    $flp.Name = 'Panel'
    $form.Controls.Add($flp)

    $Items += Get-RegItems -D 'MR' -S 'MSR'
    $items += Get-RegItems -D 'UR' -S 'USR'

    foreach ($Item in $Items) {
        Draw-Item $Item
        Write-Output $Item
    }

    $form.ShowDialog()
}

AutoStart


