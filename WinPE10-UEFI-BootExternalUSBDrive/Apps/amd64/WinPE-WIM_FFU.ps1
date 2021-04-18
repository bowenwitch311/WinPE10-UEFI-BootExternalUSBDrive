# www.AlexComputerBubble - Capture And Apply Windows Images (WIM & FFU)
# =================================================================

# chargement des forms additionnels en provenance du DotNet
#
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$volumes = (Get-WmiObject -Query "SELECT * from Win32_LogicalDisk" | Select -Property Properties )
foreach($i In $volumes){
    switch ("$($i.Properties.Item("VolumeName").Value)")               # on cible la partition intitulé IMAGEDATA
    {
    "IMAGEDATA" {
        #$partition = $i.Properties.Item("VolumeName").Value           # Récupère le nom du volume
        $drive = $i.Properties.Item("Caption").Value                   # Maj du champ Caption dans le formulaire
        }
    }
}
[string]$letter = ($Script:drive -replace ":", "")                     # on supprimer les ":"
New-PSDrive -Name [string]$letter -PSProvider FileSystem -Root $drive  
$Script:stringUSB = $letter + ":\Images"                               # Lien vers le dossier \Images
$strWimFilePath = "$Script:stringUSB\WIM-Files"                        # Lien vers le dossier \Image\WIM-Files
$strFFUFilePath = "$Script:stringUSB\FFU-Files"                        # Lien vers le dossuier Ìmage\FFU-Files
$Script:partitionDrive = ""

# Le code ci-dessous permet une utilisation avec une clé USB
#
<#
NOTE: to be able to work with USB stick I used this code and replaced it with the code above (for testing purpose):

$objwmi = Get-WmiObject -Query "SELECT * from Win32_DiskDrive WHERE InterfaceType = 'USB'"
foreach($wmiDiskDrive In $objwmi){
    $strColOfDiskPartitions = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskDrive.DeviceID='$($wmiDiskDrive.DeviceID)'} WHERE AssocClass=Win32_DiskDriveToDiskPartition"
    foreach($strDiskPartitionItem In $strColOfDiskPartitions){
       $strColOfLogicalDisks = Get-WmiObject -Query "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($strDiskPartitionItem.DeviceID)'} WHERE AssocClass=Win32_LogicalDiskToPartition"
       $Script:usbLetter = $strColOfLogicalDisks.DeviceID
    }
}
[string]$letter = ($Script:usbLetter -replace ":", "")
New-PSDrive -Name [string]$letter -PSProvider FileSystem -Root $usbLetter -ErrorAction SilentlyContinue

$Script:stringUSB = $letter + ":\Images"
$strWimFilePath = "$Script:stringUSB\WIM-Files"
$strFFUFilePath = "$Script:stringUSB\FFU-Files"
$Script:partitionDrive = ""
#>

# NOTE: remove in production version
# Checking the number of disk drives being detected

New-Item -Path $env:TEMP -Name ListDisk.txt -ItemType File -Force | Out-Null
Add-Content -Path $env:TEMP\ListDisk.txt "List disk"                     # ListDisk.txt contient la commande List Disk
$listDisk = (DiskPart /s $env:TEMP\ListDisk.txt)                         # Diskpart /s ListDisk.txt, affiche la liste des disques dur
$diskID = $listDisk[-1].Substring(7,2).Trim()                            # a adapter en fonction de la langue
$totalDisk = $diskID
If($totalDisk -lt 1){
    $mainImage = "X:\Windows\System32\PartitionPics\Warning.png"
}
Else{
    $mainImage = "X:\Windows\System32\PartitionPics\AI.png"
}

# =================================================================
# Functions
# =================================================================

Function do_ListPartitions{                                         # création d'un tableau d'informations sur les disques disponibles
$array = New-Object System.Collections.ArrayList

Function do_ComputeSize {                                           # la fonction prend en charge la taille du disque
    	Param (
    		[double]$Size
    	)
    	If ($Size -gt 1000000000)                                   # taille supérieur au Gb, traitement Gb
    	{	$ReturnPartitionSize = "{0:N2} GB" -f ($Size / 1GB)
    	}
    	Else                                                        # sinon, traitement Mb
    	{	$ReturnPartitionSize = "{0:N2} MB" -f ($Size / 1MB)
    	}
    	Return $ReturnPartitionSize
    }

$Script:partitionInfo = @(                                          # mise en forme d'un tableau d'information disques durs
$partitionCollection = (Get-WmiObject -Class Win32_LogicalDisk |
Select-Object -Property DeviceID, VolumeName, Size, Description )
#$partitions = ($partitionCollection | Select DeviceID).DeviceID
$partitions = ($partitionCollection | Select DeviceID, VolumeName, Size, Description)
ForEach ($partitionLetter in $partitions) {
        $deviceSize = (do_ComputeSize $partitionLetter.Size)
        [pscustomobject]@{DriveLetter=$partitionLetter.DeviceID;VolumeName=$partitionLetter.VolumeName;Size=$deviceSize;Description=$partitionLetter.Description}
}
)

 $array.AddRange($partitionInfo)
 $partitionDriveGrid.DataSource = $array                            # On l'ajoute dans un DataGrid pour l'affichage
 $objform.refresh()                                                 # on rafraichit les contrôles du formalaire
}

function do_GetFolderTree {                                         # permet de filtrer les informations

function Add-Node {                                                 # permet d'ajouter un noeud d'information disque
        param ( 
            $selectedNode, 
            $name, 
            $tag 
        ) 
        $newNode = new-object System.Windows.Forms.TreeNode  
        $newNode.Name = $name 
        $newNode.Text = $name 
        $newNode.Tag = $tag 
        $selectedNode.Nodes.Add($newNode) | Out-Null 
        return $newNode 
} 

    if ($script:folderItem)  
    {  
        $treeview1.Nodes.remove($script:folderItem) 
        $objform.refresh()  
    } 
    $script:folderItem = New-Object System.Windows.Forms.TreeNode   # filtre définition
    $script:folderItem.text = "Images Folder" 
    $script:folderItem.Name = "Images Folder" 
    $script:folderItem.Tag = "root" 
    $treeView1.Nodes.Add($script:folderItem) | Out-Null     
     
    #Generate Module nodes 
    $folders = @("$Script:stringUSB\Wim-Files", "$Script:stringUSB\FFU-Files")
     
    $folders | % { 
        $parentNode = Add-Node $script:folderItem $_ "Folder" 
        $folderContent = Get-ChildItem $_ -ErrorAction SilentlyContinue
        $folderContent | % { 
            $childNode = Add-Node $parentNode $_.Name "File" 
        } 
    } 
    $script:folderItem.Expand() 
} 

Function do_GetWindowsFirmwareType{
$regKey = (Get-ItemProperty -Path "REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control")
$regKey.PSObject.Properties | ForEach-Object {
    If($_.Name -eq "PEFirmwareType"){
        Switch($_.Value){
            "1"{                                                                           # PC LEGACY BIOS
                $labelDismCaptureFirmwareType.Text = "The PC is booted in BIOS mode"
                $labelDismCaptureFirmwareType.Refresh()
                $labelFFUCaptureFirmwareType.Text = "The PC is booted in BIOS mode"
                $labelFFUCaptureFirmwareType.Refresh()

                $labelDismApplyFirmwareType.Text = "The PC is booted in BIOS mode"
                $labelDismApplyFirmwareType.Refresh()

                $labelFFUApplyFirmwareType.Text = "The PC is booted in BIOS mode"
                $labelFFUApplyFirmwareType.Refresh()
               }
            "2"{                                                                           # PC UEFI BIOS
                $labelDismCaptureFirmwareType.Text = "The PC is booted in UEFI mode"
                $labelDismCaptureFirmwareType.Refresh()
                $labelFFUCaptureFirmwareType.Text = "The PC is booted in UEFI mode"
                $labelFFUCaptureFirmwareType.Refresh()

                $labelDismApplyFirmwareType.Text = "The PC is booted in UEFI mode"
                $labelDismApplyFirmwareType.Refresh()

                $labelFFUApplyFirmwareType.Text = "The PC is booted in UEFI mode"
                $labelFFUApplyFirmwareType.Refresh()                            
               }
	        Default {                                                                      # PC BIOS non identifié
                $labelDismCaptureFirmwareType.Text = "Can't figure out the firmware type"
                $labelDismCaptureFirmwareType.Refresh()
                $labelFFUCaptureFirmwareType.Text = "Can't figure out the firmware type"
                $labelFFUCaptureFirmwareType.Refresh()

                $labelDismApplyFirmwareType.Text = "Can't figure out the firmware type"
                $labelDismApplyFirmwareType.Refresh()

                $labelFFUApplyFirmwareType.Text = "Can't figure out the firmware type"
                $labelFFUApplyFirmwareType.Refresh()                            
                            
                 }
        }
    }
  }
}

Function do_GetWindowsPartition{
$partitionWinCollection = (Get-WmiObject -Class Win32_LogicalDisk |
Select-Object -Property DeviceID, VolumeName, DriveType, Caption |
Where -FilterScript {$_.DriveType -eq 3 -and $_.Caption -ne "X:"})

If($partitionWinCollection){
    $winPartitionFound = $false
    foreach($partition in $partitionWinCollection){
            If([System.IO.Directory]::Exists("$("$($partition.DeviceID)\Windows\System32")") -and (Test-Path -Path "$("$($partition.DeviceID)\Windows\System32")")){
            $Script:driveWinPartition = $partition.DeviceID
            $labelPartitionDismToCapture.Text = "Creating an image of Drive $($partition.DeviceID) Partition"
            $winPartitionFound = $true
            Break
            }
            
    } # end of foreach
    If($winPartitionFound -eq $false) {
                [System.Windows.Forms.MessageBox]::Show("Windows partition not found!")
    }
 }
}

Function do_FindChecked($node) {

  foreach ($n in $node.nodes) {
    if ($n.checked) { 
        # [System.Windows.Forms.MessageBox]::Show($n.FullPath.Replace("Images Folder\", ""))
        do_RemoveImageFiles $n.FullPath.Replace("Images Folder\", "") 
    }
    do_FindChecked($n)
  }
}

Function do_UncheckChecked($node) {
  foreach ($n in $node.nodes) {
    if ($n.checked) { $n.Checked = $false }
    do_UncheckChecked($n)
  }
}

Function do_RemoveImageFiles($fileName){
        # Delete image files 
        If(Test-Path -Path $fileName) {
            Remove-Item -Path $fileName -Force -Confirm:$false
            #[System.Windows.Forms.MessageBox]::Show($fileName)
        }
        Else{
            [System.Windows.Forms.MessageBox]::Show("File not removed, please make sure the file exists")
        }
}

Function do_DeleteImageFiles {
    $confirmDelImgFile = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete checked image file(s)?" , "Confirm Action!" , 4)
    If ($confirmDelImgFile -eq "YES") {
        do_FindChecked($treeView1) | Out-Null
        do_GetFolderTree
        $objform.refresh()
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
        do_UncheckChecked($treeView1.Nodes)
    }
}

Function do_ListWimFiles{

$Script:filesCollection = (Get-ChildItem -Path $strWimFilePath -Recurse -Force | 
? -FilterScript{$_.Extension -match ".wim"} | 
Select-Object -Property Name, FullName)
$comboBoxDismApply.Items.Clear()
    $comboBoxDismApply.BeginUpdate() 
    foreach($file in $filesCollection){
        $comboBoxDismApply.Items.add($file.Name) | Out-Null
    }
    $comboBoxDismApply.EndUpdate() 
 $objForm.Refresh()
}

Function do_ListFFUFiles{

$Script:filesCollection = (Get-ChildItem -Path $strFFUFilePath -Recurse -Force | 
? -FilterScript{$_.Extension -match ".ffu"} | 
Select-Object -Property Name, FullName)
$comboBoxFFUApply.Items.Clear()
    $comboBoxFFUApply.BeginUpdate() 
    foreach($file in $filesCollection){
        $comboBoxFFUApply.Items.add($file.Name) | Out-Null
    }
    $comboBoxFFUApply.EndUpdate() 
 $objForm.Refresh()
}

# Functions for the whole Form
# =================================================================

Function do_RunRefreshForm{
    do_ListPartitions
    do_GetFolderTree
    do_GetWindowsPartition
    do_RefreshSomeControls
    do_ListWimFiles
    do_ListFFUFiles
    do_StartLabels("REFRESH")
    $Script:partitionDrive = ""
    $objform.refresh()
}

Function do_Restart{
 $confirmRestart = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to Restart?" , "Confirm Action!" , 4)
If ($confirmRestart -eq "YES") {
    $command = "X:\Windows\System32\Cmd.exe /c wpeutil Reboot"
    Invoke-Expression $command
}
else{
    [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
 }
}

Function do_Shutdown{
$confirmShutdown = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to Shutdown?" , "Confirm Action!" , 4)
If ($confirmShutdown -eq "YES") {
    $command = "X:\Windows\System32\Cmd.exe /c wpeutil Shutdown"
    Invoke-Expression $command
}
else{
    [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
 }
}

Function do_RefreshSomeControls{
$ErrorActionPreference = 'SilentlyContinue'
$applyDropDownFfu.SelectedItem=$null
$comboBoxDismApply.SelectedItem=$null
$comboBoxFFUApply.SelectedItem=$null
$DropDownFfu.SelectedItem=$null
$deleteButtonSelectDismFile.Visible = $False
$stopButtonDismCaptureProcess.Visible = $False
$stopButtonDismCaptureProcess.Refresh()
$stopButtonFFUCaptureProcess.Visible = $False
$stopButtonFFUCaptureProcess.Refresh()
$stopButtonApplyDismProcess.Visible = $False
$stopButtonApplyDismProcess.Refresh()
$stopButtonApplyFFUProcess.Visible = $False
$stopButtonApplyFFUProcess.Refresh()
$deleteButtonSelectFFUFile.Visible = $False
$deleteButtonSelectFFUFile.Refresh()
$labelPartitionDismToCapture.Text = ""
$labelPartitionDismToCapture.Refresh()
$labelPartitionFFUApply.Text = ""
$labelPartitionFFUApply.Refresh()
 If($DropDownFfu.SelectedItem -eq $null){
    $labelPartitionFFUToCapture.Text = ""
    $labelPartitionFFUToCapture.Refresh()
 }
$textBoxDismImageName.Clear()
$textBoxFFUImageName.Clear()
$richBoxDismCapture.Clear()
$richBoxFFUCapture.Clear()
$richBoxDismApply.Clear()
$richBoxFFUApply.Clear()
$objForm.Refresh()
}

Function do_StartLabels($state) {
switch($state)
{
    "REFRESH" {
        do_RefreshSomeControls
    }
    "WIMCAPTURE" {
        $stopButtonDismCaptureProcess.Visible = $True
        $stopButtonDismCaptureProcess.Refresh()
        If($Script:driveWinPartition -ne $null){
            $labelPartitionDismToCapture.Text = "Creating Wim Image of Drive $($Script:driveWinPartition) Partition"
            $labelPartitionDismToCapture.Refresh()
        }
    }
    "FFUCAPTURE" {    
        $stopButtonFFUCaptureProcess.Visible = $True
        $stopButtonFFUCaptureProcess.Refresh()
        If($DropDownFfu.SelectedItem -ne $null){
            $labelPartitionFFUToCapture.Text = "Creating FFU Image of Drive $($DropDownFfu.SelectedItem.ToString())"
            $labelPartitionFFUToCapture.Refresh()
        }
  
     }
    "END-WIMCAPTURE"{
        $stopButtonDismCaptureProcess.Visible = $False
        $stopButtonDismCaptureProcess.Refresh()
        $labelPartitionDismToCapture.Text = ""
        $labelPartitionDismToCapture.Refresh()
    }
    "END-FFUCAPTURE"{        
        $stopButtonFFUCaptureProcess.Visible = $False
        $stopButtonFFUCaptureProcess.Refresh()
        $labelPartitionFFUToCapture.Text = ""
        $labelPartitionFFUToCapture.Refresh()       
     }
    "WIM-APPLY" {
        $stopButtonApplyDismProcess.Visible = $True
        $stopButtonApplyDismProcess.Refresh()
        $deleteButtonSelectDismFile.Visible = $True
        $deleteButtonSelectDismFile.Refresh()
     }
    "FFU-APPLY" {
        $stopButtonApplyFFUProcess.Visible = $True
        $stopButtonApplyFFUProcess.Refresh()
        $deleteButtonSelectFFUFile.Visible = $True
        $deleteButtonSelectFFUFile.Refresh()
     }
    "END-WIMAPPLY"{
        $stopButtonApplyDismProcess.Visible = $False
        $stopButtonApplyDismProcess.Refresh()
        $deleteButtonSelectDismFile.Visible = $False
        $deleteButtonSelectDismFile.Refresh()
     }
    "END-FFUAPPLY"{
        $stopButtonApplyFFUProcess.Visible = $False
        $stopButtonApplyFFUProcess.Refresh()
        $deleteButtonSelectFFUFile.Visible = $False
        $deleteButtonSelectFFUFile.Refresh()
     }
}
$objForm.Refresh()
}

# Functions Create Image - DISM
# =================================================================

Function do_CaptureImage($winDrive,$imageFilePath,$imageDesc){
    $Name = $imageDesc -replace '.*\\(.*)','$1'
    # Push-Location X:\Windows\system32\GImageX\
    Push-Location X:\Windows\system32\
    Start-Process dism.exe -ArgumentLIst "/Capture-Image /ImageFile:$imageFilePath /CaptureDir:$winDrive /Name:""$Name"" "
    If($?){
        # Imaging process finished successfully!!!
        # [System.Windows.Forms.MessageBox]::Show("$winDrive $imageFilePath ""$Name"" " , "Create Image!" , 4)
    }
    Else{
        [System.Windows.Forms.MessageBox]::Show('Error encountered while capturing image!!!')
    } 
    [int]$Script:processDismWimImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "imagex"} |Select -Property $_.Id).Id
}

Function do_CheckInputAndCaptureWim{

If($strWimFilePath -eq $null){
    [System.Windows.Forms.MessageBox]::Show("Please note: Folder for .wim file not found!")
    return
}
If($textBoxDismImageName.Text -eq $null -or $textBoxDismImageName.Text.Length -eq 0){
    [System.Windows.Forms.MessageBox]::Show("Please type a name for Wim File!")
    $textBoxDismImageName.Focus()
    return
}
If($textBoxDismImageName.Text.Contains(".wim") -or $textBoxDismImageName.Text.Contains(".Wim") ){
    $Script:wimFileName = $textBoxDismImageName.Text
}
else{
    $Script:wimFileName = $textBoxDismImageName.Text + ".wim"
 }
 
$fileTempName = ($Script:wimFileName -replace ".wim", "")
$wimName = $fileTempName + "_Comment.txt"

$confirmCapture = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to capture drive: $($Script:driveWinPartition) and create: $strWimFilePath\" + $Script:wimFileName + " image?" , "Confirm Action!" , 4)
    if ($confirmCapture -eq "YES") {
        New-Item -path $strWimFilePath -name $wimName -itemtype "file" -value $richBoxDismCapture.Text -Force
        do_StartLabels("WIMCAPTURE") 
        do_CaptureImage -winDrive "$($Script:driveWinPartition)" -imageFilePath "$($strWimFilePath)\$Script:wimFileName" -imageDesc $Script:wimFileName
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
}

Function do_StopCreateWimImaging{
[int]$Script:processDismWimImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "dism"} |Select -Property $_.Id).Id

 If ($Script:processDismWimImageID){
    $confirmStopApplyImage = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to stop the apply image process?" , "Confirm Action!" , 4)
    If ($confirmStopApplyImage -eq "YES") {
        Stop-Process -id $Script:processDismWimImageID -Force
        do_StartLabels("END-WIMCAPTURE")
        do_RefreshSomeControls
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }
Else{
    do_StartLabels("END-WIMCAPTURE")
    do_RefreshSomeControls
 }
}

# Functions Create Image - DISM FFU
# =================================================================

Function do_CaptureImageFFU($winDrive,$imageFilePath,$imageDesc){
   $Name = $imageDesc -replace '.*\\(.*)','$1'
   # Push-Location X:\Windows\system32\GImageX\
   Push-Location X:\Windows\system32\
   # [System.Windows.Forms.MessageBox]::Show("$winDrive $imageFilePath ""$Name"" " , "Create FFU Image!" , 4)
   Start-Process dism.exe -ArgumentLIst "/Capture-Ffu /ImageFile:$imageFilePath /CaptureDrive:$winDrive /Name:""$Name"" "
   # exit code for success returned by DISM is 3010 instead of 0
    If($?){
        # Imaging process finished successfully!!!
        # [System.Windows.Forms.MessageBox]::Show("$winDrive $imageFilePath ""$Name"" " , "Create Image!" , 4)
    }
    Else{
        [System.Windows.Forms.MessageBox]::Show('Error encountered while capturing image!!!')
    } 
   [int]$Script:processDismFFUImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "dism"} |Select -Property $_.Id).Id
}

Function do_CheckInputAndCaptureFfu{


If($DropDownFfu.SelectedItem -eq $null){
    [System.Windows.Forms.MessageBox]::Show("Please select drive to be captured!")
    return
}
else{
    $diskFFUNumber = $DropDownFfu.SelectedItem.ToString()
    $driveFfuCapture = (get-ciminstance win32_diskdrive | Select-Object -Property DeviceID, Caption, Index |Where-Object -FilterScript {$_.Index -eq $diskFFUNumber})
    $winFfuDrive = "$($driveFfuCapture.DeviceId)"
    $Name = "Drive$($diskFFUNumber)"
}

If($strFFUFilePath -eq $null){
    [System.Windows.Forms.MessageBox]::Show("Please note: Folder for .FFU file not found!")
    return
}
If($textBoxFFUImageName.Text -eq $null -or $textBoxFFUImageName.Text.Length -eq 0){
    [System.Windows.Forms.MessageBox]::Show("Please type a name for FFU File!")
    $textBoxFFUImageName.Focus()
    return
}
If($textBoxFFUImageName.Text.Contains(".ffu") -or $textBoxFFUImageName.Text.Contains(".Ffu") ){
    $Script:ffuFileName = $textBoxFFUImageName.Text
}
else{
    $Script:ffuFileName = $textBoxFFUImageName.Text + ".ffu"
 }
 
$fileTempName = ($Script:ffuFileName -replace ".ffu", "")
$wimName = $fileTempName + "_Comment.txt"

$confirmCapture = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to capture drive: $($diskFFUNumber) and create: $strFFUFilePath\" + $Script:ffuFileName + " image?" , "Confirm Action!" , 4)
    if ($confirmCapture -eq "YES") {
        New-Item -path $strFFUFilePath -name $wimName -itemtype "file" -value $richBoxFFUCapture.Text -Force
        do_StartLabels("FFUCAPTURE") 
        do_CaptureImageFFU -winDrive "$($winFfuDrive)" -imageFilePath "$($strFFUFilePath)\$Script:ffuFileName" -imageDesc $Script:ffuFileName
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
}

Function do_StopCreateFfuImage{
[int]$Script:processDismFFUImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "dism"} |Select -Property $_.Id).Id

 If ($Script:processDismFFUImageID){
    $confirmStopApplyImage = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to stop the apply image process?" , "Confirm Action!" , 4)
    If ($confirmStopApplyImage -eq "YES") {
        Stop-Process -id $Script:processDismFFUImageID -Force
        do_StartLabels("END-FFUCAPTURE")
        do_RefreshSomeControls
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }
Else{
    do_StartLabels("END-FFUCAPTURE")
    do_RefreshSomeControls
 }
}

# Functions Apply Image - Partition BIOS/UEFI
# =================================================================

Function do_InputPicture ($file){
    #$pic = (Get-Item "$($file)")
    $inputPicture.Visible = $True
    $inputPicture.Image = [System.Drawing.Image]::Fromfile($file)
    $inputPicture.refresh()
}

# Functions Apply Image - Partition FFU for larger drives
# =================================================================

Function do_InputFFUPicture ($file){
    #$pic = (Get-Item "$($file)")
    $inputFFUPartitionPicture.Visible = $True
    $inputFFUPartitionPicture.Image = [System.Drawing.Image]::Fromfile($file)
    $inputFFUPartitionPicture.refresh()
}

Function do_ViewPartition {
    $radioOption = $this.Text
    Switch($radioOption){

    "Default Windows 10 BIOS"{
                $MbrSystemLabel.Visible = $True
                $systemTextbox.Visible = $True
                $MbrWindowsLabel.Visible = $True
                $windowsTextbox.Visible = $True
                $MbrRecoveryLabel.Visible = $True
                $recoveryTextbox.Visible = $True
                #--------------------------------
                $gptSystemLabel.Visible = $False
                $systemGPTTextbox.Visible = $False
                $gptMSRLabel.Visible = $False
                $gptMSRTextbox.Visible = $False
                $gptWindowsLabel.Visible = $False
                $gptWindowsTextbox.Visible = $False
                $gptRecoveryLabel.Visible = $False
                $gptRecoveryTextbox.Visible = $False
                $ffuSystemLabel.Visible = $False
                $ffuSystemTextbox.Visible = $False
                $ffuMSRLabel.Visible = $False
                $ffuMSRTextbox.Visible = $False
                $ffuWindowsLabel.Visible = $False
                $ffuWindowsTextbox.Visible = $False
                $radioButtonFour.Checked = $False
                $radioButtonFive.Checked = $False
                $inputFFUPartitionPicture.Visible = $false
                $inputFFUPartitionPicture.refresh()
                $partitionPic = "X:\Windows\System32\PartitionPics\Win10BIOS.png"
                # $partitionPic = "C:\PSScript\FFU\ICOs\Win10BIOS.png"
                do_InputPicture -file $partitionPic}
    "Default Windows 10 UEFI"{
                $gptSystemLabel.Visible = $True
                $systemGPTTextbox.Visible = $True
                $gptMSRLabel.Visible = $True
                $gptMSRTextbox.Visible = $True
                $gptWindowsLabel.Visible = $True
                $gptWindowsTextbox.Visible = $True
                $gptRecoveryLabel.Visible = $True
                $gptRecoveryTextbox.Visible = $True
                #---------------------------------
                $MbrSystemLabel.Visible = $False
                $systemTextbox.Visible = $False
                $MbrWindowsLabel.Visible = $False
                $windowsTextbox.Visible = $False
                $MbrRecoveryLabel.Visible = $False
                $recoveryTextbox.Visible = $False
                $ffuSystemLabel.Visible = $False
                $ffuSystemTextbox.Visible = $False
                $ffuMSRLabel.Visible = $False
                $ffuMSRTextbox.Visible = $False
                $ffuWindowsLabel.Visible = $False
                $ffuWindowsTextbox.Visible = $False
                $radioButtonFour.Checked = $False
                $radioButtonFive.Checked = $False
                $inputFFUPartitionPicture.Visible = $false
                $inputFFUPartitionPicture.refresh()
                $partitionPic = "X:\Windows\System32\PartitionPics\Win10UEFI.png"
                # $partitionPic = "C:\PSScript\FFU\ICOs\Win10UEFI.png"
                do_InputPicture -file $partitionPic}
    "Partition UEFI FFU (Larger Drives)"{
                $ffuSystemLabel.Visible = $True
                $ffuSystemTextbox.Visible = $True
                $ffuMSRLabel.Visible = $True
                $ffuMSRTextbox.Visible = $True
                $ffuWindowsLabel.Visible = $True
                $ffuWindowsTextbox.Visible = $True
                #---------------------------------
                $MbrSystemLabel.Visible = $False
                $systemTextbox.Visible = $False
                $MbrWindowsLabel.Visible = $False
                $windowsTextbox.Visible = $False
                $MbrRecoveryLabel.Visible = $False
                $recoveryTextbox.Visible = $False
                $gptSystemLabel.Visible = $False
                $systemGPTTextbox.Visible = $False
                $gptMSRLabel.Visible = $False
                $gptMSRTextbox.Visible = $False
                $gptWindowsLabel.Visible = $False
                $gptWindowsTextbox.Visible = $False
                $gptRecoveryLabel.Visible = $False
                $gptRecoveryTextbox.Visible = $False
                $radioButtonFour.Checked = $False
                $radioButtonFive.Checked = $False
                $inputFFUPartitionPicture.Visible = $false
                $inputFFUPartitionPicture.refresh()
                $partitionPic = "X:\Windows\System32\PartitionPics\FFU.png"
                # $partitionPic = "C:\PSScript\FFU\ICOs\FFU.png"
                do_InputPicture -file $partitionPic}
    "Do no change Partition Configuration"{
                $ffuSystemLabel.Visible = $False
                $ffuSystemTextbox.Visible = $False
                $ffuMSRLabel.Visible = $False
                $ffuMSRTextbox.Visible = $False
                $ffuWindowsLabel.Visible = $False
                $ffuWindowsTextbox.Visible = $False
                #---------------------------------
                $MbrSystemLabel.Visible = $False
                $systemTextbox.Visible = $False
                $MbrWindowsLabel.Visible = $False
                $windowsTextbox.Visible = $False
                $MbrRecoveryLabel.Visible = $False
                $recoveryTextbox.Visible = $False
                $gptSystemLabel.Visible = $False
                $systemGPTTextbox.Visible = $False
                $gptMSRLabel.Visible = $False
                $gptMSRTextbox.Visible = $False
                $gptWindowsLabel.Visible = $False
                $gptWindowsTextbox.Visible = $False
                $gptRecoveryLabel.Visible = $False
                $gptRecoveryTextbox.Visible = $False
                $inputPicture.Visible = $False
                $inputPicture.refresh()
                $radioButtonOne.Checked = $False
                $radioButtonTwo.Checked = $False
                $radioButtonThree.Checked = $False
                $inputFFUPartitionPicture.Visible = $false
                $inputFFUPartitionPicture.refresh()}
    "Change Partition Configuration - Destination Computer has larger drive"{
                $ffuSystemLabel.Visible = $False
                $ffuSystemTextbox.Visible = $False
                $ffuMSRLabel.Visible = $False
                $ffuMSRTextbox.Visible = $False
                $ffuWindowsLabel.Visible = $False
                $ffuWindowsTextbox.Visible = $False
                #---------------------------------
                $MbrSystemLabel.Visible = $False
                $systemTextbox.Visible = $False
                $MbrWindowsLabel.Visible = $False
                $windowsTextbox.Visible = $False
                $MbrRecoveryLabel.Visible = $False
                $recoveryTextbox.Visible = $False
                $gptSystemLabel.Visible = $False
                $systemGPTTextbox.Visible = $False
                $gptMSRLabel.Visible = $False
                $gptMSRTextbox.Visible = $False
                $gptWindowsLabel.Visible = $False
                $gptWindowsTextbox.Visible = $False
                $gptRecoveryLabel.Visible = $False
                $gptRecoveryTextbox.Visible = $False
                $radioButtonOne.Checked = $False
                $radioButtonTwo.Checked = $False
                $radioButtonThree.Checked = $False
                $inputPicture.Visible = $False
                $inputPicture.refresh()
                $partitionPic = "X:\Windows\System32\PartitionPics\FFULargerDrivePartition.PNG"
                # $partitionPic = "C:\PSScript\FFU\ICOs\FFULargerDrivePartition.PNG"
                do_InputFFUPicture -file $partitionPic}
    } 
}

# -------------| Get DiskPartFile created |--------------------
Function do_PartitionDrive {
If ($radioButtonOne.Checked){
$Script:partitionDrive = "ONE"
$Script:commandPartDrive = @"
select disk 0
clean
create partition primary size="$($systemTextbox.Text)"
format quick fs=ntfs label="System"
assign letter="S"
active
create partition primary
shrink minimum="$($recoveryTextbox.Text)"
format quick fs=ntfs label="Windows"
assign letter="W"
create partition primary
format quick fs=ntfs label="Recovery"
assign letter="R"
set id=27
list volume
exit
"@
}
ElseIf($radioButtonTwo.Checked){
$Script:partitionDrive = "TWO"
$Script:commandPartDrive = @"
select disk 0
clean
convert gpt
create partition efi size="$($systemGPTTextbox.Text)"
format quick fs=fat32 label="System"
assign letter="S"
create partition msr size="$($gptMSRTextbox.Text)"
create partition primary
shrink minimum="$($gptRecoveryTextbox.Text)"
format quick fs=ntfs label="Windows"
assign letter="W"
create partition primary
format quick fs=ntfs label="Recovery"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
list volume
exit
"@
}
ElseIf($radioButtonThree.Checked){
$Script:partitionDrive = "THREE"
$Script:commandPartDrive = @"
select disk 0
clean
convert gpt
create partition efi size="$($ffuSystemTextbox.Text)"
format quick fs=fat32 label="System"
assign letter="S"
create partition msr size="$($ffuMSRTextbox.Text)"
create partition primary
format quick fs=ntfs label="Windows"
assign letter="W"
create partition primary
list volume
exit
"@
}
ElseIf($radioButtonFour.Checked){
$Script:partitionDrive = "FOUR"
# Do Nothing
}

ElseIf($radioButtonFive.Checked){
$Script:partitionDrive = "FIVE"
$Script:commandPartDrive = @"
select disk 0
select partition 3
assign letter="W"
shrink minimum=500
extend
shrink minimum=500
create partition primary
format quick fs=ntfs label="Recovery"
assign letter="R"
set id="de94bba4-06d1-4d40-a16a-bfd50179d6ac"
gpt attributes=0x8000000000000001
list volume
exit
"@
}
Else {
    [System.Windows.Forms.MessageBox]::Show("Please select Select BIOS/UEFI Partitions option!")
    return
    $Script:partitionDrive = ""
}

# Write the file for DiskPart command prior to apply image
$commandPartDrive | Out-File X:\Windows\system32\PartitionDrive.txt -Force
# $commandPartDrive | Out-File "$($env:TEMP)\PartitionDrive.txt" -Force
}

# Function to Apply WIM Image
# =================================================================

Function do_AddFileForDismApplyWIM{

$wimFileCollection = $strWimFilePath

$richBoxDismApply.Clear() 
    $fileName = ($comboBoxDismApply.SelectedItem.ToString() -replace ".wim", "")
    $fileNewName = $fileName + "_Comment.txt"
    $wimFileDescription = (Get-ChildItem -Path $wimFileCollection -Recurse -Force | 
    ? -FilterScript{$_.Extension -match ".txt" -and $_.Name -eq "$fileNewName" })
        
    # [System.Windows.Forms.MessageBox]::Show("$($wimFileDescription)")
    If("$($wimFileDescription)") {
        $message = (Get-Content -Path "$wimFileCollection\$wimFileDescription")
        $richBoxDismApply.AppendText($message)
        Clear-Variable message
    }
    
    $deleteButtonSelectDismFile.Visible = $True
    $deleteButtonSelectDismFile.Refresh()
    $objForm.Refresh()      
}

Function do_DeleteWimImageFile{
$confirmDeleteFile = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete file: $($comboBoxDismApply.SelectedItem)" + " ?" , "Confirm Action!" , 4)
If ($confirmDeleteFile -eq "YES") {
    $strFileToDelete = $strWimFilePath + "\$($comboBoxDismApply.SelectedItem)"
    If(Test-Path -Path $strFileToDelete) {
        # [System.Windows.Forms.MessageBox]::Show("File: $strFileToDelete deleted")
        Remove-Item -Path $strFileToDelete -Force
    }
    $fileCommentTempName = ("$($comboBoxDismApply.SelectedItem)" -replace ".wim", "")
    $imageComment = $fileCommentTempName + "_Comment.txt"
    $strFileCommentToDelete = $strWimFilePath + "\$imageComment"
    If(Test-Path -Path $strFileCommentToDelete) {
        # [System.Windows.Forms.MessageBox]::Show("File: $strFileCommentToDelete deleted")
        Remove-Item -Path $strFileCommentToDelete -Force
    }
    do_RunRefreshForm
}
else{
    [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
 }
}

Function do_ApplySelectedWimImage($winImage){
New-Item -Path $env:TEMP -Name applyWimImage.ps1 -ItemType File -Force | Out-Null
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Formatting Hard Drive - Creating Windows Partitions' -ForegroundColor Green"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "(Get-Content X:\Windows\system32\PartitionDrive.txt) | DiskPart"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Start-Sleep -Seconds 3"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Please wait ... Applying selected image file to Windows partition' -ForegroundColor Green"
# Add-Content -Path $env:TEMP\applyWimImage.ps1 "X:\Windows\system32\GImageX\dism.exe /Apply-Image /ImageFile:$winImage /Index:1 /ApplyDir:W:"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "X:\Windows\system32\dism.exe /Apply-Image /ImageFile:$winImage /Index:1 /ApplyDir:W:"
Add-Content -Path $env:TEMP\applyWimImage.ps1 'If($?){'
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Start-Sleep -Seconds 3"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Applying bcdboot tool to make bootable partition' -ForegroundColor Green"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "bcdboot W:\Windows /s S:"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Finish applying image ... (Done)!' -ForegroundColor Green"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Start-Sleep -Seconds 3"

    If($checkBoxRecovery.Checked){
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Configure Recovery Partition' -ForegroundColor Green"
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "md R:\Recovery\WindowsRE"
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "xcopy /h W:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE\"
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "W:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WindowsRE /Target W:\Windows"
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "Write-Host 'Finish configuring Recovery Partition ...!' -ForegroundColor Green"
        Add-Content -Path $env:TEMP\applyWimImage.ps1 "Start-Sleep -Seconds 3"
    }

Add-Content -Path $env:TEMP\applyWimImage.ps1 "}"    
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Else{"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "[System.Windows.Forms.MessageBox]::Show('Error encountered while applying image!!!')"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "}"
Add-Content -Path $env:TEMP\applyWimImage.ps1 "Start-Sleep -Seconds 2"

Function do_StartPSScript{
$commandStartApplyPSScript = @"
Start-Process PowerShell -ArgumentList " -ExecutionPolicy Bypass -File $($env:TEMP)\applyWimImage.ps1" 
"@
Invoke-Expression $commandStartApplyPSScript
 }
   do_StartPSScript
}

Function do_ApplyWim{

    do_PartitionDrive | Out-Null
    Start-Sleep -Seconds 2

 If ([string]::IsNullOrEmpty($Script:partitionDrive)){
    return # No partition option selected!!!
 }
 Else{
    
    If($comboBoxDismApply.SelectedItem -eq $null){
        [System.Windows.Forms.MessageBox]::Show("Please select an Image to be applied!")
    Return
    }

    $confirmApply = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to apply: $($comboBoxDismApply.SelectedItem)" + " image?" , "Confirm Action!" , 4)
    If ($confirmApply -eq "YES") {  
        If($radioButtonOne.Checked -or $radioButtonTwo.Checked -or $radioButtonThree.Checked){
            do_StartLabels("WIM-APPLY")
            do_ApplySelectedWimImage -winImage "$strWimFilePath\$($comboBoxDismApply.SelectedItem)" | Out-Null
            # [System.Windows.Forms.MessageBox]::Show("$strWimFilePath\$($comboBoxDismApply.SelectedItem)")
        }
        else{
            [System.Windows.Forms.MessageBox]::Show("You have not selected BIOS/UEFI Partitions option!")
            return
        }
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }  
}

Function do_StopApplyImage{
[int]$Script:processApplyImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "dism"} |Select -Property $_.Id).Id

 If ($Script:processApplyImageID){
    $confirmStopApplyImage = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to stop the apply image process?" , "Confirm Action!" , 4)
    If ($confirmStopApplyImage -eq "YES") {
        Stop-Process -id $Script:processApplyImageID -Force
        do_StartLabels("END-WIMAPPLY")
        do_RefreshSomeControls
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }
Else{
    do_StartLabels("END-WIMAPPLY")
    do_RefreshSomeControls
 }
}

# Functions Apply Image - FFU DISM
# =================================================================

Function do_DeleteFFUImageFile{
$confirmDeleteFile = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete file: $($comboBoxFFUApply.SelectedItem)" + " ?" , "Confirm Action!" , 4)
If ($confirmDeleteFile -eq "YES") {
    $strFileToDelete = $strFFUFilePath + "\$($comboBoxFFUApply.SelectedItem)"
    If(Test-Path -Path $strFileToDelete) {
        # [System.Windows.Forms.MessageBox]::Show("File: $strFileToDelete deleted")
        Remove-Item -Path $strFileToDelete -Force
    }
    $fileCommentTempName = ("$($comboBoxFFUApply.SelectedItem)" -replace ".ffu", "")
    $imageComment = $fileCommentTempName + "_Comment.txt"
    $strFileCommentToDelete = $strFFUFilePath + "\$imageComment"
    If(Test-Path -Path $strFileCommentToDelete) {
        # [System.Windows.Forms.MessageBox]::Show("File: $strFileCommentToDelete deleted")
        Remove-Item -Path $strFileCommentToDelete -Force
    }
    do_RunRefreshForm
}
else{
    [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
 }
}

Function do_AddFileForApplyFFU{

$ffuFileCollection = $strFFUFilePath

$richBoxFFUApply.Clear() 
    $fileName = ($comboBoxFFUApply.SelectedItem.ToString() -replace ".ffu", "")
    $fileNewName = $fileName + "_Comment.txt"
    $ffuFileDescription = (Get-ChildItem -Path $ffuFileCollection -Recurse -Force | 
    ? -FilterScript{$_.Extension -match ".txt" -and $_.Name -eq "$fileNewName" })
        
    # [System.Windows.Forms.MessageBox]::Show("$($ffuFileDescription)")
    If("$($ffuFileDescription)") {
        $message = (Get-Content -Path "$ffuFileCollection\$ffuFileDescription")
        $richBoxFFUApply.AppendText($message)
        Clear-Variable message
    }
    
    $deleteButtonSelectFFUFile.Visible = $True
    $deleteButtonSelectFFUFile.Refresh()
    $objForm.Refresh()      
}

Function do_ApplySelectedFFUImage($ffuImage,$ffuDisk){
New-Item -Path $env:TEMP -Name applyFfuImage.ps1 -ItemType File -Force | Out-Null
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Write-Host 'Please wait ... Applying selected FFU Image file to the Disk Drive' -ForegroundColor Green"
# Add-Content -Path $env:TEMP\applyFfuImage.ps1 "X:\Windows\system32\GImageX\dism.exe /Apply-ffu /ImageFile:$ffuImage /ApplyDrive:\\.\PhysicalDrive$ffuDisk"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "X:\Windows\system32\dism.exe /Apply-ffu /ImageFile:$ffuImage /ApplyDrive:\\.\PhysicalDrive$ffuDisk"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 'If($?){'
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Start-Sleep -Seconds 2"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Write-Host 'Finish applying image ... (Done)!' -ForegroundColor Green"

    If($radioButtonFour.Checked){
        # Do Nothing
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Start-Sleep -Seconds 1"
    }

    If($radioButtonFive.Checked){
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Write-Host 'DISM FFU Disk Imaging - Preparing larger Hard Drive' -ForegroundColor Green"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "(Get-Content X:\Windows\system32\PartitionDrive.txt) | DiskPart"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Start-Sleep -Seconds 2"
    }    
    If($checkBoxFFURecovery.Checked){
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Write-Host 'Configure Recovery Partition' -ForegroundColor Green"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "md R:\Recovery\WindowsRE"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "xcopy /h W:\Windows\System32\Recovery\Winre.wim R:\Recovery\WindowsRE\"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "W:\Windows\System32\Reagentc /Setreimage /Path R:\Recovery\WindowsRE /Target W:\Windows"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Write-Host 'Finish configuring Recovery Partition ...!' -ForegroundColor Green"
        Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Start-Sleep -Seconds 3"
    }
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "}"    
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Else{"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "[System.Windows.Forms.MessageBox]::Show('Error encountered while applying image!!!')"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "}"
Add-Content -Path $env:TEMP\applyFfuImage.ps1 "Start-Sleep -Seconds 2"

Function do_StartPSScript{
$commandStartApplyPSScript = @"
Start-Process PowerShell -ArgumentList " -ExecutionPolicy Bypass -File $($env:TEMP)\applyFfuImage.ps1"   
"@
Invoke-Expression $commandStartApplyPSScript
 }
  do_StartPSScript
}

Function do_ApplyFFU{

    do_PartitionDrive | Out-Null
    Start-Sleep -Seconds 1

 If ([string]::IsNullOrEmpty($Script:partitionDrive)){
    return # No partition option selected!!!
 }
 Else{

    If($applyDropDownFfu.SelectedItem -eq $null){
        [System.Windows.Forms.MessageBox]::Show("Please select the Disk Drive for imaging!")
    Return
    }

    If($comboBoxFFUApply.SelectedItem -eq $null){
        [System.Windows.Forms.MessageBox]::Show("Please select an Image to be applied!")
    Return
    }

    $confirmApply = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to apply: $($comboBoxFFUApply.SelectedItem)" + " image?" , "Confirm Action!" , 4)
    If ($confirmApply -eq "YES") {  
        If($radioButtonFour.Checked -or $radioButtonFive.Checked){
            do_StartLabels("FFU-APPLY")
            do_ApplySelectedFFUImage -ffuImage "$strFFUFilePath\$($comboBoxFFUApply.SelectedItem)" -ffuDisk $($applyDropDownFfu.SelectedItem) | Out-Null
            #[System.Windows.Forms.MessageBox]::Show("$strFFUFilePath\$($comboBoxFFUApply.SelectedItem) and $($applyDropDownFfu.SelectedItem)")
        }
        else{
            [System.Windows.Forms.MessageBox]::Show("You have not selected BIOS/UEFI Partitions option!")
            return
        }
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }
}

Function do_StopApplyImage{
[int]$Script:processApplyImageID = (Get-Process | Where -FilterScript {$_.ProcessName -eq "dism"} |Select -Property $_.Id).Id

 If ($Script:processApplyImageID){
    $confirmStopApplyImage = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to stop the apply image process?" , "Confirm Action!" , 4)
    If ($confirmStopApplyImage -eq "YES") {
        Stop-Process -id $Script:processApplyImageID -Force
        do_StartLabels("END-FFUAPPLY")
        do_RefreshSomeControls
    }
    else{
        [System.Windows.Forms.MessageBox]::Show("You have canceled this action.")
    }
 }
Else{
    do_StartLabels("END-FFUAPPLY")
    do_RefreshSomeControls
 }
}

# =================================================================
# Create a Form
# =================================================================
# X:\Windows\System32\ICOs
# C:\PSScript\FFU\ICOs
# ---------------------------------------------------------------

$imageOne = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\AI.png")
$imageDismWimFile = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\DismWimImage.png")
$imageDismFFUFile = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\DismFFUImage.png")

#$imageOne = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\AI.png")
#$imageDismWimFile = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\DismWimImage.png")
#$imageDismFFUFile = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\DismFFUImage.png")


$objForm = New-Object System.Windows.Forms.Form
$objForm.Text = "www.AlexComputerBubble - Capture And Apply Windows Images (WIM & FFU)"
$objForm.Size = New-Object System.Drawing.Size(1250,600)
$objForm.StartPosition = "CenterScreen"
$objForm.KeyPreview = $True

# Create a ToolTip
$tooltipinfo = New-Object 'System.Windows.Forms.ToolTip'

# Form Tabs
# =================================================================
# Create the tabcontrol
$tabcontrol = New-Object windows.Forms.TabControl
$tabpage_One = New-Object windows.Forms.TabPage
$tabpage_Two = New-Object windows.Forms.TabPage
$tabpage_Three = New-Object windows.Forms.TabPage

$tabcontrol.Font ="Calibri, 10pt style=Bold"
$tabcontrol.Anchor = 'Top, Bottom, Left, Right'
$tabcontrol.ItemSize = '100,25'
$tabcontrol.Padding = '15,5'
$tabcontrol.Location = '20, 20'
$tabcontrol.width = 1200
$tabcontrol.Height = 530

# Tab One
# ================================================================
$tabpage_One.Text = "Computer Info"
$tabpage_One.Location = '20, 15'
$tabpage_One.Padding ='3,3,3,3'
$tabpage_One.Size = '1200, 530'
$tabpage_One.BackColor = "White"
$tabpage_One.BackgroundImageLayout = "None"
$tabpage_One.TabIndex = 0

# RichTextBox for Pc Info
$pcInfoTextBox = New-Object System.Windows.Forms.RichTextBox
$pcInfoTextBox.location = New-Object System.Drawing.Size(20,20) 
$pcInfoTextBox.Size = New-Object System.Drawing.Size(760,130)
$pcInfoTextBox.Font ="Calibri, 8pt"
$pcInfoTextBox.AppendText("Computer Name:`t" + $env:COMPUTERNAME)
$pcInfoTextBox.AppendText("`nManufacturer:`t" + (Get-WmiObject -classname win32_computersystem).manufacturer)
$pcInfoTextBox.AppendText("`nModel Number:`t" + (Get-WmiObject -classname win32_computersystem).Model)
$pcInfoTextBox.AppendText("`nSerial:`t`t" + (Get-WmiObject -classname win32_bios).SerialNumber)
$pcInfoTextBox.AppendText("`nProcessor Name:`t" + (Get-WmiObject -Class Win32_Processor).Name)
$pcInfoTextBox.AppendText("`nNIC:`t`t" + (Get-wmiObject -classname win32_networkadapterconfiguration|Where {$_.DHCPEnabled -match "True" -and $_.IpAddress -ne $null -and $_.DefaultIPGateway -notlike ""}|Select-Object -property Description).Description)
$pcInfoTextBox.AppendText("`nMAC Address:`t"+ (Get-wmiObject -classname win32_networkadapterconfiguration|Where {$_.DHCPEnabled -match "True" -and $_.DefaultIPGateway -notlike ""}|Select-Object -property MACAddress).MACAddress)
$pcInfoTextBox.AppendText("`nIP Address:`t" + (Get-wmiObject -classname win32_networkadapterconfiguration|Where {$_.DHCPEnabled -match "True" -and $_.DefaultIPGateway -notlike ""}|Select-Object -property IpAddress).IpAddress)
$pcInfoTextBox.Visible=$True
$pcInfoTextBox.readonly = $true

# Data Grid
$partitionDriveGrid = New-Object System.Windows.Forms.DataGridView
$partitionDriveGrid.Name = "ViewPartitions"
$partitionDriveGrid.Font ="Calibri, 8pt"
$partitionDriveGrid.Location = New-Object Drawing.Point 20,170
$partitionDriveGrid.Size = New-Object Drawing.Point 760,150
$partitionDriveGrid.AutoSizeColumnsMode = 'AllCells'  # 'Fill'
$partitionDriveGrid.MultiSelect = $false
$partitionDriveGrid.RowHeadersVisible = $false
$partitionDriveGrid.allowusertoordercolumns = $true
$partitionDriveGrid.ColumnHeadersVisible = $true

# Label Folder Images
$labelTreeViewImages = New-Object System.Windows.Forms.Label
$labelTreeViewImages.Location = New-Object System.Drawing.Size(20,340)
$labelTreeViewImages.Size = New-Object System.Drawing.Size(260,20)
$labelTreeViewImages.BackColor = "Transparent"
$labelTreeViewImages.Text = "External USB Images Folder:"

# TreeView Folder Images
$treeView1 = New-Object System.Windows.Forms.TreeView
$treeView1.Location = New-Object System.Drawing.Size(20,370)
$treeView1.Size = New-Object System.Drawing.Size(760,110)
$treeView1.Name = "treeImageFolderView" 
$treeView1.Font = "Calibri, 10pt" 
$treeView1.CheckBoxes = $true

# Button Delete image files
$buttonDelImgFile = New-Object System.Windows.Forms.Button
$buttonDelImgFile.Location = New-Object System.Drawing.Size(640,340)
$buttonDelImgFile.Size = New-Object System.Drawing.Size(120,20)
$buttonDelImgFile.Font = "Calibri, 8pt"
$buttonDelImgFile.Text = “Delete”
$buttonDelImgFile.TextAlign = "middleCenter"
$buttonDelImgFile.TabIndex = 1
$tooltipinfo.SetToolTip($buttonDelImgFile, "Click this button to delete checked image files")
$buttonDelImgFile.Add_Click({do_DeleteImageFiles})

# PictureBox for main page
$picBoxOne = New-Object System.Windows.Forms.PictureBox
$picBoxOne.Width = $imageOne.Size.Width
$picBoxOne.Height = $imageOne.Size.Height
$picBoxOne.Image = $imageOne
$picBoxOne.Location = New-Object Drawing.Point 810,15
$picBoxOne.BackColor = "Transparent"

# Button Shutdown
$shutdownButton = New-Object System.Windows.Forms.Button
$shutdownButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Shutdown.ico")
#$shutdownButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Shutdown.ico")
$shutdownButton.ImageAlign = "TopCenter"
$shutdownButton.BackColor = "ButtonFace"
$shutdownButton.UseVisualStyleBackColor = $True
$shutdownButton.Location = New-Object System.Drawing.Size(1060,385)
$shutdownButton.Size = New-Object System.Drawing.Size(95,64)
$shutdownButton.Font = "Calibri, 8pt"
$shutdownButton.TabIndex = 3
$shutdownButton.Text = “Shutdown”
$shutdownButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($shutdownButton, "Shutdown Computer")
$shutdownButton.Add_Click({do_Shutdown})

# Button Restart
$restartButton = New-Object System.Windows.Forms.Button
$restartButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Restart.ico")
#$restartButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Restart.ico")
$restartButton.ImageAlign = "TopCenter"
$restartButton.BackColor = "ButtonFace"
$restartButton.UseVisualStyleBackColor = $True
$restartButton.Location = New-Object System.Drawing.Size(950,385)
$restartButton.Size = New-Object System.Drawing.Size(95,64)
$restartButton.Font = "Calibri, 8pt"
$restartButton.TabIndex = 2
$restartButton.Text = “Restart”
$restartButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($restartButton, "Restart Computer")
$restartButton.Add_Click({do_Restart})

# Button Refresh
$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Refresh.ico")
#$refreshButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Refresh.ico")
$refreshButton.ImageAlign = "TopCenter"
$refreshButton.BackColor = "ButtonFace"
$refreshButton.UseVisualStyleBackColor = $True
$refreshButton.Location = New-Object System.Drawing.Size(840,385)
$refreshButton.Size = New-Object System.Drawing.Size(95,64)
$refreshButton.Font = "Calibri, 8pt"
$refreshButton.TabIndex = 1
$refreshButton.Text = “Refresh”
$refreshButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($refreshButton, "Refresh")
$refreshButton.Add_Click({do_RunRefreshForm})

# Tab Two
# ================================================================
$tabpage_Two.Text = "Create Image"
$tabpage_Two.Location = '20, 15'
$tabpage_Two.Padding ='3,3,3,3'
$tabpage_Two.Size = '1200, 530'
$tabpage_Two.BackColor = "white"
$tabpage_Two.TabIndex = 1

# Section for two tabs under Tab Two
# Create the tabControlCreateImages with two additional tabs
# ----------------------------------------------------------------
$tabControlCreateImages = New-Object windows.Forms.TabControl
$tabPageDismCreateImage = New-Object windows.Forms.TabPage
$tabPageFFUCreateImage = New-Object windows.Forms.TabPage

$tabControlCreateImages.Font ="Calibri, 10pt style=Bold"
$tabControlCreateImages.BackColor = "Transparent"
$tabControlCreateImages.Anchor = 'Top, Bottom, Left, Right'
$tabControlCreateImages.ItemSize = '100,25'
$tabControlCreateImages.Padding = '15,5'
$tabControlCreateImages.Location = '20, 20'
$tabControlCreateImages.width = 780
$tabControlCreateImages.Height = 470

# Capture section
# ----------------------------------------------------------------
# Dism Tab Control
# ================================================================
$tabPageDismCreateImage.Text = "DISM - WIM Create Image"
$tabPageDismCreateImage.Location = '20, 15'
$tabPageDismCreateImage.Padding ='3,3,3,3'
$tabPageDismCreateImage.Size = '780, 425'
$tabPageDismCreateImage.BackColor = "White"
$tabPageDismCreateImage.BackgroundImageLayout = "None"
$tabPageDismCreateImage.TabIndex = 0

# Label Image .Wim Type File Name
$labelWriteDismImageName = New-Object System.Windows.Forms.Label
$labelWriteDismImageName.Location = New-Object System.Drawing.Point(20, 40)
$labelWriteDismImageName.Size = New-Object System.Drawing.Size(150, 25)
$labelWriteDismImageName.Font ="Calibri, 8pt"
$labelWriteDismImageName.Text = "Type Image Name:"

# Letter Image Name Text Box
$textBoxDismImageName = New-Object System.Windows.Forms.TextBox
$textBoxDismImageName.Location = New-Object System.Drawing.Size(170,40)
$textBoxDismImageName.Size = New-Object System.Drawing.Size(190,25)
$textBoxDismImageName.Font ="Calibri, 10pt"
$textBoxDismImageName.TabIndex = 1

# RichBox for description of captured wim files
$richBoxDismCapture = New-Object System.Windows.Forms.RichTextBox
$richBoxDismCapture.location = New-Object System.Drawing.Size(20,100) 
$richBoxDismCapture.Size = New-Object System.Drawing.Size(340,150) 
$richBoxDismCapture.font = "Calibri, 8pt"
$richBoxDismCapture.Visible=$True
$richBoxDismCapture.wordwrap = $true
$richBoxDismCapture.multiline = $true
$richBoxDismCapture.readonly = $false
$richBoxDismCapture.scrollbars = "Vertical"
$richBoxDismCapture.TabIndex = 2

# Label Info about Windows Partition
$labelPartitionDismToCapture = New-Object System.Windows.Forms.Label
$labelPartitionDismToCapture.Font = "Calibri, 9pt, style=Bold"
$labelPartitionDismToCapture.ForeColor = "Blue"
$labelPartitionDismToCapture.Location = New-Object System.Drawing.Point(10, 290)
$labelPartitionDismToCapture.Size = New-Object System.Drawing.Size(300, 25)
$labelPartitionDismToCapture.Text = ""
$labelPartitionDismToCapture.TextAlign = "MiddleCenter"

# Label Info about Windows Firmware
$labelDismCaptureFirmwareType = New-Object System.Windows.Forms.Label
$labelDismCaptureFirmwareType.Font = "Calibri, 9pt, style=Bold"
$labelDismCaptureFirmwareType.ForeColor = "Blue"
$labelDismCaptureFirmwareType.Location = New-Object System.Drawing.Point(10, 335)
$labelDismCaptureFirmwareType.Size = New-Object System.Drawing.Size(300, 25)
$labelDismCaptureFirmwareType.Text = ""
$labelDismCaptureFirmwareType.TextAlign = "MiddleCenter"
# PictureBox Dism-Wim - Create
$picBoxWimCreate = New-Object System.Windows.Forms.PictureBox
$picBoxWimCreate.Width = $imageDismWimFile.Size.Width
$picBoxWimCreate.Height = $imageDismWimFile.Size.Height
$picBoxWimCreate.Image = $imageDismWimFile
$picBoxWimCreate.Location = New-Object Drawing.Point 510,70
$picBoxWimCreate.BackColor = "Transparent"

# Button stop imaging Capture process
$stopButtonDismCaptureProcess = New-Object System.Windows.Forms.Button
$stopButtonDismCaptureProcess.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Stop.ico")
#$stopButtonDismCaptureProcess.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Stop.ico")
$stopButtonDismCaptureProcess.ImageAlign = "TopCenter"
$stopButtonDismCaptureProcess.BackColor = "ButtonFace"
$stopButtonDismCaptureProcess.UseVisualStyleBackColor = $True
$stopButtonDismCaptureProcess.Location = New-Object System.Drawing.Size(420,280)
$stopButtonDismCaptureProcess.Size = New-Object System.Drawing.Size(85,64)
$stopButtonDismCaptureProcess.Font = "Calibri, 8pt"
$stopButtonDismCaptureProcess.TabIndex = 4
$stopButtonDismCaptureProcess.Text = “Imaging”
$stopButtonDismCaptureProcess.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($stopButtonDismCaptureProcess, "Stops the current imaging capture process.")
$stopButtonDismCaptureProcess.Visible = $False
$stopButtonDismCaptureProcess.Add_Click({do_StopCreateWimImaging})

# Button Create Image
$createImgButton = New-Object System.Windows.Forms.Button
$createImgButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\CreateImage.ico")
#$createImgButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\CreateImage.ico")
$createImgButton.ImageAlign = "TopCenter"
$createImgButton.BackColor = "ButtonFace"
$createImgButton.UseVisualStyleBackColor = $True
$createImgButton.Location = New-Object System.Drawing.Size(520,280)
$createImgButton.Size = New-Object System.Drawing.Size(85,64)
$createImgButton.Font = "Calibri, 8pt"
$createImgButton.TabIndex = 3
$createImgButton.Text = “Create”
$createImgButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($createImgButton, "Create or capture an image of this computer")
$createImgButton.Add_Click({do_CheckInputAndCaptureWim})

# Adding controls to the Dism tab control
$tabPageDismCreateImage.Controls.Add($labelWriteDismImageName)
$tabPageDismCreateImage.Controls.Add($textBoxDismImageName)
$tabPageDismCreateImage.Controls.Add($richBoxDismCapture)
$tabPageDismCreateImage.Controls.Add($picBoxWimCreate)
$tabPageDismCreateImage.Controls.Add($labelPartitionDismToCapture)
$tabPageDismCreateImage.Controls.Add($labelPartitionDismToCapture)
$tabPageDismCreateImage.Controls.Add($labelDismCaptureFirmwareType)
$tabPageDismCreateImage.Controls.Add($createImgButton)

# Capture section
# ----------------------------------------------------------------
# FFU Tab Control
# ================================================================
$tabPageFFUCreateImage.Text = "DISM - FFU Create Image"
$tabPageFFUCreateImage.Location = '20, 15'
$tabPageFFUCreateImage.Padding ='3,3,3,3'
$tabPageFFUCreateImage.Size = '780, 425'
$tabPageFFUCreateImage.BackColor = "white"
$tabPageFFUCreateImage.BackgroundImageLayout = "None"
$tabPageFFUCreateImage.TabIndex = 0

# Label select FFU Drive
$labelForFfuDrive = New-Object System.Windows.Forms.Label
$labelForFfuDrive.Location = New-Object System.Drawing.Point(20, 20)
$labelForFfuDrive.Size = New-Object System.Drawing.Size(120, 25)
$labelForFfuDrive.Font ="Calibri, 8pt"
$labelForFfuDrive.Text = "Select Drive:"

$diskFfuDrive = get-ciminstance win32_diskdrive | 
select @{Label="Drive";Expression={$_.index}},InterfaceType,@{Label="Size(GB)";Expression={$_.size/1GB}},Caption, Partitions, Status
   
$driveFfuCollection = ($diskFfuDrive | select drive).drive
     
# Combo Box FFU Drive  
$DropDownFfu = new-object System.Windows.Forms.ComboBox
$DropDownFfu.Location = new-object System.Drawing.Size(170,20)
$DropDownFfu.Size = new-object System.Drawing.Size(60,25)
$DropDownFfu.DropDownStyle = 2
$DropDownFfu.TabIndex = 1    
ForEach ($Drive in $driveFfuCollection) {[void]$DropDownFfu.Items.Add($Drive)}
    
# Label Image .Wim Type File Name
$labelWriteFFUImageName = New-Object System.Windows.Forms.Label
$labelWriteFFUImageName.Location = New-Object System.Drawing.Point(20, 60)
$labelWriteFFUImageName.Size = New-Object System.Drawing.Size(150, 25)
$labelWriteFFUImageName.Font ="Calibri, 8pt"
$labelWriteFFUImageName.Text = "Type Image Name:"

# Letter Image Name Text Box
$textBoxFFUImageName = New-Object System.Windows.Forms.TextBox
$textBoxFFUImageName.Location = New-Object System.Drawing.Size(170,60)
$textBoxFFUImageName.Size = New-Object System.Drawing.Size(190,25)
$textBoxFFUImageName.Font ="Calibri, 10pt"
$textBoxFFUImageName.TabIndex = 2

# RichBox for description of captured wim files
$richBoxFFUCapture = New-Object System.Windows.Forms.RichTextBox
$richBoxFFUCapture.location = New-Object System.Drawing.Size(20,120) 
$richBoxFFUCapture.Size = New-Object System.Drawing.Size(340,150) 
$richBoxFFUCapture.font = "Calibri, 8pt"
$richBoxFFUCapture.Visible=$True
$richBoxFFUCapture.wordwrap = $true
$richBoxFFUCapture.multiline = $true
$richBoxFFUCapture.readonly = $false
$richBoxFFUCapture.scrollbars = "Vertical"
$richBoxFFUCapture.TabIndex = 3

# Label Info about Windows Partition
$labelPartitionFFUToCapture = New-Object System.Windows.Forms.Label
$labelPartitionFFUToCapture.Font = "Calibri, 8pt, style=Bold"
$labelPartitionFFUToCapture.ForeColor = "Blue"
$labelPartitionFFUToCapture.Location = New-Object System.Drawing.Point(10, 300)
$labelPartitionFFUToCapture.Size = New-Object System.Drawing.Size(300, 25)
$labelPartitionFFUToCapture.Text = ""
$labelPartitionFFUToCapture.TextAlign = "MiddleCenter"

# Label Info about Windows Firmware
$labelFFUCaptureFirmwareType = New-Object System.Windows.Forms.Label
$labelFFUCaptureFirmwareType.Font = "Calibri, 9pt, style=Bold"
$labelFFUCaptureFirmwareType.ForeColor = "Blue"
$labelFFUCaptureFirmwareType.Location = New-Object System.Drawing.Point(10, 335)
$labelFFUCaptureFirmwareType.Size = New-Object System.Drawing.Size(300, 25)
$labelFFUCaptureFirmwareType.Text = ""
$labelFFUCaptureFirmwareType.TextAlign = "MiddleCenter"

# PictureBox Dism-FFU - Create
$picBoxFFUCreate = New-Object System.Windows.Forms.PictureBox
$picBoxFFUCreate.Width = $imageDismFFUFile.Size.Width
$picBoxFFUCreate.Height = $imageDismFFUFile.Size.Height
$picBoxFFUCreate.Image = $imageDismFFUFile
$picBoxFFUCreate.Location = New-Object Drawing.Point 510,70
$picBoxFFUCreate.BackColor = "Transparent"

# Button stop imaging Capture process
$stopButtonFFUCaptureProcess = New-Object System.Windows.Forms.Button
$stopButtonFFUCaptureProcess.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Stop.ico")
#$stopButtonFFUCaptureProcess.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Stop.ico")
$stopButtonFFUCaptureProcess.ImageAlign = "TopCenter"
$stopButtonFFUCaptureProcess.BackColor = "ButtonFace"
$stopButtonFFUCaptureProcess.UseVisualStyleBackColor = $True
$stopButtonFFUCaptureProcess.Location = New-Object System.Drawing.Size(420,280)
$stopButtonFFUCaptureProcess.Size = New-Object System.Drawing.Size(85,64)
$stopButtonFFUCaptureProcess.Font = "Calibri, 8pt"
$stopButtonFFUCaptureProcess.TabIndex = 5
$stopButtonFFUCaptureProcess.Text = “Imaging”
$stopButtonFFUCaptureProcess.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($stopButtonFFUCaptureProcess, "Stops the current imaging capture process.")
$stopButtonFFUCaptureProcess.Visible = $False
$stopButtonFFUCaptureProcess.Add_Click({do_StopCreateFfuImage})

# Button Create Image
$createFfuImageButton = New-Object System.Windows.Forms.Button
$createFfuImageButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\CreateImage.ico")
#$createFfuImageButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\CreateImage.ico")
$createFfuImageButton.ImageAlign = "TopCenter"
$createFfuImageButton.BackColor = "ButtonFace"
$createFfuImageButton.UseVisualStyleBackColor = $True
$createFfuImageButton.Location = New-Object System.Drawing.Size(520,280)
$createFfuImageButton.Size = New-Object System.Drawing.Size(85,64)
$createFfuImageButton.Font = "Calibri, 8pt"
$createFfuImageButton.TabIndex = 4
$createFfuImageButton.Text = “Create”
$createFfuImageButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($createFfuImageButton, "Create or capture an image of this computer")
$createFfuImageButton.Add_Click({do_CheckInputAndCaptureFfu})

# Adding controls to the FFU tab control
$tabPageFFUCreateImage.Controls.Add($labelForFfuDrive)
$tabPageFFUCreateImage.Controls.Add($DropDownFfu)
$tabPageFFUCreateImage.Controls.Add($labelWriteFFUImageName)
$tabPageFFUCreateImage.Controls.Add($textBoxFFUImageName)
$tabPageFFUCreateImage.Controls.Add($richBoxFFUCapture)
$tabPageFFUCreateImage.Controls.Add($picBoxFFUCreate)
$tabPageFFUCreateImage.Controls.Add($labelPartitionFFUToCapture)
$tabPageFFUCreateImage.Controls.Add($labelFFUCaptureFirmwareType)
$tabPageFFUCreateImage.Controls.Add($stopButtonFFUCaptureProcess)
$tabPageFFUCreateImage.Controls.Add($createFfuImageButton)
# ---------------------------------------------------------------
# PictureBox for main page
$picBoxTwo = New-Object System.Windows.Forms.PictureBox
$picBoxTwo.Width = $imageOne.Size.Width
$picBoxTwo.Height = $imageOne.Size.Height
$picBoxTwo.Image = $imageOne
$picBoxTwo.Location = New-Object Drawing.Point 810,15
$picBoxTwo.BackColor = "Transparent"

# Button Shutdown
$shutdownButtonCreateImg = New-Object System.Windows.Forms.Button
$shutdownButtonCreateImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Shutdown.ico")
#$shutdownButtonCreateImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Shutdown.ico")
$shutdownButtonCreateImg.ImageAlign = "TopCenter"
$shutdownButtonCreateImg.BackColor = "ButtonFace"
$shutdownButtonCreateImg.UseVisualStyleBackColor = $True
$shutdownButtonCreateImg.Location = New-Object System.Drawing.Size(1060,385)
$shutdownButtonCreateImg.Size = New-Object System.Drawing.Size(95,64)
$shutdownButtonCreateImg.Font = "Calibri, 8pt"
$shutdownButtonCreateImg.TabIndex = 1
$shutdownButtonCreateImg.Text = “Shutdown”
$shutdownButtonCreateImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($shutdownButtonCreateImg, "Shutdown Computer")
$shutdownButtonCreateImg.Add_Click({do_Shutdown})

# Button Restart
$restartButtonCreateImg = New-Object System.Windows.Forms.Button
$restartButtonCreateImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Restart.ico")
#$restartButtonCreateImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Restart.ico")
$restartButtonCreateImg.ImageAlign = "TopCenter"
$restartButtonCreateImg.BackColor = "ButtonFace"
$restartButtonCreateImg.UseVisualStyleBackColor = $True
$restartButtonCreateImg.Location = New-Object System.Drawing.Size(950,385)
$restartButtonCreateImg.Size = New-Object System.Drawing.Size(95,64)
$restartButtonCreateImg.Font = "Calibri, 8pt"
$restartButtonCreateImg.TabIndex = 1
$restartButtonCreateImg.Text = “Restart”
$restartButtonCreateImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($restartButtonCreateImg, "Restart Computer")
$restartButtonCreateImg.Add_Click({do_Restart})

# Button Refresh
$refreshButtonCreateImg = New-Object System.Windows.Forms.Button
$refreshButtonCreateImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Refresh.ico")
#$refreshButtonCreateImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Refresh.ico")
$refreshButtonCreateImg.ImageAlign = "TopCenter"
$refreshButtonCreateImg.BackColor = "ButtonFace"
$refreshButtonCreateImg.UseVisualStyleBackColor = $True
$refreshButtonCreateImg.Location = New-Object System.Drawing.Size(840,385)
$refreshButtonCreateImg.Size = New-Object System.Drawing.Size(95,64)
$refreshButtonCreateImg.Font = "Calibri, 8pt"
$refreshButtonCreateImg.TabIndex = 1
$refreshButtonCreateImg.Text = “Refresh”
$refreshButtonCreateImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($refreshButtonCreateImg, "Refresh")
$refreshButtonCreateImg.Add_Click({do_RunRefreshForm})

# Tab Three
# ================================================================
$tabpage_Three.Text = "Apply Image"
$tabpage_Three.Location = '20, 15'
$tabpage_Three.Padding ='3,3,3,3'
$tabpage_Three.Size = '1200, 530'
$tabpage_Three.BackColor = "White"
$tabpage_Three.TabIndex = 2

# Section for three tabs under Tab Three
# ----------------------------------------------------------------
$tabControlApplyImages = New-Object windows.Forms.TabControl
$tabPagePartition = New-Object windows.Forms.TabPage
$tabPageDismApplyImage = New-Object windows.Forms.TabPage
$tabPageFFUCreatePartition = New-Object windows.Forms.TabPage
$tabPageFFUApplyImage = New-Object windows.Forms.TabPage

$tabControlApplyImages.Font ="Calibri, 10pt style=Bold"
$tabControlApplyImages.BackColor = "Transparent"
$tabControlApplyImages.Anchor = 'Top, Bottom, Left, Right'
$tabControlApplyImages.ItemSize = '100,25'
$tabControlApplyImages.Padding = '15,5'
$tabControlApplyImages.Location = '20, 20'
$tabControlApplyImages.width = 780
$tabControlApplyImages.Height = 470

# Dism DiskPart Tab
# ================================================================
$tabPagePartition.Text = "Create WIM Partitions"
$tabPagePartition.Location = '20, 15'
$tabPagePartition.Padding ='3,3,3,3'
$tabPagePartition.Size = '780, 425'
$tabPagePartition.BackColor = "White"
$tabPagePartition.BackgroundImageLayout = "None"
$tabPagePartition.TabIndex = 0

# Adding radio button to patition tab
# ================================================================
# Create first radiobutton
$radioButtonOne = New-Object System.Windows.Forms.Radiobutton
$radioButtonOne.text = "Default Windows 10 BIOS"
$radioButtonOne.Font ="Calibri, 8pt"
$radioButtonOne.height = 20
$radioButtonOne.width = 235
$radioButtonOne.top = 30
$radioButtonOne.left = 15
$radioButtonOne.add_click({do_ViewPartition})

# Create second radiobutton
$radioButtonTwo = New-Object System.Windows.Forms.Radiobutton
$radioButtonTwo.text = "Default Windows 10 UEFI"
$radioButtonTwo.Font ="Calibri, 8pt"
$radioButtonTwo.height = 20
$radioButtonTwo.width = 235
$radioButtonTwo.top = 30
$radioButtonTwo.left = 250
$radioButtonTwo.add_click({do_ViewPartition})

# Create third radiobutton
$radioButtonThree = New-Object System.Windows.Forms.Radiobutton
$radioButtonThree.text = "Partition UEFI FFU (Larger Drives)"
$radioButtonThree.Font ="Calibri, 8pt"
$radioButtonThree.height = 20
$radioButtonThree.width = 235
$radioButtonThree.top = 30
$radioButtonThree.left = 485
$radioButtonThree.add_click({do_ViewPartition})

# UEFI FFU warning Label
$ffuWarningLabel = new-object System.Windows.Forms.Label
$ffuWarningLabel.Location = new-object System.Drawing.Size(490,60) 
$ffuWarningLabel.size = new-object System.Drawing.Size(200,20) 
$ffuWarningLabel.Text = "New OS Installation only"
$ffuWarningLabel.Font ="Calibri, 8pt"
$ffuWarningLabel.ForeColor = "Blue"
$ffuWarningLabel.Visible = $True

# Adding labels and textboxes to partition tab
# ----------------- MBR ------------------------------------

#  MBR System Label
$MbrSystemLabel = new-object System.Windows.Forms.Label
$MbrSystemLabel.Location = new-object System.Drawing.Size(15,105) 
$MbrSystemLabel.size = new-object System.Drawing.Size(80,20) 
$MbrSystemLabel.Text = "System:"
$MbrSystemLabel.Font ="Calibri, 8pt"
$MbrSystemLabel.Visible = $False

# MBR System Text Box
$systemTextbox = New-Object System.Windows.Forms.TextBox
$systemTextbox.Location = New-Object System.Drawing.Size(100,105)
$systemTextbox.Size = New-Object System.Drawing.Size(70,20)
$systemTextbox.Text = 350
$systemTextbox.Font ="Calibri, 8pt"
$systemTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$systemTextbox.Visible = $False

#  MBR Windows Label
$MbrWindowsLabel = new-object System.Windows.Forms.Label
$MbrWindowsLabel.Location = new-object System.Drawing.Size(15,135) 
$MbrWindowsLabel.size = new-object System.Drawing.Size(80,20) 
$MbrWindowsLabel.Text = "Windows:"
$MbrWindowsLabel.Font ="Calibri, 8pt"
$MbrWindowsLabel.Visible = $False

# MBR Windows Text Box
$windowsTextbox = New-Object System.Windows.Forms.TextBox
$windowsTextbox.Location = New-Object System.Drawing.Size(100,135)
$windowsTextbox.Size = New-Object System.Drawing.Size(70,20)
$windowsTextbox.Text = "XXXXXX"
$windowsTextbox.Font ="Calibri, 8pt"
$windowsTextbox.ReadOnly = $True
$windowsTextbox.Visible = $False

#  MBR Recovery Label
$MbrRecoveryLabel = new-object System.Windows.Forms.Label
$MbrRecoveryLabel.Location = new-object System.Drawing.Size(15,165) 
$MbrRecoveryLabel.size = new-object System.Drawing.Size(80,20) 
$MbrRecoveryLabel.Text = "Recovery:"
$MbrRecoveryLabel.Font ="Calibri, 8pt"
$MbrRecoveryLabel.Visible = $False

# MBR Recovery Text Box
$recoveryTextbox = New-Object System.Windows.Forms.TextBox
$recoveryTextbox.Location = New-Object System.Drawing.Size(100,165)
$recoveryTextbox.Size = New-Object System.Drawing.Size(70,20)
$recoveryTextbox.Text = 15000
$recoveryTextbox.Font ="Calibri, 8pt"
$recoveryTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$recoveryTextbox.Visible = $False

#--------------------- GPT -----------------------------------
#  GPT System Label
$gptSystemLabel = new-object System.Windows.Forms.Label
$gptSystemLabel.Location = new-object System.Drawing.Size(250,105) 
$gptSystemLabel.size = new-object System.Drawing.Size(80,20) 
$gptSystemLabel.Text = "System:"
$gptSystemLabel.Font ="Calibri, 8pt"
$gptSystemLabel.Visible = $False

# GPT System Text Box
$systemGPTTextbox = New-Object System.Windows.Forms.TextBox
$systemGPTTextbox.Location = New-Object System.Drawing.Size(345,105)
$systemGPTTextbox.Size = New-Object System.Drawing.Size(70,20)
$systemGPTTextbox.Text = 350
$systemGPTTextbox.Font ="Calibri, 8pt"
$systemGPTTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$systemGPTTextbox.Visible = $False

#  GPT MSR Label
$gptMSRLabel = new-object System.Windows.Forms.Label
$gptMSRLabel.Location = new-object System.Drawing.Size(250,135) 
$gptMSRLabel.size = new-object System.Drawing.Size(80,20) 
$gptMSRLabel.Text = "MSR:"
$gptMSRLabel.Font ="Calibri, 8pt"
$gptMSRLabel.Visible = $False

# GPT MSR Text Box
$gptMSRTextbox = New-Object System.Windows.Forms.TextBox
$gptMSRTextbox.Location = New-Object System.Drawing.Size(345,135)
$gptMSRTextbox.Size = New-Object System.Drawing.Size(70,20)
$gptMSRTextbox.Text = 128
$gptMSRTextbox.Font ="Calibri, 8pt"
$gptMSRTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$gptMSRTextbox.Visible = $False

#  GPT Windows Label
$gptWindowsLabel = new-object System.Windows.Forms.Label
$gptWindowsLabel.Location = new-object System.Drawing.Size(250,165) 
$gptWindowsLabel.size = new-object System.Drawing.Size(80,20) 
$gptWindowsLabel.Text = "Windows:"
$gptWindowsLabel.Font ="Calibri, 8pt"
$gptWindowsLabel.Visible = $False

# GPT Windows Text Box
$gptWindowsTextbox = New-Object System.Windows.Forms.TextBox
$gptWindowsTextbox.Location = New-Object System.Drawing.Size(345,165)
$gptWindowsTextbox.Size = New-Object System.Drawing.Size(70,20)
$gptWindowsTextbox.Text = "XXXXXX"
$gptWindowsTextbox.Font ="Calibri, 8pt"
$gptWindowsTextbox.ReadOnly = $True
$gptWindowsTextbox.Visible = $False

#  GPT Recovery Label
$gptRecoveryLabel = new-object System.Windows.Forms.Label
$gptRecoveryLabel.Location = new-object System.Drawing.Size(250,195) 
$gptRecoveryLabel.size = new-object System.Drawing.Size(80,20) 
$gptRecoveryLabel.Text = "Recovery:"
$gptRecoveryLabel.Font ="Calibri, 8pt"
$gptRecoveryLabel.Visible = $False

# GPT Recovery Text Box
$gptRecoveryTextbox = New-Object System.Windows.Forms.TextBox
$gptRecoveryTextbox.Location = New-Object System.Drawing.Size(345,195)
$gptRecoveryTextbox.Size = New-Object System.Drawing.Size(70,20)
$gptRecoveryTextbox.Text = 15000
$gptRecoveryTextbox.Font ="Calibri, 8pt"
$gptRecoveryTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
    $Script:mbrSystem =  $this.Text
})
$gptRecoveryTextbox.Visible = $False

#--------------------- FFU Larger Drives------------------------------
#  FFU System Label
$ffuSystemLabel = new-object System.Windows.Forms.Label
$ffuSystemLabel.Location = new-object System.Drawing.Size(485,105) 
$ffuSystemLabel.size = new-object System.Drawing.Size(80,20) 
$ffuSystemLabel.Text = "System:"
$ffuSystemLabel.Font ="Calibri, 8pt"
$ffuSystemLabel.Visible = $False

# FFU System Text Box
$ffuSystemTextbox = New-Object System.Windows.Forms.TextBox
$ffuSystemTextbox.Location = New-Object System.Drawing.Size(580,105)
$ffuSystemTextbox.Size = New-Object System.Drawing.Size(70,20)
$ffuSystemTextbox.Text = 350
$ffuSystemTextbox.Font ="Calibri, 8pt"
$ffuSystemTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$ffuSystemTextbox.Visible = $False

#  FFU MSR Label
$ffuMSRLabel = new-object System.Windows.Forms.Label
$ffuMSRLabel.Location = new-object System.Drawing.Size(485,135) 
$ffuMSRLabel.size = new-object System.Drawing.Size(80,20) 
$ffuMSRLabel.Text = "MSR:"
$ffuMSRLabel.Font ="Calibri, 8pt"
$ffuMSRLabel.Visible = $False

# FFU MSR Text Box
$ffuMSRTextbox = New-Object System.Windows.Forms.TextBox
$ffuMSRTextbox.Location = New-Object System.Drawing.Size(580,135)
$ffuMSRTextbox.Size = New-Object System.Drawing.Size(70,20)
$ffuMSRTextbox.Text = 128
$ffuMSRTextbox.Font ="Calibri, 8pt"
$ffuMSRTextbox.Add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$ffuMSRTextbox.Visible = $False

#  FFU Windows Label
$ffuWindowsLabel = new-object System.Windows.Forms.Label
$ffuWindowsLabel.Location = new-object System.Drawing.Size(485,165) 
$ffuWindowsLabel.size = new-object System.Drawing.Size(80,20) 
$ffuWindowsLabel.Text = "Windows:"
$ffuWindowsLabel.Font ="Calibri, 8pt"
$ffuWindowsLabel.Visible = $False

# FFU Windows Text Box
$ffuWindowsTextbox = New-Object System.Windows.Forms.TextBox
$ffuWindowsTextbox.Location = New-Object System.Drawing.Size(580,165)
$ffuWindowsTextbox.Size = New-Object System.Drawing.Size(70,20)
$ffuWindowsTextbox.Text = "XXXXXX"
$ffuWindowsTextbox.Font ="Calibri, 8pt"
$ffuWindowsTextbox.ReadOnly = $True
$ffuWindowsTextbox.Visible = $False

# Input PictureBox
$inputPicture = New-Object System.Windows.Forms.PictureBox
$inputPicture.Location = New-Object Drawing.Point 25,230
$inputPicture.Width = "470"
$inputPicture.Height = "200"
$inputPicture.BackColor = "Transparent"
$inputPicture.SizeMode = "Normal" # "Zoom" , "AutoSize", "CenterImage", "Normal"

# CheckBox Recover Label
$checkBoxRecoverLabel = new-object System.Windows.Forms.Label
$checkBoxRecoverLabel.Location = new-object System.Drawing.Size(100,350) 
$checkBoxRecoverLabel.size = new-object System.Drawing.Size(250,20) 
$checkBoxRecoverLabel.Text = "Configure Apply Recovery"
$checkBoxRecoverLabel.Font ="Calibri, 8pt"
$checkBoxRecoverLabel.Visible = $True

# Add Checkbox
$checkBoxRecovery = new-object System.Windows.Forms.Checkbox
$checkBoxRecovery.Location = new-object System.Drawing.Size(500,300)
$checkBoxRecovery.size = new-object System.Drawing.Size(270,20)
$checkBoxRecovery.Text = "Configure Recovery Partition"

# --------------------- End Of MBR and GPT --------------------------
# ================================================================
$tabPagePartition.Controls.Add($radioButtonOne)
$tabPagePartition.Controls.Add($radioButtonTwo)
$tabPagePartition.Controls.Add($radioButtonThree)
$tabPagePartition.Controls.Add($ffuWarningLabel)

$tabPagePartition.Controls.Add($MbrSystemLabel)
$tabPagePartition.Controls.Add($MbrWindowsLabel)
$tabPagePartition.Controls.Add($MbrRecoveryLabel)

$tabPagePartition.Controls.Add($systemTextbox)
$tabPagePartition.Controls.Add($windowsTextbox)
$tabPagePartition.Controls.Add($recoveryTextbox)

$tabPagePartition.Controls.Add($gptSystemLabel)
$tabPagePartition.Controls.Add($gptMSRLabel)
$tabPagePartition.Controls.Add($gptWindowsLabel)
$tabPagePartition.Controls.Add($gptRecoveryLabel)

$tabPagePartition.Controls.Add($systemGPTTextbox)
$tabPagePartition.Controls.Add($gptMSRTextbox)
$tabPagePartition.Controls.Add($gptWindowsTextbox)
$tabPagePartition.Controls.Add($gptRecoveryTextbox)

$tabPagePartition.Controls.Add($ffuSystemLabel)
$tabPagePartition.Controls.Add($ffuMSRLabel)
$tabPagePartition.Controls.Add($ffuWindowsLabel)
$tabPagePartition.Controls.Add($ffuSystemTextbox)
$tabPagePartition.Controls.Add($ffuMSRTextbox)
$tabPagePartition.Controls.Add($ffuWindowsTextbox)

$tabPagePartition.Controls.Add($inputPicture)
$tabPagePartition.Controls.Add($checkBoxRecovery)

# Dism Apply Image Tab Control
# ================================================================
$tabPageDismApplyImage.Text = "DISM Apply Image"
$tabPageDismApplyImage.Location = '20, 15'
$tabPageDismApplyImage.Padding ='3,3,3,3'
$tabPageDismApplyImage.Size = '780, 425'
$tabPageDismApplyImage.BackColor = "White"
$tabPageDismApplyImage.BackgroundImageLayout = "None"
$tabPageDismApplyImage.TabIndex = 1

# Label select .Wim file
$labelForDismWimFile = New-Object System.Windows.Forms.Label
$labelForDismWimFile.Location = New-Object System.Drawing.Point(20, 40)
$labelForDismWimFile.Size = New-Object System.Drawing.Size(140, 25)
$labelForDismWimFile.Font ="Calibri, 8pt"
$labelForDismWimFile.Text = "Select Image File:"

# ComoboBox to select Wim files
$comboBoxDismApply = New-Object System.Windows.Forms.ComboBox
$comboBoxDismApply.Location = New-Object System.Drawing.Point(160, 40)
$comboBoxDismApply.Size = New-Object System.Drawing.Size(200, 310)
$comboBoxDismApply.Font ="Calibri, 8pt"
$comboBoxDismApply.DropDownStyle = 1
$comboBoxDismApply.TabIndex = 2
$comboBoxDismApply.add_SelectedIndexChanged({do_AddFileForDismApplyWIM})

# RichBox for description of wim files
$richBoxDismApply = New-Object System.Windows.Forms.RichTextBox
$richBoxDismApply.location = New-Object System.Drawing.Size(20,100) 
$richBoxDismApply.Size = New-Object System.Drawing.Size(340,150) 
$richBoxDismApply.font = "Calibri, 8pt"
$richBoxDismApply.Visible=$True
$richBoxDismApply.wordwrap = $true
$richBoxDismApply.multiline = $true
$richBoxDismApply.readonly = $true
$richBoxDismApply.scrollbars = "Vertical"
$richBoxDismApply.TabIndex = 3

# Label Info about Apply image action
$labelPartitionDismApply = New-Object System.Windows.Forms.Label
$labelPartitionDismApply.Font = "Calibri, 9pt, style=Bold"
$labelPartitionDismApply.ForeColor = "Red"
$labelPartitionDismApply.Location = New-Object System.Drawing.Point(10, 330)
$labelPartitionDismApply.Size = New-Object System.Drawing.Size(350, 25)
$labelPartitionDismApply.Text = "Computer's Hard Drive will be formatted!"
$labelPartitionDismApply.TextAlign = "MiddleCenter"

# Label Info about Firmware
$labelDismApplyFirmwareType = New-Object System.Windows.Forms.Label
$labelDismApplyFirmwareType.Font = "Calibri, 9pt, style=Bold"
$labelDismApplyFirmwareType.ForeColor = "Blue"
$labelDismApplyFirmwareType.Location = New-Object System.Drawing.Point(10, 355)
$labelDismApplyFirmwareType.Size = New-Object System.Drawing.Size(350, 25)
$labelDismApplyFirmwareType.Text = ""
$labelDismApplyFirmwareType.TextAlign = "MiddleCenter"

# PictureBox Dism-Wim - Apply
$picBoxWimApply = New-Object System.Windows.Forms.PictureBox
$picBoxWimApply.Width = $imageDismWimFile.Size.Width
$picBoxWimApply.Height = $imageDismWimFile.Size.Height
$picBoxWimApply.Image = $imageDismWimFile
$picBoxWimApply.Location = New-Object Drawing.Point 510,70
$picBoxWimApply.BackColor = "Transparent"

# Button Delete selected image file
$deleteButtonSelectDismFile = New-Object System.Windows.Forms.Button
$deleteButtonSelectDismFile.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Delete.ico")
#$deleteButtonSelectDismFile.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Delete.ico")
$deleteButtonSelectDismFile.ImageAlign = "TopCenter"
$deleteButtonSelectDismFile.BackColor = "ButtonFace"
$deleteButtonSelectDismFile.UseVisualStyleBackColor = $True
$deleteButtonSelectDismFile.Location = New-Object System.Drawing.Size(420,280)
$deleteButtonSelectDismFile.Size = New-Object System.Drawing.Size(85,64)
$deleteButtonSelectDismFile.Font = "Calibri, 8pt"
$deleteButtonSelectDismFile.TabIndex = 6
$deleteButtonSelectDismFile.Text = “Delete”
$deleteButtonSelectDismFile.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($deleteButtonSelectDismFile, "Delete selected image file from the list.")
$deleteButtonSelectDismFile.Visible = $False
$deleteButtonSelectDismFile.Add_Click({do_DeleteWimImageFile})

# Button stop imaging Apply process
$stopButtonApplyDismProcess = New-Object System.Windows.Forms.Button
$stopButtonApplyDismProcess.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Stop.ico")
#$stopButtonApplyDismProcess.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Stop.ico")
$stopButtonApplyDismProcess.ImageAlign = "TopCenter"
$stopButtonApplyDismProcess.BackColor = "ButtonFace"
$stopButtonApplyDismProcess.UseVisualStyleBackColor = $True
$stopButtonApplyDismProcess.Location = New-Object System.Drawing.Size(520,280)
$stopButtonApplyDismProcess.Size = New-Object System.Drawing.Size(85,64)
$stopButtonApplyDismProcess.Font = "Calibri, 8pt"
$stopButtonApplyDismProcess.TabIndex = 5
$stopButtonApplyDismProcess.Text = “Imaging”
$stopButtonApplyDismProcess.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($stopButtonApplyDismProcess, "Stop the current imaging apply process.")
$stopButtonApplyDismProcess.Visible = $False
$stopButtonApplyDismProcess.Add_Click({do_StopApplyImage})

# Button Apply WIM Image
$applyWimImageButton = New-Object System.Windows.Forms.Button
$applyWimImageButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\ApplyImage.ico")
#$applyWimImageButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\ApplyImage.ico")
$applyWimImageButton.ImageAlign = "TopCenter"
$applyWimImageButton.BackColor = "ButtonFace"
$applyWimImageButton.UseVisualStyleBackColor = $True
$applyWimImageButton.Location = New-Object System.Drawing.Size(620,280)
$applyWimImageButton.Size = New-Object System.Drawing.Size(85,64)
$applyWimImageButton.Font = "Calibri, 8pt"
$applyWimImageButton.TabIndex = 4
$applyWimImageButton.Text = “Apply”
$applyWimImageButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($applyWimImageButton, "Apply or install an image to this computer")
$applyWimImageButton.Add_Click({do_ApplyWim})

# Adding controls to the Dism tab control
$tabPageDismApplyImage.Controls.Add($labelForDismWimFile)
$tabPageDismApplyImage.Controls.Add($comboBoxDismApply)
$tabPageDismApplyImage.Controls.Add($richBoxDismApply)
$tabPageDismApplyImage.Controls.Add($picBoxWimApply)
$tabPageDismApplyImage.Controls.Add($labelPartitionDismApply)
$tabPageDismApplyImage.Controls.Add($labelDismApplyFirmwareType)
$tabPageDismApplyImage.Controls.Add($stopButtonApplyDismProcess)
$tabPageDismApplyImage.Controls.Add($deleteButtonSelectDismFile)
$tabPageDismApplyImage.Controls.Add($applyWimImageButton)

# FFU Partition Creation Tab Control
# ================================================================
$tabPageFFUCreatePartition.Text = "Create FFU Partition"
$tabPageFFUCreatePartition.Location = '20, 15'
$tabPageFFUCreatePartition.Padding ='3,3,3,3'
$tabPageFFUCreatePartition.Size = '780, 425'
$tabPageFFUCreatePartition.BackColor = "White"
$tabPageFFUCreatePartition.BackgroundImageLayout = "None"
$tabPageFFUCreatePartition.TabIndex = 3

# ================================================================
# Create fourth radiobutton
$radioButtonFour = New-Object System.Windows.Forms.Radiobutton
$radioButtonFour.text = "Do no change Partition Configuration"
$radioButtonFour.Font ="Calibri, 8pt"
$radioButtonFour.height = 20
$radioButtonFour.width = 235
$radioButtonFour.top = 30
$radioButtonFour.left = 20
$radioButtonFour.add_click({do_ViewPartition})

# Label describe the option button Four
$labelForRadioButtonFour = New-Object System.Windows.Forms.Label
$labelForRadioButtonFour.Location = New-Object System.Drawing.Point(40, 55)
$labelForRadioButtonFour.Size = New-Object System.Drawing.Size(500, 25)
$labelForRadioButtonFour.Font ="Calibri, 8pt"
$labelForRadioButtonFour.Text = "(Both the Reference/Source and Destination Computer have the same drive size)"

# Create fifth radiobutton
$radioButtonFive = New-Object System.Windows.Forms.Radiobutton
$radioButtonFive.text = "Change Partition Configuration - Destination Computer has larger drive"
$radioButtonFive.Font ="Calibri, 8pt"
$radioButtonFive.height = 20
$radioButtonFive.width = 500
$radioButtonFive.top = 90
$radioButtonFive.left = 20
$radioButtonFive.add_click({do_ViewPartition})

# Input PictureBox
$inputFFUPartitionPicture = New-Object System.Windows.Forms.PictureBox
$inputFFUPartitionPicture.Location = New-Object Drawing.Point 25,120
$inputFFUPartitionPicture.Width = "470"
$inputFFUPartitionPicture.Height = "240"
$inputFFUPartitionPicture.BackColor = "Transparent"
$inputFFUPartitionPicture.SizeMode = "Normal" # "Zoom" , "AutoSize", "CenterImage", "Normal"

# Add Checkbox
$checkBoxFFURecovery = new-object System.Windows.Forms.Checkbox
$checkBoxFFURecovery.Location = new-object System.Drawing.Size(510,310)
$checkBoxFFURecovery.size = new-object System.Drawing.Size(270,20)
$checkBoxFFURecovery.Text = "Configure Recovery Partition"

# ------------- End Of FFU Prartition Configuration --------------
# ================================================================
$tabPageFFUCreatePartition.Controls.Add($radioButtonFour)
$tabPageFFUCreatePartition.Controls.Add($labelForRadioButtonFour)
$tabPageFFUCreatePartition.Controls.Add($radioButtonFive)
$tabPageFFUCreatePartition.Controls.Add($inputFFUPartitionPicture)
$tabPageFFUCreatePartition.Controls.Add($checkBoxFFURecovery)

# FFU Apply Image Tab Control
# ================================================================
$tabPageFFUApplyImage.Text = "FFU Apply Image"
$tabPageFFUApplyImage.Location = '20, 15'
$tabPageFFUApplyImage.Padding ='3,3,3,3'
$tabPageFFUApplyImage.Size = '780, 425'
$tabPageFFUApplyImage.BackColor = "white"
$tabPageFFUApplyImage.BackgroundImageLayout = "None"
$tabPageFFUApplyImage.TabIndex = 4

# Label select Apply FFU Drive
$labelForApplyFfuDrive = New-Object System.Windows.Forms.Label
$labelForApplyFfuDrive.Location = New-Object System.Drawing.Point(20, 20)
$labelForApplyFfuDrive.Size = New-Object System.Drawing.Size(120, 25)
$labelForApplyFfuDrive.Font ="Calibri, 8pt"
$labelForApplyFfuDrive.Text = "Select Drive:"

$diskFfuAplyDrive = get-ciminstance win32_diskdrive | 
select @{Label="Drive";Expression={$_.index}},InterfaceType,@{Label="Size(GB)";Expression={$_.size/1GB}},Caption, Partitions, Status
   
$applyDriveFfuCollection = ($diskFfuAplyDrive | select drive).drive
     
# Combo Box Apply FFU Drive  
$applyDropDownFfu = new-object System.Windows.Forms.ComboBox
$applyDropDownFfu.Location = new-object System.Drawing.Size(160,20)
$applyDropDownFfu.Size = new-object System.Drawing.Size(60,20)
$applyDropDownFfu.DropDownStyle = 2
$applyDropDownFfu.TabIndex = 1    
ForEach ($applyDrive in $applyDriveFfuCollection) {[void]$applyDropDownFfu.Items.Add($applyDrive)}

# Label select FFU file
$labelForFFUWimFile = New-Object System.Windows.Forms.Label
$labelForFFUWimFile.Location = New-Object System.Drawing.Point(20, 60)
$labelForFFUWimFile.Size = New-Object System.Drawing.Size(140, 25)
$labelForFFUWimFile.Font ="Calibri, 8pt"
$labelForFFUWimFile.Text = "Select Image File:"

# ComoboBox to select FFU files
$comboBoxFFUApply = New-Object System.Windows.Forms.ComboBox
$comboBoxFFUApply.Location = New-Object System.Drawing.Point(160, 60)
$comboBoxFFUApply.Size = New-Object System.Drawing.Size(200, 310)
$comboBoxFFUApply.Font ="Calibri, 8pt"
$comboBoxFFUApply.DropDownStyle = 1
$comboBoxFFUApply.add_SelectedIndexChanged({do_AddFileForApplyFFU})
$comboBoxFFUApply.TabIndex = 2

# RichBox for description of FFU files
$richBoxFFUApply = New-Object System.Windows.Forms.RichTextBox
$richBoxFFUApply.location = New-Object System.Drawing.Size(20,100) 
$richBoxFFUApply.Size = New-Object System.Drawing.Size(340,150) 
$richBoxFFUApply.font = "Calibri, 8pt"
$richBoxFFUApply.Visible=$True
$richBoxFFUApply.wordwrap = $true
$richBoxFFUApply.multiline = $true
$richBoxFFUApply.readonly = $true
$richBoxFFUApply.scrollbars = "Vertical"

# Label Info about Apply image action
$labelPartitionFFUApply = New-Object System.Windows.Forms.Label
$labelPartitionFFUApply.Font = "Calibri, 9pt, style=Bold"
$labelPartitionFFUApply.ForeColor = "Red"
$labelPartitionFFUApply.Location = New-Object System.Drawing.Point(10, 330)
$labelPartitionFFUApply.Size = New-Object System.Drawing.Size(350, 25)
$labelPartitionFFUApply.Text = "Computer's Hard Drive will be formatted!"
$labelPartitionFFUApply.TextAlign = "MiddleCenter"

# Label Info about Firmware
$labelFFUApplyFirmwareType = New-Object System.Windows.Forms.Label
$labelFFUApplyFirmwareType.Font = "Calibri, 9pt, style=Bold"
$labelFFUApplyFirmwareType.ForeColor = "Blue"
$labelFFUApplyFirmwareType.Location = New-Object System.Drawing.Point(10, 355)
$labelFFUApplyFirmwareType.Size = New-Object System.Drawing.Size(350, 25)
$labelFFUApplyFirmwareType.Text = ""
$labelFFUApplyFirmwareType.TextAlign = "MiddleCenter"

# PictureBox Dism-FFU for main page
$picBoxFFUApply = New-Object System.Windows.Forms.PictureBox
$picBoxFFUApply.Width = $imageDismFFUFile.Size.Width
$picBoxFFUApply.Height = $imageDismFFUFile.Size.Height
$picBoxFFUApply.Image = $imageDismFFUFile
$picBoxFFUApply.Location = New-Object Drawing.Point 510,70
$picBoxFFUApply.BackColor = "Transparent"

# Button Delete selected image file
$deleteButtonSelectFFUFile = New-Object System.Windows.Forms.Button
$deleteButtonSelectFFUFile.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Delete.ico")
#$deleteButtonSelectFFUFile.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Delete.ico")
$deleteButtonSelectFFUFile.ImageAlign = "TopCenter"
$deleteButtonSelectFFUFile.BackColor = "ButtonFace"
$deleteButtonSelectFFUFile.UseVisualStyleBackColor = $True
$deleteButtonSelectFFUFile.Location = New-Object System.Drawing.Size(420,280)
$deleteButtonSelectFFUFile.Size = New-Object System.Drawing.Size(85,64)
$deleteButtonSelectFFUFile.Font = "Calibri, 8pt"
$deleteButtonSelectFFUFile.TabIndex = 5
$deleteButtonSelectFFUFile.Text = “Delete”
$deleteButtonSelectFFUFile.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($deleteButtonSelectFFUFile, "Deletes selected image file from the list.")
$deleteButtonSelectFFUFile.Visible = $False
$deleteButtonSelectFFUFile.Add_Click({do_DeleteFFUImageFile})

# Button stop imaging Apply process
$stopButtonApplyFFUProcess = New-Object System.Windows.Forms.Button
$stopButtonApplyFFUProcess.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Stop.ico")
#$stopButtonApplyFFUProcess.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Stop.ico")
$stopButtonApplyFFUProcess.ImageAlign = "TopCenter"
$stopButtonApplyFFUProcess.BackColor = "ButtonFace"
$stopButtonApplyFFUProcess.UseVisualStyleBackColor = $True
$stopButtonApplyFFUProcess.Location = New-Object System.Drawing.Size(520,280)
$stopButtonApplyFFUProcess.Size = New-Object System.Drawing.Size(85,64)
$stopButtonApplyFFUProcess.Font = "Calibri, 8pt"
$stopButtonApplyFFUProcess.TabIndex = 4
$stopButtonApplyFFUProcess.Text = “Imaging”
$stopButtonApplyFFUProcess.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($stopButtonApplyFFUProcess, "Stops the current imaging apply process.")
$stopButtonApplyFFUProcess.Visible = $False
$stopButtonApplyFFUProcess.Add_Click({do_StopApplyImage})

# Button Apply FFU Image
$applyFfuImageButton = New-Object System.Windows.Forms.Button
$applyFfuImageButton.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\ApplyImage.ico")
#$applyFfuImageButton.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\ApplyImage.ico")
$applyFfuImageButton.ImageAlign = "TopCenter"
$applyFfuImageButton.BackColor = "ButtonFace"
$applyFfuImageButton.UseVisualStyleBackColor = $True
$applyFfuImageButton.Location = New-Object System.Drawing.Size(620,280)
$applyFfuImageButton.Size = New-Object System.Drawing.Size(85,64)
$applyFfuImageButton.Font = "Calibri, 8pt"
$applyFfuImageButton.TabIndex = 3
$applyFfuImageButton.Text = “Apply”
$applyFfuImageButton.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($applyFfuImageButton, "Apply or install an image to this computer")
$applyFfuImageButton.Add_Click({do_ApplyFFU})

# Add controls to the FFU tab
$tabPageFFUApplyImage.Controls.Add($labelForApplyFfuDrive)
$tabPageFFUApplyImage.Controls.Add($applyDropDownFfu)
$tabPageFFUApplyImage.Controls.Add($labelForFFUWimFile)
$tabPageFFUApplyImage.Controls.Add($comboBoxFFUApply)
$tabPageFFUApplyImage.Controls.Add($richBoxFFUApply)
$tabPageFFUApplyImage.Controls.Add($labelPartitionFFUApply)
$tabPageFFUApplyImage.Controls.Add($labelFFUApplyFirmwareType)
$tabPageFFUApplyImage.Controls.Add($picBoxFFUApply)
$tabPageFFUApplyImage.Controls.Add($stopButtonApplyFFUProcess)
$tabPageFFUApplyImage.Controls.Add($deleteButtonSelectFFUFile)
$tabPageFFUApplyImage.Controls.Add($applyFfuImageButton)

# PictureBox for main page
$picBoxThree = New-Object System.Windows.Forms.PictureBox
$picBoxThree.Width = $imageOne.Size.Width
$picBoxThree.Height = $imageOne.Size.Height
$picBoxThree.Image = $imageOne
$picBoxThree.Location = New-Object Drawing.Point 810,15
$picBoxThree.BackColor = "Transparent"

# Button Shutdown
$shutdownButtonApplImg = New-Object System.Windows.Forms.Button
$shutdownButtonApplImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Shutdown.ico")
#$shutdownButtonApplImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Shutdown.ico")
$shutdownButtonApplImg.ImageAlign = "TopCenter"
$shutdownButtonApplImg.BackColor = "ButtonFace"
$shutdownButtonApplImg.UseVisualStyleBackColor = $True
$shutdownButtonApplImg.Location = New-Object System.Drawing.Size(1060,385)
$shutdownButtonApplImg.Size = New-Object System.Drawing.Size(95,64)
$shutdownButtonApplImg.Font = "Calibri, 8pt"
$shutdownButtonApplImg.TabIndex = 1
$shutdownButtonApplImg.Text = “Shutdown”
$shutdownButtonApplImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($shutdownButtonApplImg, "Shutdown Computer")
$shutdownButtonApplImg.Add_Click({do_Shutdown})

# Button Restart
$restartButtonApplImg = New-Object System.Windows.Forms.Button
$restartButtonApplImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Restart.ico")
#$restartButtonApplImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Restart.ico")
$restartButtonApplImg.ImageAlign = "TopCenter"
$restartButtonApplImg.BackColor = "ButtonFace"
$restartButtonApplImg.UseVisualStyleBackColor = $True
$restartButtonApplImg.Location = New-Object System.Drawing.Size(950,385)
$restartButtonApplImg.Size = New-Object System.Drawing.Size(95,64)
$restartButtonApplImg.Font = "Calibri, 8pt"
$restartButtonApplImg.TabIndex = 1
$restartButtonApplImg.Text = “Restart”
$restartButtonApplImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($restartButtonApplImg, "Restart Computer")
$restartButtonApplImg.Add_Click({do_Restart})

# Button Refresh
$refreshButtonApplImg = New-Object System.Windows.Forms.Button
$refreshButtonApplImg.Image = [system.drawing.image]::FromFile("X:\Windows\System32\ICOs\Refresh.ico")
#$refreshButtonApplImg.Image = [system.drawing.image]::FromFile("C:\PSScript\FFU\ICOs\Refresh.ico")
$refreshButtonApplImg.ImageAlign = "TopCenter"
$refreshButtonApplImg.BackColor = "ButtonFace"
$refreshButtonApplImg.UseVisualStyleBackColor = $True
$refreshButtonApplImg.Location = New-Object System.Drawing.Size(840,385)
$refreshButtonApplImg.Size = New-Object System.Drawing.Size(95,64)
$refreshButtonApplImg.Font = "Calibri, 8pt"
$refreshButtonApplImg.TabIndex = 1
$refreshButtonApplImg.Text = “Refresh”
$refreshButtonApplImg.TextAlign = "BottomCenter"
$tooltipinfo.SetToolTip($refreshButtonApplImg, "Refresh")
$refreshButtonApplImg.Add_Click({do_RunRefreshForm})

# Add the controls to the form
# =========================================================

$objForm.Controls.Add($tabcontrol)
# Tab One
$tabpage_One.Controls.Add($picBoxOne)
$tabpage_One.Controls.Add($pcInfoTextBox)
$tabpage_One.Controls.Add($partitionDriveGrid)
$tabpage_One.Controls.Add($labelTreeViewImages)
$tabpage_One.Controls.Add($treeView1)
$tabpage_One.Controls.Add($buttonDelImgFile)
$tabpage_One.Controls.Add($shutdownButton)
$tabpage_One.Controls.Add($restartButton)
$tabpage_One.Controls.Add($refreshButton)
$tabpage_One.Controls.Add($productKeyButton)

# Tab Two
# ------------------------------------------------
$tabpage_Two.Controls.Add($tabControlCreateImages)
$tabControlCreateImages.tabpages.add($tabPageDismCreateImage)
$tabControlCreateImages.tabpages.add($tabPageFFUCreateImage)

$tabpage_Two.Controls.Add($picBoxTwo)
$tabpage_Two.Controls.Add($shutdownButtonCreateImg)
$tabpage_Two.Controls.Add($restartButtonCreateImg)
$tabpage_Two.Controls.Add($refreshButtonCreateImg)

# Tab Three
# ------------------------------------------------
$tabpage_Three.Controls.Add($tabControlApplyImages)
$tabControlApplyImages.tabpages.add($tabPagePartition)
$tabControlApplyImages.tabpages.add($tabPageDismApplyImage)
$tabControlApplyImages.tabpages.add($tabPageFFUCreatePartition)
$tabControlApplyImages.tabpages.add($tabPageFFUApplyImage)

$tabpage_Three.Controls.Add($picBoxThree)
$tabpage_Three.Controls.Add($shutdownButtonApplImg)
$tabpage_Three.Controls.Add($restartButtonApplImg)
$tabpage_Three.Controls.Add($refreshButtonApplImg)

# Tabcontrol
$tabcontrol.tabpages.add($tabpage_One)
$tabcontrol.tabpages.add($tabpage_Two)
$tabcontrol.tabpages.add($tabpage_Three)

# Activate the form
# =========================================================
$objForm.Add_Load({do_ListPartitions;do_GetFolderTree;do_GetWindowsPartition;do_GetWindowsFirmwareType;do_ListWimFiles;do_ListFFUFiles})
$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()