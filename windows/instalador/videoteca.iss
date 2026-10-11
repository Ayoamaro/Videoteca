; Instalador de Videoteca para Windows (Inno Setup 6).
;
; Se compila solo en GitHub Actions al publicar una versión (ver
; .github/workflows/publicar.yml). A mano, después de
; `flutter build windows --release`:
;
;   iscc /DVersion=1.0.0 /DRepo=usuario/Videoteca windows\instalador\videoteca.iss
;
; Se instala solo para el usuario actual (en %LOCALAPPDATA%\Programs), así
; que no pide permisos de administrador. Los datos de la app (catálogo,
; miniaturas, registro de cambios y ajustes, en %LOCALAPPDATA%\Videoteca) no
; se tocan al instalar ni al actualizar; al desinstalar se pregunta si se
; borran (por defecto, no). Las películas del disco nunca se tocan.
;
; Este archivo va en UTF-8 con BOM (si no, Inno Setup estropea las tildes).

#ifndef Version
  #define Version "0.0.0"
#endif
#ifndef Repo
  #define Repo "Ayoamaro/Videoteca"
#endif

[Setup]
; Siempre el mismo: así cada versión se instala encima de la anterior.
AppId={{6A4E3C59-2F0B-4C7E-9B1D-8E5A7F2C4D10}
AppName=Videoteca
AppVersion={#Version}
AppVerName=Videoteca {#Version}
AppPublisher=Ayoamaro
AppPublisherURL=https://github.com/{#Repo}
AppSupportURL=https://github.com/{#Repo}
AppUpdatesURL=https://github.com/{#Repo}/releases
AppCopyright=© 2026 Ayoamaro · Licencia MIT
VersionInfoVersion={#Version}
VersionInfoProductName=Videoteca
VersionInfoDescription=Instalador de Videoteca
VersionInfoCompany=Ayoamaro
DefaultDirName={autopf}\Videoteca
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
; Flutter necesita Windows 10 o posterior, de 64 bits.
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\build\instalador
OutputBaseFilename=Videoteca-{#Version}-instalador
SetupIconFile=..\runner\resources\app_icon.ico
WizardImageFile=imagen-grande-100.bmp,imagen-grande-150.bmp,imagen-grande-200.bmp
WizardSmallImageFile=imagen-pequena-100.bmp,imagen-pequena-150.bmp,imagen-pequena-200.bmp
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

[Messages]
es.WelcomeLabel2=Se va a instalar [name/ver] en este equipo.%n%nCatálogo de tu colección de películas: búscalas al instante, completa sus fichas y consúltalas también desde el móvil.%n%nSi ya tienes Videoteca, se actualiza y tu catálogo se conserva.
; En Windows 7 u 8, o de 32 bits, la app no funciona (Flutter necesita
; Windows 10 u 11 de 64 bits): se dice qué se puede hacer en su lugar.
es.WinVersionTooLowError=Videoteca necesita Windows 10 u 11 y este PC tiene una versión anterior de Windows.%n%nDesde este PC puedes abrir las películas por la red en el Explorador (la carpeta que comparte el PC de las películas) y consultar el catálogo en el móvil.
es.OnlyOnTheseArchitectures=Videoteca necesita Windows de 64 bits y este PC tiene Windows de 32 bits.%n%nDesde este PC puedes abrir las películas por la red en el Explorador (la carpeta que comparte el PC de las películas) y consultar el catálogo en el móvil.

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

[Code]
// Con la app abierta no se puede desinstalar (sus archivos están en uso):
// se pide cerrarla. La app crea «VideotecaAbierta» al arrancar (ver
// windows/runner/main.cpp).
function InitializeUninstall(): Boolean;
begin
  Result := True;
  while CheckForMutexes('VideotecaAbierta') do
    if SuppressibleMsgBox(
        'Videoteca está abierta. Ciérrala y pulsa «Aceptar» para seguir.',
        mbError, MB_OKCANCEL, IDCANCEL) = IDCANCEL then
    begin
      Result := False;
      Exit;
    end;
end;

// Al desinstalar se pregunta si se borran también los datos de la app de
// este equipo. Por defecto (y en una desinstalación silenciosa), no: si se
// vuelve a instalar, todo sigue como estaba.
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Datos: String;
begin
  if CurUninstallStep <> usPostUninstall then
    Exit;
  Datos := ExpandConstant('{localappdata}\Videoteca');
  if not DirExists(Datos) then
    Exit;
  if SuppressibleMsgBox(
      '¿Borrar también los datos de Videoteca de este equipo?' + #13#10#13#10 +
      'Son el catálogo, las miniaturas de las carátulas, el registro de ' +
      'cambios y los ajustes (en ' + Datos + ').' + #13#10#13#10 +
      'Tus películas no se tocan: sus datos y carátulas están dentro de cada ' +
      'archivo. Si piensas volver a instalar Videoteca, elige «No» y todo ' +
      'seguirá como estaba.',
      mbConfirmation, MB_YESNO or MB_DEFBUTTON2, IDNO) = IDYES then
    DelTree(Datos, True, True, True);
end;
