; Expeditus one-click Windows installer (NSIS 3.x).
; Double-clicking the generated exe installs silently for the current user
; and launches Expeditus. No wizard, no external runtime packages.
;
; Build from the repository root with:
;   makensis /DAPP_VERSION=1.0.0 /DAPP_BUILD=1 installer\expeditus.nsi

Unicode true

!define APP_NAME "Expeditus"
!define APP_EXE "expeditus.exe"
!define APP_PUBLISHER "kappa77"
!define APP_URL "https://github.com/kappa77/expeditus"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\Expeditus"

!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif

!ifndef APP_BUILD
  !define APP_BUILD "1"
!endif

Name "${APP_NAME} ${APP_VERSION}"
OutFile "..\dist\ExpeditusSetup-${APP_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "Software\Expeditus" "InstallDir"
RequestExecutionLevel user
SilentInstall silent
SilentUnInstall silent
SetCompressor /SOLID lzma
SetCompressorDictSize 64
CRCCheck on
SetOverwrite on
ManifestDPIAware true
BrandingText "${APP_NAME} ${APP_VERSION}"

Icon "..\windows\runner\resources\app_icon.ico"
UninstallIcon "..\windows\runner\resources\app_icon.ico"

VIProductVersion "${APP_VERSION}.${APP_BUILD}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription" "${APP_NAME} installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}.${APP_BUILD}"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026 ${APP_PUBLISHER}"
VIAddVersionKey "OriginalFilename" "ExpeditusSetup-${APP_VERSION}.exe"

Function .onInit
  SetShellVarContext current
FunctionEnd

Function un.onInit
  SetShellVarContext current
FunctionEnd

Section "Install"
  SetShellVarContext current

  ; NSIS cannot overwrite a running executable. Expeditus has no unsaved
  ; document state, so closing it is safe.
  nsExec::Exec '"$SYSDIR\taskkill.exe" /IM ${APP_EXE} /F'

  SetOutPath "$INSTDIR"
  File /r "..\build\windows\x64\runner\Release\*.*"
  File "..\LICENSE"
  File /oname=THIRD_PARTY_NOTICES.txt "..\THIRD_PARTY_NOTICES.md"

  SetOutPath "$INSTDIR\LICENSES"
  File "..\LICENSES\*.*"
  SetOutPath "$INSTDIR"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Licenze ${APP_NAME}.lnk" "$INSTDIR\THIRD_PARTY_NOTICES.txt"
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"

  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKCU "Software\Expeditus" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${APP_PUBLISHER}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "${APP_URL}"
  WriteRegStr HKCU "${UNINST_KEY}" "HelpLink" "${APP_URL}/issues"
  WriteRegStr HKCU "${UNINST_KEY}" "URLUpdateInfo" "${APP_URL}/releases"
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

  ; One click: install, then open the app.
  Exec "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Uninstall"
  SetShellVarContext current

  nsExec::Exec '"$SYSDIR\taskkill.exe" /IM ${APP_EXE} /F'

  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Licenze ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"

  RMDir /r "$INSTDIR"

  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\Expeditus"
SectionEnd
