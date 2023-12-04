Add-Type -AssemblyName System.Windows.Forms

$form = [System.Windows.Forms.Form]::new()
$form.Text = "Windows Panel"
$form.Size = [System.Drawing.Size]::new(1024, 640)
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
        $path = $path -replace '"', ''
        $extIndex = $Path.LastIndexOf('.')
        return $Path.Substring(0, $extIndex+4)
    }

    function Get-RegItems {
        param ([String]$D, [String]$S)
        $items = @()

        $DataKey = Get-Item -Path ($regKeyList.$D)
        $StateKey = Get-Item -Path ($regKeyList.$S)

        foreach ($value in $Datakey.GetValueNames()) {
            $path = $DataKey.GetValue($value, $null)
            $bin = $StateKey.GetValue($value, $null)

            if ($null -ne $bin) {
                $data = [System.BitConverter]::ToString($bin) -replace '-'
                $start = $data.Substring(0, 2)
                $stateType = [Int]$start
                $end = $data.Substring(2 + 6)
                $state = switch ([Int]$start) {
                    2 { $true }
                    0 { $true }
                    6 { $true } # Add something to handle different permission levels
                    1 { $false }
                    3 { $false }
                    default { $null }
                }

                if ($null -eq $state) {
                    continue
                }

                if ($state -eq $false -or $end -ge 1) {
                    $hex = $start + $end
                    $bytes = [byte[]]($hex -split '(..)' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })# Convert hex to bytes
                    $filetime = [BitConverter]::ToInt64($bytes, 1) # Convert the byte array to a long (Int64), start from the second byte
                    $time = [DateTime]::FromFileTimeUtc($filetime)# Convert the FILETIME (represented as a long) to a DateTime object
                }
                else {
                    $time = $null
                }
            }

            $object = New-Object PSObject -Property @{
                Name = $value
                DataKey = $D
                StateKey = $S
                Path = $path
                State = $state
                StateType = $stateType
                Time = $time
            }

            $items += $object
        }
        return $items
    }

    function global:Toggle-Item {
        param ([String]$key, [String]$name, [String]$state)

        $time = Get-Date
        $filetime = $time.ToFileTimeUtc()
        $arr = $null
        $arr = [byte[]]@($state, '0', '0', '0') + [System.BitConverter]::GetBytes($filetime)
        if($null -eq $arr) {
            Write-Host "ERROR SETTING $name"
            return
        }

        Set-ItemProperty -Path $regKeyList.$key -Name $name -Type Binary -Value $arr

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
        Write-Host "Create-Item called"
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
        $pnl.Width = 190

        $lblName = [System.Windows.Forms.Label]::new()
        $lblName.Font = New-Object System.Drawing.Font("Lucida Console", 11, [System.Drawing.FontStyle]::Regular)
        $lblName.Width = 190
        $lblName.Height = 32
        $lblName.TextAlign = 'TopCenter'
        $lblName.Text = Get-Name $item.Path

        $icon = Get-Icon $item.Path
        $pbx = [System.Windows.Forms.PictureBox]::new()
        $pbx.Width = 32  # Adjust as needed
        $pbx.Height = 32  # Adjust as needed
        $pbx.Location = [System.Drawing.Point]::new(82, 32)
        $pbx.Image = $icon.ToBitmap()

        $cbx = [System.Windows.Forms.Checkbox]::new()
        $cbx.Location = [System.Drawing.Point]::new(32, 72)
        $cbx.Text = If ($item.State) {'ON'} Else {'OFF'}
        $cbx.Checked = $item.State

        $cbx.Add_CheckedChanged({
            switch ($cbx.Checked) {
                $true {
                    $cbx.Text = 'ON'
                    Write-Host 'SET KEY' $item.Name 'TO ON'
                    Toggle-Item -key $item.StateKey -name $item.Name -state '2'
                }
                $false {
                    $cbx.Text = 'OFF'
                    Write-Host 'SET KEY' $item.Name 'TO OFF'
                    Toggle-Item -key $item.StateKey -name $item.Name '3'
                }
            }
        }.GetNewClosure())



        $pnl.Controls.Add($lblName)
        $pnl.Controls.Add($pbx)
        $pnl.Controls.Add($cbx)

        $mainPanel.Controls.Add($pnl)
    }


    $form = $script:form
    $form.Text = "AutoStart"


    $tableLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $tableLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tableLayout.RowCount = 2
    $tableLayout.Padding = 0
    $tableLayout.Margin = 0
    $form.Controls.Add($tableLayout)
    
    $topBar = New-Object System.Windows.Forms.FlowLayoutPanel
    $topBar.Height = 35
    $topBar.Dock = 'Fill'
    $tableLayout.Controls.Add($topBar, 0, 0)

    $btnNew = [System.Windows.Forms.Button]::new()
    $btnNew.Text = 'New item'
    $topBar.Controls.Add($btnNew)
    
    $mainPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $mainPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tableLayout.Controls.Add($mainPanel, 0, 1)

    $Items += Get-RegItems -D 'MR' -S 'MSR'
    $Items += Get-RegItems -D 'UR' -S 'USR'
    $Items += Get-RegItems -D 'MWR' -S 'MS32'

    foreach ($Item in $Items) {
        Draw-Item $Item
    }

    $form.ShowDialog()
}


AutoStart