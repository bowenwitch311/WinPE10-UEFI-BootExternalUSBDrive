# Filename: WinPE50-UEFI.ps1 - www.alexcomputerbubble.com
# Date:     November, 2015
# Author:   Alex Dujakovic 
# Description: PowerShell script to create UEFI boot WinPE
# -------------------------------------------------------------------------------
[CmdletBinding()]
param (
[string] $WinArch
)
# Paths to WinPE folders
# $myFoldersPath est le chemin du fichier WinPE50-UEFI.ps1
# $WinPE_BuildFolder est un dossier temporaire pour la construction du WinPE
# $WinPE_MountFolder est un dossier pour le montage du WinPE
# $WinPE_Drivers est le dossier qui comporte les pilotes supplémentaires
# $WinPE_AppsFiles est le dossier qui comporte les applications supplèmentaires
# $winPE_Images est le dossier de stockage des images WIM ou FFU
# $amd64 dossier relatif en fonction de l'architecture utilisé
# $x86 dossier relatif en fonction de l'architecture utilisé
#
$myFoldersPath = (Get-Location).Path           # répertoire en cours de l'application (script)
$WinPE_BuildFolder = "$myFoldersPath\WinPE50"  # sous-dossier WinPE50, utilisé pour la création du WinPE
$WinPE_MountFolder = "$myFoldersPath\Mount"    # sous-dossier Mount, utilisé comme point de montage du Wim (winpe)
$WinPE_Drivers = "$myFoldersPath\Drivers"      # sous-dossier Drivers, utilisé pour stocker les pilotes (x86/amd64)
$WinPE_AppsFiles = "$myFoldersPath\Apps"       # sous-dossier Apps, utilisé pour stocker des applications compatibles WinPE
$WinPE_Media = "$myFoldersPath\Media"          # sous-dossier Media, version finale du support WinPE
$winPE_Images = "$myFoldersPath\Images"        # sous-dossier Images, utilisé pour stocker des Wims ou FFus
$amd64 = "$WinPE_BuildFolder" + "_amd64"       # utilisé pour l'architecture amd64
$x86 = "$WinPE_BuildFolder" + "_x86"           # utilisé pour l'architecture x86

#
# Synthèse vocale
# $msg est la chaine qu'il faudra rejouer à la voix
#
Function do_ReadMessage($msg){
Add-Type -AssemblyName System.Speech
$synthesizer = New-Object -TypeName System.Speech.Synthesis.SpeechSynthesizer
$synthesizer.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo }
$synthesizer.Speak("$msg")
}

#
# Fabrication du WinPE en fonction de l'architecture x64 ou x32, attention à la version d'ADK modifier en conséquence !
# $ADK_Path contient le chemin vers le kit ADK_Path
# $WinPE_ADK_Path est le chemin vers le WinPE
# $WinPE_OCs_Path est le chemin (en fonction de l'architecture) vers la traduction en fonction du pays et des outils complémentaires
# $DISM_Path est le chemin vers la commande Dism
# $WinPE_BuildFolder est le chemin du résultat final de la construction du WinPE
#
Function Make-WinPEBootWim($WinPE_Architecture){

# Paths to WinPE folders and tools 
$ADK_Path = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$WinPE_ADK_Path = $ADK_Path + "\Windows Preinstallation Environment"
$WinPE_OCs_Path = $WinPE_ADK_Path + "\$WinPE_Architecture\WinPE_OCs"
$DISM_Path = $ADK_Path + "\Deployment Tools" + "\$WinPE_Architecture\DISM"
$WinPE_BuildFolder = $WinPE_BuildFolder + "_" + $WinPE_Architecture

# Functions
#

#
# Supprime un répertoire et les sous-repertoires associés
#
Function Delete-Folder($folderPath){
    try {  # test si le dossier existe déjà (si il existe, on supprime le dossier ainsi que ses fichiers)
        if (Test-Path -path $folderPath) {Remove-Item -Path $folderPath -Force -Recurse -ErrorAction Stop}
    }
    catch{ # petit message si un problème est détecté
        Write-Warning "$folderPath - Error deleting folder!"
        Write-Warning "Error: $($_.Exception.Message)"
        Break
    }
}

#
# Création d'un dossier
#
Function Make-Directory($folderPath){
	if (!(Test-Path -path $folderPath)) {New-Item $folderPath -Type Directory}
}

#
# Permet de monter une image en lecture / écriture dans un dossier de montage d'image
#
Function WinPE-Mount($buildFolder, $mountFolder){
    & $DISM_Path\Imagex.exe /mountrw $buildFolder\winpe.wim 1 $mountFolder
}

#
# Permet de démonter une image avec application des modifications éventuelles
#
Function WinPE-UnMount($mountFolder){
    & $DISM_Path\Imagex.exe /unmount /commit $mountFolder
}

Delete-Folder -folderPath $WinPE_BuildFolder  # Supprime le dossier $WinPE_BuildFolder
Delete-Folder -folderPath $WinPE_MountFolder  # Supprime le dossier $WinPE_MountFolder

Make-Directory -folderPath $WinPE_BuildFolder # créé un nouveau dossier $WinPE_BuildFolder
Make-Directory -folderPath $WinPE_MountFolder # créé un nouveau dossier $WinPE_MountFolder

# Recopie la version en-us du winpe.wim dans le dossier de construction d'image
# ici on ne tient compte que de la version en-us !
#
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\en-us\winpe.wim" $WinPE_BuildFolder  

# Mount folder
# Monte le winpe.wim dans le dossier de montage d'image
#
WinPE-Mount -buildFolder $WinPE_BuildFolder -mountFolder $WinPE_MountFolder

# Add WinPE 5.0 optional components using ADK 8.1 version of dism.exe
# Ajoutes les utilitaires (packages) dans l'ordre suivant:
#
# WinPE-Scripting.cab ainsi que la version en-us WinPE-Scripting_en-us.cab (Le language de script)
# WinPE-WMI.cab ainsi que la version en-us WinPE-WMI_en-us.cab (Le WMI)
# WinPE-MDAC.cab ainsi que la version en-us WinPE-MDAC_en-us.cab (le MDAC)
# WinPE-NetFx.cab ainsi que la version en-us WinPE-NetFx_en-us.cab (Le framework DOTNET 4.0)
# WinPE-PowerShell.cab ainsi que la version en-us WinPE-PowerShell_en-us.cab (Le powershell)
# WinPE-DismCmdlets.cab ainsi que la version en-us WinPE-DismCmdlets_en-us.cab (les DismCmdLets)
#
# Attention: ici seule la version en-us sera prise en charge
# Le premier fichier CAB correspond au package générique (langue générique)
# Le deuxième fichier CAB permet de personnaliser la langue (ici en-us)
#
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-Scripting.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-Scripting_en-us.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-WMI.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-WMI_en-us.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-MDAC.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-MDAC_en-us.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-NetFx.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-NetFx_en-us.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-PowerShell.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-PowerShell_en-us.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-DismCmdlets.cab
#& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\en-us\WinPE-DismCmdlets_en-us.cab

# Add WinPE 5.0 optional components using ADK 8.1 version of dism.exe
# Default Input Locales for Windows Language Packs: https://technet.microsoft.com/en-ca/library/hh825684.aspx

& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\lp.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Set-UILang:fr-FR
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Set-SysLocale:fr-FR
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Set-UserLocale:fr-FR
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Set-InputLocale:040C:0000040c
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-Scripting.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-Scripting_fr-fr.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-WMI.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-WMI_fr-fr.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-MDAC.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-MDAC_fr-fr.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-NetFx.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-NetFx_fr-fr.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-PowerShell.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-PowerShell_fr-fr.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\WinPE-DismCmdlets.cab
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Package /PackagePath:$WinPE_OCs_Path\fr-fr\WinPE-DismCmdlets_fr-fr.cab

# Install WinPE 5.0 Drivers
#
# installation des pilotes complémentaires (facultatif)
#
& $DISM_Path\dism.exe /Image:$WinPE_MountFolder /Add-Driver /Driver:"$WinPE_Drivers\$WinPE_Architecture" /Recurse

# Copy WinPE ExtraFiles
#
# installation des applications complémentaire (facultatif), dans le dossier \Windows\System32 de l'image monté
#
# Attention: le dossier $myFoldersPath\Apps doit exister sinon une erreur sera visible sous powershell
#            c'est dans ce dossier que l'on place les applications compatibles WinPE
#            Le dossier $myFoldersPath\Drivers doit exister sinon une erreur sera visible sous powershell
#            c'est dans ce dossier que l'on place les pilotes spécifique pour la prise en charge du matèriels
#
Copy-Item "$WinPE_AppsFiles\$WinPE_Architecture\*" "$WinPE_MountFolder\Windows\System32\" -Recurse

# Unmount folder
# 
# Démonte l'image et applique les modifications
#
WinPE-UnMount -mountFolder $WinPE_MountFolder

Make-Directory -folderPath "$WinPE_BuildFolder\bootiso\media\sources"

# Recopie le fichier ISO dans le dossier de construction d'image WinPE
# idem pour le fichier WIM
#
Copy-Item "$WinPE_ADK_Path\$WinPE_Architecture\Media" "$WinPE_BuildFolder\bootiso" -recurse -Force
Copy-Item "$WinPE_BuildFolder\winpe.wim" "$WinPE_BuildFolder\bootiso\media\sources\boot.wim" -Force

}

# Make folder for boot.wim files
#
# Créé un nouveau dossier si le dossier n'existe pas
#
Function Make-Directory($folderPath){
	if (!(Test-Path -path $folderPath)) {New-Item $folderPath -Type Directory}
}

# Création d'un WinPE en fonction de l'architecture détecté
#
Function CreateBootFiles($WinPeMode){
switch($WinPeMode){
'x86'{           # pour la version x86
        #do_ReadMessage -msg "Creating Media Files - Please Wait" | Out-Null        # petit message vocal début de création
        do_ReadMessage -msg "Création du support fichiers - S.V.P. veuillez patienter" | Out-Null # petit message vocal début de création
        #Write-Host "Please do not close this application ..." -ForegroundColor Red # petit message sur fond rouge
        Write-Host "S.V.P. ne pas fermer cette application ..." -ForegroundColor Red # petit message sur fond rouge
        # To create bootable WinPE x86											   
        Make-WinPEBootWim -WinPE_Architecture "x86"								   # Création du winpe x86
        #Write-Host "Finish creating 32 Bit bootable image, please wait" -ForegroundColor Green #petit message sur fond vert
        Write-Host "Fin de la création de l'image bootable 32 Bit, S.V.P. veuillez patienter" -ForegroundColor Green #petit message sur fond vert
        #do_ReadMessage -msg "Finish creating 32 Bit bootable image, please wait"   # petit message vocal fin de création
        do_ReadMessage -msg "Fin de la création de l'image de démarrage 32 Bit, S.V.P. veuillez patienter"   # petit message vocal fin de création
        if (Test-Path -path $WinPE_Media) {Remove-Item -Path $WinPE_Media -Recurse -Force}
        Make-Directory -folderPath $WinPE_Media
        Copy-Item "$x86\bootiso\media\*" -Destination $WinPE_Media -recurse -Force

    }
'amd64'{          # pour la version x64
        #do_ReadMessage -msg "Creating Media Files - Please Wait" | Out-Null
        do_ReadMessage -msg "Création du support fichiers - S.V.P. veuillez patienter" | Out-Null
        #Write-Host "Please do not close this application ..." -ForegroundColor Red
        Write-Host "S.V.P. ne pas fermer cette application ..." -ForegroundColor Red
        # To create bootable WinPE x64
        Make-WinPEBootWim -WinPE_Architecture "amd64"
        #Write-Host "Finish creating 64 Bit bootable image, please wait" -ForegroundColor Green
        Write-Host "Fin de la création de l'image bootable 64 Bit, S.V.P. veuillez patienter" -ForegroundColor Green
        #do_ReadMessage -msg "Finish creating 64 Bit bootable image, please wait"
        do_ReadMessage -msg "Fin de la création de l'image de démarrage 64 Bit, S.V.P. veuillez patienter"
        if (Test-Path -path $WinPE_Media) {Remove-Item -Path $WinPE_Media -Recurse -Force}
        Make-Directory -folderPath $WinPE_Media
        Copy-Item "$amd64\bootiso\media\*" -Destination $WinPE_Media -recurse -Force
    }
 }

# Delete all language files except en-us
$foldersCollection = (Get-ChildItem $WinPE_Media)
foreach($folder In $foldersCollection){
    If($folder.Name.Contains("-") -and $folder.Name -ne ("en-us")){
        Remove-Item -Path $folder.FullName -Force -Recurse -Confirm:$false
        "Deleting: $($folder.FullName)"
    }
}

#Write-Host "Finish creating all neccessary folders" -ForegroundColor Green
Write-Host "Fin de création de tout les dossiers nécessaires" -ForegroundColor Green
#Write-Host "Finish making boot Media Files... (Done)!" -ForegroundColor Green
Write-Host "Fin de la création du support de démarrage fichier ... (terminé)!" -ForegroundColor Green
#do_ReadMessage -msg "Media File Created - Please go to the second step" | Out-Null
do_ReadMessage -msg "Support de démarrage fichier créé - S.V.P. veuillez passer à la deuxième étape" | Out-Null
Start-Sleep -Seconds 3
}
CreateBootFiles -WinPeMode $WinArch