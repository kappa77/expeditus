; Expeditus Windows installer (NSIS 3.x).
; Build from the repository root with:
;   makensis /DAPP_VERSION=1.0.0 /DAPP_BUILD=1 installer\expeditus.nsi
; The release workflow does this automatically.

Unicode true
!include "MUI2.nsh"

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
SetCompressor /SOLID lzma
SetCompressorDictSize 64
CRCCheck on
ManifestDPIAware true
BrandingText "${APP_NAME} ${APP_VERSION}"

VIProductVersion "${APP_VERSION}.${APP_BUILD}"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "CompanyName" "${APP_PUBLISHER}"
VIAddVersionKey "FileDescription" "${APP_NAME} installer"
VIAddVersionKey "FileVersion" "${APP_VERSION}.${APP_BUILD}"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026 ${APP_PUBLISHER}"
VIAddVersionKey "OriginalFilename" "ExpeditusSetup-${APP_VERSION}.exe"

!define MUI_ABORTWARNING
!define MUI_ICON "..\windows\runner\resources\app_icon.ico"
!define MUI_UNICON "..\windows\runner\resources\app_icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Italian"

Function .onInit
  SetShellVarContext current
FunctionEnd

Function un.onInit
  SetShellVarContext current
FunctionEnd

Section "Expeditus" SEC_MAIN
  SectionIn RO
  SetShellVarContext current
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
SectionEnd

Section /o "Desktop shortcut" SEC_DESKTOP
  SetShellVarContext current
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Uninstall"
  SetShellVarContext current

  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Licenze ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"

  RMDir /r "$INSTDIR"

  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\Expeditus"
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_MAIN} "Installa Expeditus e le licenze dei componenti."
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} "Crea un collegamento sul desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END
