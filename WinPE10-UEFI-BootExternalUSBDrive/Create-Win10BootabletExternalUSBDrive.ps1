# =================================================================
# www.AlexComputerBubble - Create UEFI Bootable External USB Drive
# =================================================================
#
# Ajouts de deux assembly en provenance du GAC (global assembly cache)
#
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

# =================================================================
# Functions
# =================================================================

#
# Permet l'affichage de renseignements utilisateur suivant la tache à effectuer
#

Function do_StartMediaLabel($state) {
switch($state)
{
    "START" {
             #$labelWaitForCommLineWindow.Text = "Please wait until the Powershell Command Line Windows is closed.";$labelWaitForCommLineWindow.ForeColor = "Red"
             $labelWaitForCommLineWindow.Text = "S.V.P attendez que la fenêtre de ligne de commande powershell se ferme.";$labelWaitForCommLineWindow.ForeColor = "Red"
             #$labelInfoAboutScriptAction.Text = "Once all Media Files are created please proceed to the second step.";$labelInfoAboutScriptAction.ForeColor = "Blue";Break
             $labelInfoAboutScriptAction.Text = "Dés que tous les fichiers sont créés, S.V.P passé à la deuxiéme étape.";$labelInfoAboutScriptAction.ForeColor = "Blue";Break
            }
    "END" {$labelInfoAboutScriptAction.Text = "";$labelWaitForCommLineWindow.Text = "";Break}
}
    $objForm.Refresh()
}

#
# Sélection d'un dossier
#
# ouvre un objet shell de type BrowserFolder (parcours de dossier) afin de sélectionner un dossier de travail
#
Function Select-Folder{
param(
        #$message=’Select a folder’, 	        # message par défaut (en cas de non attribution de valeur)
        $message=’Sélectionner un dossier’, 	# message par défaut (en cas de non attribution de valeur)
        $path = 0,
        [int]$source
    )
$object = New-Object -ComObject Shell.Application
$folder = $object.BrowseForFolder(0, $message, 0, $path)
    if ($folder -ne $null -and $source -eq 1) { # si dossier référencé et $source = 1 (fichier source référencé)
    $sourceTextbox.Text = $folder.self.path     # affecte le chemin du dossier au contrôle TextBox
    $Script:folderPath = $sourceTextbox.Text    # mémorise le chemin du dossier dans variable folderPath context $Script
    } 
} 

#
# Lance le script powershell WinPE-UEFI.ps1 en fonction de l'architecture
# 
# La variable -WinArch 'x86' ou 'amd64' en fonction de l'architecture à déployer
# Remarque: $($Script:folderPath) et non $Script:folderPath !!
# Attention: il ne faut pas mettre de caractère espacement devant "@ , sinon il y aura un souci !
# donc attention à la remise en forme du code !!
#
Function do_StartPSScript($Mode){

switch($Mode){
"32-BIT"{ 
$commandStartPSScript = @"
Start-Process PowerShell -ArgumentList "$($Script:folderPath)\WinPE-UEFI.ps1 -WinArch 'x86'"
"@
}
"64-BIT"{
$commandStartPSScript = @"
Start-Process PowerShell -ArgumentList "$($Script:folderPath)\WinPE-UEFI.ps1 -WinArch 'amd64'" 
"@
}
}
    Invoke-Expression $commandStartPSScript
}

#
# Gestion du bouton radio sur le choix du type de WinPE à créer en fonction de l'architecture choisie
#
Function do_CreateMediaFiles{

    If ($radioButtonOne.Checked -eq $True){          # x86
        $WinPEMode = "32-BIT"
    }
    ElseIf($radioButtonTwo.Checked -eq $True){       # x64 (amd64)
        $WinPEMode = "64-BIT"
    }
    Else {
        #[System.Windows.Forms.MessageBox]::Show("Please select 32-Bit/64-Bit option!") # info boite de dialogue
        [System.Windows.Forms.MessageBox]::Show("S.V.P sélectionnez l'option 32-Bit ou 64-Bit!") # info boite de dialogue
        return
    }

    If(($sourceTextbox.Text) -and (Test-Path -Path "$($Script:folderPath)\WinPE-UEFI.ps1" )) {
        do_StartPSScript -Mode $WinPEMode
        do_StartMediaLabel("START")                   # début de la création, modifie le label du bouton
    }
    Else{
        #[System.Windows.Forms.MessageBox]::Show("Please select folder named 'WinPE-UEFI-BootExternalUSBDrive'.")
        [System.Windows.Forms.MessageBox]::Show("S.V.P sélectionnez le dossier intitulé 'WinPE-UEFI-BootExternalUSBDrive'.")
        do_StartMediaLabel("END")                     # fin de la création, modifie le label du bouton
        return
    }
}

#
# Affiche un message de couleur rouge dans le champ $messageForActionLabel.Text
#
Function do_StartLabel{
    #$messageForActionLabel.ForeColor = "Red";$messageForActionLabel.Text = “... Formating , please wait ...”
    $messageForActionLabel.ForeColor = "Red";$messageForActionLabel.Text = “... Formatage en cours , S.V.P attendez ...”
    $messageForActionLabel.Refresh()
    $objform.refresh()
}

#
# Affiche un message de couleur bleu dans le champ $messageForActionLabel.Text
#
Function do_ChangeLabel{
    #$messageForActionLabel.ForeColor = "Blue";$messageForActionLabel.Text = “Creation of UEFI Boot USB Drive completed successfully”
    $messageForActionLabel.ForeColor = "Blue";$messageForActionLabel.Text = “Création du support USB bootable UEFI terminé correctement”
    $messageForActionLabel.Refresh()
    $objform.refresh
}

#
# Efface le message du champ $messageForActionLabel.Text
#
Function do_ClearLabel{
    $messageForActionLabel.Text = “”
    $messageForActionLabel.Refresh()
    $objform.refresh
}

#
# Création d'une liste d'informations sur les disques présents sur le PC (contrôle ViewDataGrid)
# 
# $listDisk[-1].Substring(7,2).Trim(), permet d'extraire le nombre de disk à condition d'ajouter 1 (disk 0, premier disk)
# un fichier temporaire est créé: $env:TEMP\ListDisk.txt (dossier C:\Users\xxxx\AppData\) 
# il existe une commande New-TemporaryFile depuis powershell 5
#
Function do_ListDiskPartResult{      
    If($viewDataGrid.columncount -gt 0){  # création d'un ViewDataGrid
        $viewDataGrid.DataSource = $null  # de source $null
        $viewDataGrid.Columns.Clear()     # et vide (entête de colonne ?...)
    }     
    $Column1 = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    $Column1.name = "Select"              # Nom de la 1ere colonne
    $viewDataGrid.Columns.Add($Column1)   # ajout de la colonne au contrôle ViewDataGrid

	$array = New-Object System.Collections.ArrayList      # création d'une liste de chaine
    $pcInfo = New-Object System.Collections.ArrayList     # idem pour récupèrer les infos du PC
        # ----------------------------------------------

    New-Item -Path $env:TEMP -Name ListDisk.txt -ItemType File -Force | Out-Null # force la création d'un fichier ListDisk.txt
    Add-Content -Path $env:TEMP\ListDisk.txt "List disk"                         # ajout de la commande "List Disk" dans le fichier
    $listDisk = (C:\Windows\System32\DiskPart /s $env:TEMP\ListDisk.txt)         # appel de diskpart /s ListDisk.txt
    # $diskID = $listDisk[-1].Substring(7,2).Trim()                              # pour en-us !!
    $diskID = $listDisk[-1].Substring(8,2).Trim()                                # pour fr-FR !! (dernière ligne !)
    $totalDisk = $diskID                                                         # le nombre de disk présent dans le PC

   $array = @(
    for ($d=0;$d -le $totalDisk;$d++){                                     # récupère les informations sur les disks présent
    #$diskID = $LISTDISK[-1-$d].Substring(7,5).trim()                      # numéro du disk (en-us)
    $diskID = $LISTDISK[-1-$d].Substring(8,2).trim()                       # numéro du disk (fr-FR index offset 8)
    Add-Content -Path $env:TEMP\ListDisk.txt "Select disk $diskID"         # ajout Select disk xx au fichier ListDisk.txt
    Add-Content -Path $env:TEMP\ListDisk.txt "Detail disk"                 # ajout Detail disk au fichier ListDisk.txt
    $detailDisk = (C:\Windows\System32\DiskPart /s $env:TEMP\ListDisk.txt) # exécute la commande diskpart /s ListDisk.txt
    write-host $detailDisk

    #Copy-Item "$env:TEMP\ListDisk.txt" (Get-Location).Path                # permet de contrôler le fichier ListDisk.txt
    
    $name = $detailDisk[-19].Trim()                                        # 1Ere ligne de detail disk
    
    write-host "nom du disque:$name"
    $driveLetter = $detailDisk[-1].Substring(15,1)                         # lettre du volume
    write-host "Lettre du lecteur:$type"
    #$type = $detailDisk[-17].Substring(9).Trim()                          # Type de disk ex SATA
    $type = $detailDisk[-17].Substring(7).Trim()                           # Type de disk ex SATA
    write-host "Type de disque:$type"
    $size = $detailDisk[-1].Substring(51,9).Trim()                         # taille du disk
    write-host "Size du disk:$type"
    $partitionType = $detailDisk[-1].Substring(39,9).Trim()                # champ type partition
    write-host "Type de partition:$type"

    # on construit un objet customisé avec les champs utiles
    [pscustomobject]@{DiskNumber=$DISKID;DriveLetter=$DRIVELETTER;Type=$TYPE; Size= $SIZE;PartitionType=$partitionType; DiskName=$NAME}
    }
   )
    $pcInfo.AddRange($array)                                               # on ajoute nos données
    $viewDataGrid.DataSource = $pcInfo                                     # comme source pour le datagrid
 
    for($i=0;$i -lt $viewDataGrid.RowCount;$i++){                          # traitement de couleur sur les champs exploitables

       if($viewDataGrid.Item('PartitionType',$i).Value.ToString() -like "Removable" `
        -or $viewDataGrid.Item('DriveLetter',$i).Value.ToString() -like "C")
            {
            $viewDataGrid.Item('PartitionType',$i).Style.backcolor = 'red' # support (media) non exploitable en rouge
            }
       else    
            {
            $viewDataGrid.Item('PartitionType',$i).Style.backcolor = 'green' # support (media) exploitable en vert
            }
    }

	$objform.refresh()                                                     # rafraichie l'ensemble de la form
}



Function do_CreateImageContainer{
$volumes = (Get-WmiObject -Query "SELECT * from Win32_LogicalDisk" | Select -Property Properties )
foreach($i In $volumes){                                                   # parcours des volumes
    switch ("$($i.Properties.Item("VolumeName").Value)")                   
    {
    "IMAGEDATA" {                                                          # Identification de 'IMAGEDATA'
        # $partition = $i.Properties.Item("VolumeName").Value
        $drive = $i.Properties.Item("Caption").Value
        }
    }
}

If ($radioButtonOne.Checked){                                                    # Bouton radio "32-Bit" sélectionné
    # "32-BIT"                                                                   # choix architecture x32
    New-Item -Path $drive -Name "Images" -ItemType directory | Out-Null          # création d'un dossier "Images"
    New-Item -Path "$drive\Images" -Name "32-BIT" -ItemType directory | Out-Null # création d'un sous-dossier "32-Bit"
    New-Item -Path $drive -Name "Owner Files" -ItemType directory | Out-Null     # création d'un sous-dossier "Owner Files"
    }
Elseif($radioButtonTwo.Checked){                                                 # Bouton radio "64-Bit" sélectionné
    # "64-BIT"                                                                   # choix architecture x64
    New-Item -Path $drive -Name "Images" -ItemType directory | Out-Null          # création d'un dossier "Images"
    New-Item -Path "$drive\Images" -Name "64-BIT" -ItemType directory | Out-Null # création d'un sous-dossier "64-Bit"
    New-Item -Path $drive -Name "Owner Files" -ItemType directory | Out-Null     # création d'un sous-dossier "Owner Files"
 }
}

# recopie tous les fichiers d'un dossier vers un lecteur
#
Function do_CopyFiles($diskLetter, $folder){                               

  $FOF_CREATEPROGRESSDLG = "&H0&"
  $objShell = New-Object -ComObject "Shell.Application"                    # objet shell.application
  $objFolder = $objShell.NameSpace($diskLetter)
 
    if(Test-Path -Path $folder){                                           # vérifie si le dossier existe
	$folder = $folder + "\*.*"
        $objFolder.CopyHere($folder, $FOF_CREATEPROGRESSDLG)

    do_CreateImageContainer                                                # appel de fonction création structure dossiers

    }  
    else{
        [System.Windows.Forms.MessageBox]::Show("Folder does not exist!")  # boite de message "Le dossier n'existe pas !"
    }
}

# pour la synthèse vocale
# 
# $msg est le message vocal à prononcer via l'interface vocale
#
Function do_ReadMessage($msg){
Add-Type -AssemblyName System.Speech                                       # ajoute prise en charge assembly voix
$synthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
$synthesizer.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo }
$synthesizer.Speak("$msg")
}

# Initialisation du lecteur (diskpart /s), MakeBootable.txt contient le scénario de partitionnement personnalisé
#
# Création d'un fichier temporaire MakeBootable.txt pour stocker le script à exécuter
# avec la commande Diskpart /s
# Création d'un fichier temporaire FindDiskLetter.txt pour sotcker le script à exécuter
#
Function do_InitializeDrive($diskNumber) {
NEW-ITEM $env:TEMP -Name MakeBootable.txt -ItemType file -force | OUT-NULL                     # Fichier script MakeBootable.txt
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "SELECT DISK $diskNumber"                  # on sélectionne le disk
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "CLEAN"                                    # on efface tout !!
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "CREATE PARTITION PRIMARY size=4096"       # on créé une partition primaire de 4Go
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "FORMAT FS=Fat32 QUICK LABEL=""WinPE"" "   # on la formate en FAT32 et on la nomme WinPE
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "ASSIGN"                                   # on assigne une lettre logique
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -value "ACTIVE"                                   # on active la partition
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "CREATE PARTITION PRIMARY"                 # on créé une nouvelle partition primaire
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "FORMAT FS=NTFS QUICK LABEL=""IMAGEDATA"" "# on la formate en NTFS et on la nomme IMAGEDATA
ADD-CONTENT -Path $env:TEMP\MakeBootable.txt -Value "ASSIGN"                                   # on assigne une lettre logique
DiskPart /s $env:TEMP\MakeBootable.txt | Out-Null                                              # exécute le script Diskpart /s MkeBootable.txt

New-Item -Path $env:TEMP -Name FindDiskLetter.txt -ItemType File -Force | Out-Null             # Fichier script FindDiskLetter.txt
Add-Content -Path $env:TEMP\FindDiskLetter.txt "List disk"                                     # on list les disks pour indication
Add-Content -Path $env:TEMP\FindDiskLetter.txt "Select disk $diskNumber"                       # on sélectionne le disk
Add-Content -Path $env:TEMP\FindDiskLetter.txt "Detail disk"                                   # on affiche ses détails
$detailDisk = (DiskPart /s $env:TEMP\FindDiskLetter.txt)                                       # exécute le script Diskpart /s FindLetter.txt
$driveLetter = $detailDisk[-2].Substring(15,1) + ":"
    if("$($Script:folderPath)\Media") {                                                        # présence d'un dossier Media ? (au niveau répertoire script)
        do_CopyFiles -diskLetter $driveLetter -folder "$($Script:folderPath)\Media"            # si oui, on recopie son contenu
    }
}

Function do_RunAction {
#$answer= [System.Windows.Forms.MessageBox]::Show("Do you want to perform this action?" , "Create External USB Bootable Drive" , 4)
$answer= [System.Windows.Forms.MessageBox]::Show("Voulez vous exécuter cette action?" , "Création d'un lecteur USB externe bootable" , 4)
if ($answer -eq "YES" ) {
    for($i=0;$i -lt $viewDataGrid.RowCount;$i++){ 
        if($viewDataGrid.Rows[$i].Cells['Select'].Value -eq $true){
            $diskNumber = $viewDataGrid.Rows[$i].Cells['DiskNumber'].Value
            #[System.Windows.Forms.MessageBox]::Show("Selected: $diskNumber")
            do_StartLabel
            do_InitializeDrive($diskNumber) | Out-Null
            do_ChangeLabel
            #do_ReadMessage -msg "External USB Bootable Media Created"            
            do_ReadMessage -msg "Le support de démarrage externe usb est créé"
         }    
    }
            
 }  
 else { 
       #[System.Windows.Forms.MessageBox]::Show("You have canceled Run action.")
       [System.Windows.Forms.MessageBox]::Show("Vous avez annulé l'action en cours.")
 }      
    #
    $sourceTextbox.Text = ""
    $objform.refresh
}

Function do_CloseForm {
    $objform.Close()
}

# Représentation graphique d'une icône encodée en base 64
#
$AI48Icon = [System.Convert]::FromBase64String(
"AAABAAEAMDAAAAEAIACoJQAAFgAAACgAAAAwAAAAYAAAAAEAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD////////////////////////////////////////////////////////////////+/v7//f39//r5+f/59/f/+Pb1//b08//28/L/+PPw//z38v/+/vz//v7+//7+/v/+/vz//v76//7++v/+/vz//v7+///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/v7//v79//37+f/7+Pb/9/Tz//Xx8P/z7uz/9e7n//vx5//+/PH//v75//7++P/+/vf//v71//7+9//+/v7//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////v7+//79+v/9+/f/+fXx//Xv6v/07OX/9evi//vt4f/++On//v7w//7+8P/+/vD//v3v//7+9f/+/v7//////////////////////////////////////////////////v7+//7+/v/+/v7//////////////////////////////////////////////////////////////////////////////////////////////////////////////////v7+//7+/v/+/v7//fv5//rz7v/47+b/+e3h//zu4P/+9ef//vvs//766//++On//vXn//747v/+/v7////////////////////////////////////////////+/v7/+fj4//X29v/8/Pz//v7+///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/////v7+//7+/f/++/f//fbs//3w4//98+X//vbn//7z4//+8eL//u/g//3y5//+/f3//////////////////v7+////////////////////////////+Pf3//X09P/7+/v//v7+//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7////+/////v7//v7+//78+P/99+z//O7g//zs3P/66tr/+ejZ//nr3//+/Pr//v7+//7+/v/7+vn/8vDw//X09P/9/f3//v7+/////////////Pv7//z8/P/+/v7///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////7+/v/69/X/4tnS/+baz//s3dH/79/S//Dj1//69fL/+fj3//Du7f/k4uH/3tzc/9/d3f/m5eX/8fDw//n5+f/+/v7//v7+//7+/v/////////////////////////////////////////////////////////////////////////////////////////////////+/v7/+/v7//7+/v/////////////////////////////////////////////////39vb/y8fG/8vGw//QycP/187G/+DWzP/p5eH/4d/e/9nY1//X1dT/19XU/9vZ2P/d3Nz/39zc/+Ti4f/28vH//v7+//////////////////////////////////////////////////////////////////////////////////////////////////7+/v/y8vL/5OTk//z8/P/////////////////////////////////////////////////19PT/wL28/766uf++urn/wby6/8rDvf/SzMf/zsrJ/87Lyv/Pzcz/0M7N/9PR0P/X1dT/29jV/+Pe2v/t6OP/+ff2///////////////////////////////////////////////////////////////////////////////////////+/v7/+/v7/+rq6v/b2tr/2NfX//r6+v////////////7+/v/+/v7//Pz8//v7+//6+vr/+Pj4//j4+P/v7u3/s6+u/7Kurf+zr67/uLKv/8K5sf/Kv7b/xr64/8W/u//HwsD/ycXE/8zJyP/W0c7/39jT/+Hc2P/k4eD/7+7u//7+/v////////////////////////////////////////////////////////////////////////////7+/v/8/Pz/5eTk/9jW1v/V0tH/zszM//b29v/8/Pz/9PT0/9LS0v++vr7/tLS0/7u7u//Y2Nj/5OTk/+np6f/k5OT/p6Oj/6ejof+qpKH/saih/7itpP/Cs6f/v7Sp/7+1rP/BuLH/xb24/8W/vP/SzMj/1NHO/9fV1f/e3Nz/6Obm//z8/P////////////////////////////////////////////////////////////////////////////7+/v/19fX/3t3d/9/Z1P/d1M3/zsjE/+7t7P/n5+f/urq6/8vLy//t7e3/6Ojo/9fX1/+2trb/ra2t/76+vv/T0tL/m5WS/56YlP+impP/pZuT/6qflf+3p5n/t6eb/7eqn/+7saf/wLat/7q0sP/FwsH/y8jH/9DOzv/X1dX/4N7e//f39//+/v7///////////////////////////////////////////////////////////////////////7+/v/5+fn/7Ovr/+vg2P/p2cn/18q//9PS0f+0tLT/39/f//Ly8v/y8vL/7+/v/+7u7v/r6+v/5OTk/8vLy/+tra3/g3x3/5CHgP+UioP/l42E/5uPhP+qmor/r56R/7Ojl/+ypJn/rqKX/6ihnP+2s7L/vry7/8XDwv/Ny8v/1tTU/+zr6//4+Pj//Pz8//7+/v/+/v7////////////////////////////////////////////////////////////+/v7//Pv7/+/l3P/by73/vLKo/7y7uv/s7Oz/9PT0//X19f/z8/P/7u7u/+7u7v/u7u7/7Ozs/+rq6v/l5OT/bmZg/3hvZ/+Adm7/hnxy/42AdP+hkID/o5OD/6GQgv+ej4H/nY6C/5aOh/+mo6L/r62s/7i2tf/Bv77/y8nI/9/e3v/t7e3/8/Pz//f39//8/Pz//v7+/////////////////////////////////////////////////////////////v7+/+jh2v+4rqb/lZGO/+Tk5P/09PT/9fX1//X19f/z8/P/7+/v/+/v7//u7u7/7Ozs/+rq6v/p6en/ZV1W/2VaUv9rYVj/dGhe/3dpXf+CcWH/j35t/4x8bP+OfW//jn1w/4Z7cv+TkI//nZmY/6Cenf+hn57/jo2M/6WkpP+4uLj/zMzM/+rq6v/19fX//f39/////////////////////////////////////////////////////////////f39/9XS0P+hnpz/jImI/+jo6P/19fX/9fX1//X19f/09PT/8PDw/+/v7//u7u7/7Ozs/+rq6v/q6ur/YVdQ/1VLQv9YTEP/TUA0/0cuF/90Rhr/bEck/2NLNP9sXEz/eWhb/3hrYf+Cf37/iYWE/3t5eP9+fHv/oZ+e/8nIyP/u7u7/1NTU/7m5uf++vr7/6+vr//7+/v////////////////////////////////////////////7+/v/8/Pz/7Orq/8jGxv+koqH/k5CP/+vq6v/29vb/9vb2//f39//29vb/8vLy/+/v7//t7e3/7Ozs/+vr6//p6en/XlVN/0I3Lf84KBn/QyYK/1QvC/99Sxn/hlEe/3hHFv9nPRX/WDsg/1ZGOP9lY2L/bmtq/46Liv+koaD/q6mo/8TCwv/29vb/9vb2//T09P/n5+f/09PT/////////////////////////////////////////////v7+//v7+//s6+v/393d/8LAwP+ioJ7/lZSS/+zs7P/39/f/9/f3//r6+v/+/v7//f39//j39//x8fH/7e3t/+vr6//p6en/TkU//zMeC/9BJAn/SCkJ/1MuCf94Rxf/hVIg/3lIF/90RRb/bkAU/146F/9eW1r/joqI/5uXlf+hnZz/qKWk/7q5uP/39/f/9/f3//j4+P/39/f/9/f3//7+/v///////////////////////////////////////v7+//Hw8P/l4+P/3dvb/8G/v/+joaH/lpSU/+7u7v/5+fn//f39//7+/v/+/f3/+vr5//n18//69/b/+Pb1//Pz8v/t7ez/TUA2/zgbAv89IAX/RCUH/04rCP9xQxf/g1Ij/3RFGP9sPxL/bEAV/3NNKf91cm//jIiE/5GMif+Xk5D/n5uZ/66sq//29vb/+Pj4//n5+f/4+Pj/+fn5//7+/v///////////////////////////////////////v7+/+rp6f/g39//2NbW/768vP+hn5//k5GR//Ly8v/9/f3/+fj4//Du7v/m5OP/393c/9rV0v/Z087/1M3I/8G7tv+ej4H/YEIn/z0eBP86HAL/Ph8B/0YjAf9oPhT/e08k/2k/Fv9vRyH/lX5p/8rGxP/x8fH/0M7N/6unpf+RjIn/k46K/6CbmP/x8fH/+fn5//n5+f/5+fn/+fn5//39/f///////////////////////////////////////v7+/+fn5//d3Nz/09PT/7e2tv+WlZX/kpCQ/6impf/Ivrb/1dHO/9LPzv/IxsX/v728/7exrf+qpJ7/hXpw/3ZUNP+UXSf/m2Eo/5phK/98TSD/WzUS/0MiA/9dNxP/dE8t/4NsVv+yrKf/xMLC/87MzP/29vb/+Pj4//f49//u7e3/ycfG/6Whn//r6+v/+vr6//n5+f/5+fn/+Pj4//39/f///////////////////////////////////////v7+/+Xl5f/T09P/r6+v/5WVlf+zsrL/5ubm/8LAwP+xo5X/o4du/5mBbP+bj4T/nJiV/4R9ef9rUz7/g1Mj/5RcJv+aYSr/m2Ep/59lLf+eZS3/mWMu/45dL/9rRiP/lIuF/7Owr/+8urn/xMLB/8zKyv/09PT/+fn5//n5+f/5+fn/+fn5//Dv7//5+Pj//v7+//39/f/7+/v/+fn5//z8/P///////////////////////////////////////Pz8/8nJyf+1tbX/39/f//Dw8P/4+Pj/6enp/8nHx//Avr3/uri3/6+sqv+VjIX/altP/3lVM/+TYTH/klwp/5FcKP+WYCv/m2Ep/6BlLf+gZi7/mGAq/4ZSH/9rQhn/lY6I/7awrP/Au7j/xsPB/8zKyf/x8fH/+Pj4//j4+P/5+fn/+vr6//f29v/w7u3//fz8/////////////v7+//39/f//////////////////////////////////////9fX1/83Nzf/s7Oz/9/f3//j4+P/5+fn/5+fn/8TCwf+6uLf/srCv/6qnpv+gm5f/eHRx/29GH/+LWiz/l2Y2/5poOv+aZzf/mmEp/55jK/+WWiH/jVMb/4VPGv9vQhf/j4eA/7awq//CvLj/ycS//87Ixf/u7u3/+Pj4//j4+P/5+fn/+fn5//j4+P/p5+f//Pv7/////////////v7+//7+/v//////////////////////////////////////+/v7//Hx8f/29vb/+vr6//n5+f/6+vr/5uXl/727u/+xr67/qKSh/6Galv+Zk47/d3Jw/2tDH/+AUib/glQo/4FUKf+JWi7/mmIq/5dbI/+QVBz/j1Qb/4hQGv9yRBf/iYB4/7Wvqv/CvLf/ycO+/83IxP/s6ur/9/f3//j4+P/4+Pj/+fn5//n5+f/u7Ov//v7+/////////////////////////////////////////////////////////////Pz8//Hx8f/29vb/+vr6//n5+f/6+vr/5OPj/7m3tv+ln5z/n5mV/7Gsqf/k4+L/3d3d/7Sklf+XeFr/eVEu/3VNKP97USv/mWEr/5hcJP+QVBz/kFQb/4tSGv93Rhf/hHlw/7exrP/Dvbj/ysS//87JxP/r6un/+vr6//n5+f/4+Pj/+Pj4//j4+P/39fT//v7+////////////////////////////////////////////////////////////+/v7//Ly8v/29vb/+vr6//n5+f/6+vr/4N/f/6+srP+loJ3/1tXU//b39//39/f/9fX1//Pz8//y8vL/6+nn/8W6sP+bh3X/lGQ2/5dcJP+QVBv/kFQa/45TGf98SRf/gXRp/7mzrv/Fv7r/0s3J/+ro5v/9/f3//v7+//39/f/7+/v/+fn5//j4+P/49/T/////////////////////////////////////////////////////////////////+/v7//Ly8v/39/f/+vr6//r6+v/7+/v/3d3d/8/Ozv/z8/P/+Pj4//n5+f/4+Pj/9PT0//X19f/19fX/9PT0//T09P/z8/P/w6eN/4tGBP+RTAn/j1AR/49SGP+GThf/g3Nl/8XAu//o5uT//f39//7+/v////7////+///////+/v7//v7+//z9/P/39fH/////////////////////////////////////////////////////////////////+/v7//b29v/6+vr/+/v7//39/f/+/v7//v7+//n5+f/6+vr/+fn5//n5+f/4+Pj/9PT0//X19f/29vb/9fX1//X19f/19fX/yK6W/4dCAP+PRQD/kEUA/49GAf9/Qgj/lYNy/9vX1P/u6uf/9fLu//f08P/49vP/+/v6//z7+//5+Pj/3tTL/7qeg//Htqb/9fX1//n5+f/9/f3//v7+/////////////////////////////////////////////v7+//7+/v/8/Pz//v7+/////////////v7+//r6+v/5+fn/+Pj4//j4+P/39/f/9PT0//X19f/29vb/9vb2//b29v/29vb/x7Ge/3o7AP+APQD/bzQB/1EmAf9RJgH/fUcU/3tQJv98X0P/jn5w/62lof/KxL//1tPQ/7WroP+WgW3/p5aH/8vHxP/d3Nv/9fT0//j4+P/09PT/9fX1//j4+P/9/f3//////////////////////////////////////////////////v7+//n28v/9/v7//v7+//r6+v/5+fn/+fn5//j4+P/29vb/9fX1//X19f/29vb/9/f3//b29v/29vb/wrWq/1AmAv9DIQP/RyEB/10sAP9rMwD/hksT/5heJf+UWiP/j1ch/4BQIf92Vjn/bVhH/5WNhf/Bvr3/0tDP/9rY1//h397/9PPz//n4+f/4+Pj/9/f3//f39//5+fn//v7+/////////////////////////////////////////////f79/9Gebf/Qn3P/3Lye//n5+P/5+fn/+fn5//n5+f/39/f/9fX1//b29v/29vb/9/f3//b29v/29vb/w7u3/y0WAv9JJAL/VioC/2EvAf9uNAD/hUoR/5pfJ/+bXyf/nmMs/5lgKf+GUh7/hnBc/6+ppP/CvLj/z8vI/9nV1P/h3t3/8fDw//j4+P/4+Pj/+Pj4//n5+f/6+vr//v7+///////+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/v7//f79/9Gbav/IjFb/u4JN//r5+P/5+fn/+fn5//n5+f/7+/v/9/f3//f39//39/f/9/f3//b29v/29vb/zMS+/zcaAv9TJwD/WywA/2QxAP9qNAH/gkgQ/59lLf+ZXSX/lFcf/5JXH/+JUh7/iG1T/66opP/Dvbj/z8nE/9fRzP/d2NP/7erp//j4+P/4+Pj/+Pj4//n5+f/5+fn//v7+//7+/v///////////////////////////////////////f38/7GBVP+hZzH/p284//r6+P/6+vr//Pz8//7+/v////////////7+/v/+/v7//Pz8//r6+v/5+fn/1c3I/zobAv9ZKgD/Yi8A/2wzAP9yOAD/hEgO/51jK/+TVx//lVgg/5NXH/+LUx3/iGlL/6ulof/GwLv/083I/9rUz//h29b/7Ojm//f39//4+Pj/+Pj4//j4+P/4+Pj//v7+//////////////////////////////////7+/v/6+vr/9PT0/7Gqpf+Ddmv/emVT//v8+//+/v7//v7+/////////////////////////////v7///7+/v/9/fz/vK6h/zwcAv9dLAD/aTMA/3U5AP98PAD/hkgL/55jK/+UVx//k1cf/5NXH/+OVB3/hWpN/6ehnf/Iwr3/19HM/+Da1f/l39v/7Ojm//j4+P/4+Pj/9/f3//j4+P/39/f//v7+////////////////////////////+/v7//T09P/19fX/9vb2/8a+uv+vpp//pZuV/8S/u//e1cz/9e/o//79/f/+/v7//v7+//7+/v/+/v7/+Pb0/8awm/+EWC7/XS0B/z8fA/9mMQD/dzoA/4A+AP+CPwD/hUYJ/51kLP+UVx//lFcf/5RXIP+SVh7/i2pL/6Wgm//PycT/3tjT/+fh3P/s5eL/8u/u//v7+//5+fn/9/f3//j4+P/4+Pj//f39///////+/v7//v7+//7+/v/+/v7/+fn5//f39//4+Pj/+Pj4/8fDwP+zrqr/qqOe/6CZlf+wj3L/wodR/8aSY//SrYn/3sex/+PYzP+/oYP/iE8Y/34+AP94PAD/aDMB/0QhA/9yOAD/gkAA/4RCAP+ZWRv/yI1W/9GYYv+yeED/mV4m/5NXH/+UWB//kWpE/6mjn//c1tH/7Ofj//fz8f/8+/r//v7+//7+/v/+/v7//f39//z8/P/5+fn//Pz8//7+/v/////////////////+/v7/+vr6//f39//4+Pj/+fn5/83Kx/+6trX/sayq/6mkn/+1lHb/wYZQ/7+DTf/NlF7/6rR+//XAiv/cpnD/vYNJ/6BjJ/+GRgj/eDwA/1AnA/+IRgf/tHU5/+Orc//9yZP//sqU//7LlP/+y5T/+8iS/+izfP/Nl1//to5k/9PQzf/59/b//v7+//7+/v/////////////////////////////////+/v7//v7+///////////////////////+/v7/+fn5//f39//4+Pj/+fn5/9jU0//HxML/v7q4/7awrP+7m33/159p//K+iP/+zJb//syU//3Mlf/+zJb//syW//7Mlf/5yJH/2adw/7+NWv/ntoD/8cKM//vLlf/9zJb//syW//7Mlv/+zJf/98aR/9WlcP+0gUz/v5t3//7+/v/////////////////////////////////////////////////////////////////////////////////+/v7/+Pj4//b29v/39/f/+fn5/+Lg3P/W09D/z8vI/8fCvv++tq//vKyb/7qYc//To27/7b2J//zNmP/+zZj/+MmV//LEkP/0xJD//cyY//7Omf/+zZn//MyX//PEj//vwo3/7MCL/+Cyff+7h1H/o2oz/6JoMf+jajL/uo5k//7+/v/////////////////////////////////////////////////////////////////+/v7//v7+//7+/v//////+fn5//f39//4+Pj/+vr6//Ty8P/s6OX/5ODe/97Z1f/Uzcj/vbSt/4xuUf+YXCP/nWIp/7V+Rv/lt4H/7MCM//HFkP/2ypX//tGb//7Qmv/+0Jr//dGb//HGkf/wxI//8sWQ//3Pm//2x5H/4K94/8yWYP+3f0j/tIRV//7+/v/+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/v7//v7+//7+/v//////////////////////+fn5//z8/P/+/v7///////7+/v/+/v7//f39//v5+P/18u//5+Db/6OAXf/CjFT/6bmD//7Rm//+0pz//tGc//7Snf/5zZj/8ceS//DNn//w2Lj/6smf//rRnv/+0p3//tKd//7Snf/+0p3//tKd//vXqf/44sX/+PHn//3+/v///////////////////////////////////////////////////////////////////////////////////////v7+//7+/v/////////////////////////////////+/v///v7+//r27//88N7//OfK//zft//816b//dSf//zWpP/85ML//PTl//7+/P/5+fn/6Obm/+3p5v/v5tv/9+bP//rhvv/65cj/9e3i//T08//19fX/+/v7//7+/v/////////////////////////////////////////////////////////////////+/v7//v7+//7+/v///////v7+//7+/v/+/v7//v7+/////////////v7+///////+/v7//v7+//7+/v/+/v7//v7+//7+/v/+/vz//fnx//38+f/+/v7//v7+//7+/v/9/f3/+fj4//z8/P/+/v7//v7+//7+/v/+/v7//v7+//7+/v/9/f3//v7+///////+/v7//v7+//7+/v/+/v7////////////+/v7///////7+/v/+/v7//v7+//7+/v///////////////////////////////////////////////////////////////////////////////////////////////////////v7///7+///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////+/v7///////7+/v///////v7+//7+/v/+/v7//v7+//7+/v/+/v7////////////+/v7//v7+///////+/v7//v7+///////+/v7///////7+/v/+/v7//v7+//7+/v/+/v7//v7+/////////////v7+//7+/v///////v7+//7+/v///////v7+///////+/v7//v7+//7+/v/+/v7//v7+//7+/v////////////7+/v/+/v7///////7+/v////////+g+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPkAAAAAAACg+QAAAAAAAKD5AAAAAAAAoPk=
")

$AIicon = [System.Convert]::FromBase64String(
"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")

# =================================================================
# Create a Form
# =================================================================

$objForm = New-Object System.Windows.Forms.Form
#$objForm.Text = "    WWW.AlexComputerBubble - Create UEFI Bootable External USB Drive ( WIM & FFU Images )"
$objForm.Text = "    WWW.AlexComputerBubble - Création d'un lecteur USB externe bootable compatible UEFI ( WIM & FFU Images )"
$objForm.Size = New-Object System.Drawing.Size(1000,550)
$objForm.StartPosition = "CenterScreen"
$objForm.Icon = $AI48Icon
$objForm.KeyPreview = $True

# Create a ToolTip
$tooltipinfo = New-Object 'System.Windows.Forms.ToolTip'

# Form Tabs
# =================================================================
# Create the tabcontrol
$tabcontrol = New-Object windows.Forms.TabControl
$tabpage_One = New-Object windows.Forms.TabPage
$tabpage_Two = New-Object windows.Forms.TabPage

$tabcontrol.Font ="Calibri, 12pt style=Bold"
$tabcontrol.Anchor = 'Top, Bottom, Left, Right'
$tabcontrol.ItemSize = '100,25'
$tabcontrol.Padding = '15,5'
$tabcontrol.Location = '20, 20'
$tabcontrol.width = 940
$tabcontrol.Height = 460

# Tab One
# ================================================================
#$tabpage_One.Text = "First Step"
$tabpage_One.Text = "Première étape"
$tabpage_One.Location = '20, 15'
$tabpage_One.Padding ='3,3,3,3'
$tabpage_One.Size = '940, 460'
$tabpage_One.BackColor = "White"
$tabpage_One.BackgroundImageLayout = "None"
$tabpage_One.TabIndex = 0

# GroupBox for creation of Media files
$groupBoxMediaFiles = New-Object System.Windows.Forms.groupBox
$groupBoxMediaFiles.Location = '20, 20'
$groupBoxMediaFiles.Name = "groupCapture"
$groupBoxMediaFiles.Size = '880, 375'
$groupBoxMediaFiles.TabStop = $False
$groupBoxMediaFiles.BackColor = "Transparent"
#$groupBoxMediaFiles.Text = "Create Bootable Media Files:"
$groupBoxMediaFiles.Text = "Création d'un support fichiers bootable:"

# Add Message Label to the Tab
$bitSelectionLable = New-Object System.Windows.Forms.Label
$bitSelectionLable.Location = New-Object System.Drawing.Size(20,50)
$bitSelectionLable.Size = New-Object System.Drawing.Size(500,20)
$bitSelectionLable.Font = "Calibri, 10pt"
#$bitSelectionLable.Text = “1: Click the radion button to select 32-Bit or 64-Bit"
$bitSelectionLable.Text = “1: Cliquer sur le bouton radio afin de sélectionner 32-Bit ou 64-Bit"

# Create first radiobutton
$radioButtonOne = New-Object System.Windows.Forms.Radiobutton
$radioButtonOne.text = "32-BIT"
$radioButtonOne.Font = "Calibri, 10pt"
$radioButtonOne.height = 20
$radioButtonOne.width = 100
$radioButtonOne.top = 100
$radioButtonOne.left = 40
#$radioButtonOne.add_click({do_SelectArch})

# Create second radiobutton
$radioButtonTwo = New-Object System.Windows.Forms.Radiobutton
$radioButtonTwo.text = "64-BIT"
$radioButtonTwo.Font = "Calibri, 10pt"
$radioButtonTwo.height = 20
$radioButtonTwo.width = 100
$radioButtonTwo.top = 100
$radioButtonTwo.left = 200
#$radioButtonTwo.add_click({do_SelectArch})

# Input PictureBox First Tab
$inputPicture = New-Object System.Windows.Forms.PictureBox
$inputPicture.Location = '650, 35'
$inputPicture.Width = "150"
$inputPicture.Height = "150"
$inputPicture.BackColor = "Transparent"
$inputPicture.SizeMode = "Normal" # "Zoom" , "AutoSize", "CenterImage", "Normal"
$inputPicture.Image = $AIicon

# Add Message Label to the Tab
$sourceFolderLabel = New-Object System.Windows.Forms.Label
$sourceFolderLabel.Location = New-Object System.Drawing.Size(20,150)
$sourceFolderLabel.Size = New-Object System.Drawing.Size(830,20)
$sourceFolderLabel.Font = "Calibri, 10pt"
#$sourceFolderLabel.Text = “2: Click the Browse Source button to select the folder named 'WinPE10-UEFI-BootExternalUSBDrive'.”
$sourceFolderLabel.Text = “2: Cliquer sur le bouton Browse Source afin de sélectionner le dossier nommé 'WinPE10-UEFI-BootExternalUSBDrive'.”

# Add Text Box to the Tab
$sourceTextbox = New-Object System.Windows.Forms.TextBox
$sourceTextbox.Location = New-Object System.Drawing.Size(20,200)
$sourceTextbox.Size = New-Object System.Drawing.Size(500,20)
$sourceTextbox.Font = "Calibri, 11pt"

# Add Button to select folder
$sourceBrowseButton = New-Object System.Windows.Forms.Button
$sourceBrowseButton.Location = New-Object System.Drawing.Size(650,200)
$sourceBrowseButton.Size = New-Object System.Drawing.Size(150,25)
$sourceBrowseButton.TabIndex = 0
$sourceBrowseButton.Font = "Calibri, 10pt"
$sourceBrowseButton.Text = “Browse Source”
$sourceBrowseButton.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($sourceBrowseButton, "Click this button to select the folder named 'WinPE10-UEFI-BootExternalUSBDrive'")
$tooltipinfo.SetToolTip($sourceBrowseButton, "Cliquez sur ce bouton afin de sélectionner le dossier nommé 'WinPE10-UEFI-BootExternalUSBDrive'")
$sourceBrowseButton.Add_Click({Select-Folder -message "Select Source Folder" -path "" -source 1})

# Add Message Label to the Tab
$searchFolderLabel = New-Object System.Windows.Forms.Label
$searchFolderLabel.Location = New-Object System.Drawing.Size(20,250)
$searchFolderLabel.Size = New-Object System.Drawing.Size(550,20)
$searchFolderLabel.Font = "Calibri, 10pt"
#$searchFolderLabel.Text = “3: Click the Start button to start creating folders for UEFI external Drive.”
$searchFolderLabel.Text = “3: Cliquez sur le bouton start pour la création des dossiers sur le lecteur UEFI externe.”

# Add Button to create media files
$createMediaFilesButton = New-Object System.Windows.Forms.Button
$createMediaFilesButton.Location = New-Object System.Drawing.Size(650,250)
$createMediaFilesButton.Size = New-Object System.Drawing.Size(150,25)
$createMediaFilesButton.TabIndex = 1
$createMediaFilesButton.Font = "Calibri, 10pt"
$createMediaFilesButton.Text = “Start”
$createMediaFilesButton.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($createMediaFilesButton, "Click this button to start creating Media Files for UEFI bootable USB Drive")
$tooltipinfo.SetToolTip($createMediaFilesButton, "Cliquer sur ce bouton start pour la création des fichiers Media Files pour le lecteur UEFI bootable")
$createMediaFilesButton.Add_Click({do_CreateMediaFiles})

# Label Wait for Command line window
$labelWaitForCommLineWindow = New-Object System.Windows.Forms.Label
$labelWaitForCommLineWindow.Font = "Calibri, 11pt, style=Bold"
$labelWaitForCommLineWindow.Location = New-Object System.Drawing.Point(20, 300)
$labelWaitForCommLineWindow.Size = New-Object System.Drawing.Size(550, 25)
$labelWaitForCommLineWindow.Text = ""
$labelWaitForCommLineWindow.TextAlign = "MiddleCenter"

# Label Info about script action
$labelInfoAboutScriptAction = New-Object System.Windows.Forms.Label
$labelInfoAboutScriptAction.Font = "Calibri, 11pt, style=Bold"
$labelInfoAboutScriptAction.Location = New-Object System.Drawing.Point(20, 330)
$labelInfoAboutScriptAction.Size = New-Object System.Drawing.Size(550, 25)
$labelInfoAboutScriptAction.Text = ""
$labelInfoAboutScriptAction.TextAlign = "MiddleCenter"

# Add Button to exit application
$exitButtonOne = New-Object System.Windows.Forms.Button
$exitButtonOne.Location = New-Object System.Drawing.Size(650,320)
$exitButtonOne.Size = New-Object System.Drawing.Size(150,25)
$exitButtonOne.TabIndex = 1
$exitButtonOne.Font = "Calibri, 10pt"
$exitButtonOne.TabIndex = 1
$exitButtonOne.Text = “Exit”
$exitButtonOne.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($exitButtonOne, "Click this button to exit this application")
$tooltipinfo.SetToolTip($exitButtonOne, "Cliquez sur ce bouton pour quitter cette application")
$exitButtonOne.Add_Click({do_CloseForm})

# Tab Two
# ================================================================
#$tabpage_Two.Text = "Second Step"
$tabpage_Two.Text = "Deuxième étape"
$tabpage_Two.Location = '20, 15'
$tabpage_Two.Padding ='3,3,3,3'
$tabpage_Two.Size = '940, 460'
$tabpage_Two.BackColor = "white"
$tabpage_Two.TabIndex = 1

# GroupBox for creation of USB external drive
$groupBoxUsbDrive = New-Object System.Windows.Forms.groupBox
$groupBoxUsbDrive.Location = '20, 20'
$groupBoxUsbDrive.Name = "groupCapture"
$groupBoxUsbDrive.Size = '880, 375'
$groupBoxUsbDrive.TabStop = $False
$groupBoxUsbDrive.BackColor = "Transparent"
#$groupBoxUsbDrive.Text = "Make External USB Drive Bootable:"
$groupBoxUsbDrive.Text = "Créer un lecteur USB externe démarrable:"

# List USB drives Label
$labelListDisk = New-Object System.Windows.Forms.Label
$labelListDisk.Font = "Calibri, 10pt"
$labelListDisk.Location = New-Object System.Drawing.Size(20,40)
$labelListDisk.Size = New-Object System.Drawing.Size(270,25)
#$labelListDisk.Text = “List of the avalilable Drives:”
$labelListDisk.Text = “List des lecteurs disponibles:”

# Add Grid View to the Tab
$viewDataGrid = New-Object System.Windows.Forms.DataGridView
$viewDataGrid.Name = "ListDiskPartResult"
$viewDataGrid.Font = "Calibri, 10pt"
$viewDataGrid.TabIndex = 0
$viewDataGrid.Location = New-Object Drawing.Point 20,70
$viewDataGrid.Size = New-Object Drawing.Point 540,200
$viewDataGrid.AutoSizeColumnsMode = 'AllCells'  # 'Fill'
$viewDataGrid.MultiSelect = $false
$viewDataGrid.RowHeadersVisible = $false
$viewDataGrid.ColumnHeadersVisible = $true
$viewDataGrid.allowusertoordercolumns = $true

# Message Label Action
$messageForActionLabel = New-Object System.Windows.Forms.Label
$messageForActionLabel.Font = "Calibri, 11pt, style=Bold"
$messageForActionLabel.Location = New-Object System.Drawing.Size(50,300)
$messageForActionLabel.Size = New-Object System.Drawing.Size(380,25)
$messageForActionLabel.Text = “”

# Input PictureBox Second Tab
$inputPicSecondTab = New-Object System.Windows.Forms.PictureBox
$inputPicSecondTab.Location = '650, 50'
$inputPicSecondTab.Width = "150"
$inputPicSecondTab.Height = "150"
$inputPicSecondTab.BackColor = "Transparent"
$inputPicSecondTab.SizeMode = "Normal" # "Zoom" , "AutoSize", "CenterImage", "Normal"
$inputPicSecondTab.Image = $AIicon

# Button List USB drives
$buttonViewDisk = New-Object System.Windows.Forms.Button
$buttonViewDisk.Location = New-Object System.Drawing.Size(650,240)
$buttonViewDisk.Size = New-Object System.Drawing.Size(150,25)
$buttonViewDisk.TabIndex = 3
$buttonViewDisk.Font = "Calibri, 10pt"
$buttonViewDisk.Text = “View Drive(s)”
$buttonViewDisk.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($buttonViewDisk, "Click this button to view all available Drives connected to your computer")
$tooltipinfo.SetToolTip($buttonViewDisk, "Cliquer sur ce bouton pour afficher tous les lecteurs disponibles de votre ordinateur")
$buttonViewDisk.Add_Click({do_ListDiskPartResult})

# Button Run action
$buttonRun = New-Object System.Windows.Forms.Button
$buttonRun.Location = New-Object System.Drawing.Size(650,290)
$buttonRun.Size = New-Object System.Drawing.Size(150,25)
$buttonRun.TabIndex = 4
$buttonRun.Font = "Calibri, 10pt"
$buttonRun.Text = “Run”
$buttonRun.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($buttonRun, "Click this button to create UEFI Bootable USB External Drive")
$tooltipinfo.SetToolTip($buttonRun, "Cliquer sur ce bouton pour créer un lecteur USB bootable UEFI")
$buttonRun.Add_Click({do_RunAction})

# Button Close app
$buttonClose = New-Object System.Windows.Forms.Button
$buttonClose.Location = New-Object System.Drawing.Size(650, 330)
$buttonClose.Size = New-Object System.Drawing.Size(150,25)
$buttonClose.TabIndex = 5
$buttonClose.Font = "Calibri, 10pt"
$buttonClose.Text = “Exit”
$buttonClose.TextAlign = "MiddleCenter"
#$tooltipinfo.SetToolTip($buttonClose, "Click this button to exit this application")
$tooltipinfo.SetToolTip($buttonClose, "Cliquer sur ce bouton pour quitter cette application")
$buttonClose.Add_Click({do_CloseForm})

# Add the controls to the form
# =========================================================
$objForm.Controls.Add($tabcontrol)

# Tab One
$groupBoxMediaFiles.Controls.Add($bitSelectionLable)
$groupBoxMediaFiles.Controls.Add($radioButtonOne)
$groupBoxMediaFiles.Controls.Add($radioButtonTwo)
$groupBoxMediaFiles.Controls.Add($inputPicture)
$groupBoxMediaFiles.Controls.Add($sourceFolderLabel)
$groupBoxMediaFiles.Controls.Add($sourceTextbox)
$groupBoxMediaFiles.Controls.Add($sourceBrowseButton)
$groupBoxMediaFiles.Controls.Add($searchFolderLabel)
$groupBoxMediaFiles.Controls.Add($createMediaFilesButton)
$groupBoxMediaFiles.Controls.Add($labelWaitForCommLineWindow)
$groupBoxMediaFiles.Controls.Add($labelInfoAboutScriptAction)
$groupBoxMediaFiles.Controls.Add($exitButtonOne)
$tabpage_One.Controls.Add($groupBoxMediaFiles)

# Tab Two
$groupBoxUsbDrive.Controls.Add($labelListDisk)
$groupBoxUsbDrive.Controls.Add($viewDataGrid)
$groupBoxUsbDrive.Controls.Add($messageForActionLabel)
$groupBoxUsbDrive.Controls.Add($inputPicSecondTab)
$groupBoxUsbDrive.Controls.Add($buttonViewDisk)
$groupBoxUsbDrive.Controls.Add($buttonRun)
$groupBoxUsbDrive.Controls.Add($buttonClose)
$tabpage_Two.Controls.Add($groupBoxUsbDrive)

# Tabcontrol
$tabcontrol.tabpages.add($tabpage_One)
$tabcontrol.tabpages.add($tabpage_Two)
# Activate the form
# =========================================================
# $objForm.Add_Load({do_Something})
$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()