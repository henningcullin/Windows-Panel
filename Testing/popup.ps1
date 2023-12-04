Add-Type -AssemblyName System.Windows.Forms

# Create the main form
$mainForm = New-Object System.Windows.Forms.Form 
$mainForm.Text = "Main Form"
$mainForm.Size = New-Object System.Drawing.Size(300,200) 
$mainForm.StartPosition = "CenterScreen"

# Create a button on the main form to open the second form
$button = New-Object System.Windows.Forms.Button
$button.Location = New-Object System.Drawing.Point(75,120)
$button.Size = New-Object System.Drawing.Size(150,23)
$button.Text = "Create new autostart item"
$mainForm.Controls.Add($button)

# Create the second form
$secondForm = New-Object System.Windows.Forms.Form 
$secondForm.Text = "Second Form"
$secondForm.Size = New-Object System.Drawing.Size(300,200) 
$secondForm.StartPosition = "CenterScreen"

# Create a text box on the second form to enter data
$textBox = New-Object System.Windows.Forms.TextBox 
$textBox.Location = New-Object System.Drawing.Point(10,40) 
$textBox.Size = New-Object System.Drawing.Size(260,20) 

$secondForm.Controls.Add($textBox) 

# Create an OK button on the second form to return data to the main form
$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(75,120)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$secondForm.AcceptButton = $OKButton
$secondForm.Controls.Add($OKButton)

# When the button on the main form is clicked, open the second form and get the data
$button.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.InitialDirectory = "C:\"
    $openFileDialog.Filter = "All files (*.*)|*.*"
    $openFileDialog.ShowDialog() | Out-Null
    $openFileDialog.FileName

    $mainForm.Text = $openFileDialog.FileName

    $result = $secondForm.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $x = $textBox.Text
        #$mainForm.Text = "Data from second form: $x"
    }
})

# Show the main form
$mainForm.ShowDialog()