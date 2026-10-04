; Instalador de Videoteca para Windows (Inno Setup 6).
;
; Se compila solo en GitHub Actions al publicar una versión (ver
; .github/workflows/publicar.yml). A mano, después de
; `flutter build windows --release`:
;
;   iscc /DVersion=0.1.0 windows\instalador\videoteca.iss
;
; Se instala solo para el usuario actual (en %LOCALAPPDATA%\Programs), así
; que no pide permisos de administrador. Los datos de la app (catálogo y
; miniaturas, en %LOCALAPPDATA%\Videoteca) no se tocan al instalar, actualizar
; ni desinstalar.

#ifndef Version
  #define Version "0.0.0"
#endif

[Setup]
AppId={{6A4E3C59-2F0B-4C7E-9B1D-8E5A7F2C4D10}
AppName=Videoteca
AppVersion={#Version}
AppPublisher=Ayoamaro
AppPublisherURL=https://github.com/Ayoamaro/videoteca
DefaultDirName={autopf}\Videoteca
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\instalador
OutputBaseFilename=Videoteca-{#Version}-instalador
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\videoteca.exe
UninstallDisplayName=Videoteca
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Si la app está abierta al actualizar, se cierra y se vuelve a abrir.
CloseApplications=yes
RestartApplications=yes

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Todo lo que genera `flutter build windows --release` (y las librerías de
; Visual C++, que el flujo de GitHub copia ahí antes de compilar esto).
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; Restos de versiones anteriores (las fuentes e iconos cambian de una a otra).
Type: filesandordirs; Name: "{app}\data"

[Icons]
Name: "{autoprograms}\Videoteca"; Filename: "{app}\videoteca.exe"
Name: "{autodesktop}\Videoteca"; Filename: "{app}\videoteca.exe"; Tasks: escritorio

[Run]
Filename: "{app}\videoteca.exe"; Description: "{cm:LaunchProgram,Videoteca}"; Flags: nowait postinstall skipifsilent
