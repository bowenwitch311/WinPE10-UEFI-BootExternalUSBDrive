@ECHO OFF
wpeinit.exe /unattend=X:\Windows\System32\WinPEResolution.xml
cd X:\Windows\system32
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
Start Powershell
powershell.exe -ExecutionPolicy Bypass -NoLogo -NonInteractive -NoProfile -File X:\Windows\system32\WinPE-WIM_FFU.ps1
CLS
GoTo:EOF
