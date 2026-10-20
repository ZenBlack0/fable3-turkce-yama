; Fable III Türkçe Yama - Inno Setup betiği
; Derleme: build.py --exe  (ISCC /DVersion=1.0.0 /DSrcDir=... /DOutDir=... fable3_tr.iss)

#ifndef Version
  #define Version "1.1.1"
#endif
#ifndef SrcDir
  #define SrcDir "delta"
#endif
#ifndef OutDir
  #define OutDir "..\..\dist\v1.1.1"
#endif
#ifndef OutName
  #define OutName "Fable3_Turkce_Yama_v1.1.1"
#endif

[Setup]
AppId={{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}
AppName=Fable III Türkçe Yama
AppVersion={#Version}
AppVerName=Fable III Türkçe Yama v{#Version}
AppPublisher=ZenBlack0
DefaultDirName={autopf}\Fable3 Turkce Yama
DisableDirPage=yes
DirExistsWarning=no
DisableProgramGroupPage=yes
DisableReadyPage=no
UsePreviousAppDir=no
UninstallFilesDir={app}
UninstallDisplayName=Fable III Türkçe Yama
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutDir}
OutputBaseFilename={#OutName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
DisableWelcomePage=no
ShowLanguageDialog=no
LanguageDetectionMethod=none
VersionInfoVersion={#Version}.0
VersionInfoProductName=Fable III Türkçe Yama
VersionInfoProductVersion={#Version}
VersionInfoDescription=Fable III (PC) Türkçe yama kurulumu - fan çevirisi
VersionInfoCompany=ZenBlack0
VersionInfoCopyright=Copyright (c) 2026 Kerim
CloseApplications=no
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Messages]
turkish.WelcomeLabel1=Fable III Türkçe Yama v{#Version}
turkish.WelcomeLabel2=Bu sihirbaz, Fable III (PC) oyununa Türkçe altyazı ve arayüz yamasını kuracak.%n%nBu yama bir hayran çevirisidir; resmî değildir ve oyunun yapımcıları ya da yayıncısıyla bağlantılı değildir. Konuşmalar (ses) İngilizce kalır.%n%nDevam etmeden önce oyunu kapatın.
turkish.SelectDirLabel3=Fable III oyun klasörü aşağıda gösterilmiştir. Farklıysa "Gözat" ile oyunun kurulu olduğu klasörü seçin.
turkish.SelectDirBrowseLabel=Devam etmek için İleri'ye tıklayın.

[Files]
; Oyuna ait HİÇBİR dosya ya da metin yoktur: yalnızca "kayıt ID'si -> Türkçe" çeviri paketi, yardımcı program (f3patch)
; ve yazı tipi için küçük bir xdelta3 farkı. Yamalı dosyalar kullanıcının KENDİ orijinal dosyalarından üretilir.
Source: "{#SrcDir}\book_pack.lzma"; DestDir: "{tmp}"; Flags: dontcopy
Source: "{#SrcDir}\f3patch\*"; DestDir: "{tmp}\f3patch"; Flags: dontcopy recursesubdirs createallsubdirs
Source: "{#SrcDir}\font.xdelta"; DestDir: "{tmp}"; Flags: dontcopy
Source: "{#SrcDir}\xdelta3.exe"; DestDir: "{tmp}"; Flags: dontcopy
Source: "{#SrcDir}\placeholder\*"; DestDir: "{tmp}\placeholder"; Flags: dontcopy recursesubdirs createallsubdirs
Source: "{#SrcDir}\placeholder\*"; DestDir: "{app}\placeholder"; Flags: recursesubdirs createallsubdirs
Source: "{#SrcDir}\xdelta3_COPYING.txt"; DestDir: "{app}\lisans"
Source: "{#SrcDir}\nuitka_LICENSE.txt"; DestDir: "{app}\lisans"
Source: "{#SrcDir}\python_LICENSE.txt"; DestDir: "{app}\lisans"
Source: "{#SrcDir}\NOTICE.txt"; DestDir: "{app}\lisans"

[UninstallDelete]
; yalnızca KENDİ uygulama klasörümüz ({app} asla oyun klasörü değildir)
Type: files; Name: "{app}\kurulum_log.txt"
Type: dirifempty; Name: "{app}"

[Registry]
Root: HKA; Subkey: "SOFTWARE\Fable3TurkceYama"; ValueType: string; ValueName: "Surum"; ValueData: "{#Version}"; Flags: uninsdeletekey
Root: HKA; Subkey: "SOFTWARE\Fable3TurkceYama"; ValueType: string; ValueName: "OyunKlasoru"; ValueData: "{code:GameDirP}"

[Code]
const
  ORIG_BOOK = '1a588553b9dde08b3aa37d609f5e2ec9a9a9f2cb8f0d93bb3b93cdeca2e7afc3';
  ORIG_FONT = '913cf1699e2fc3b612f18ee88957f44451abf8bbe88df0bf6c5d075ec6e8f0a3';

#include "known_hashes.inc"

var
  InstPage: TWizardPage;
  InstRB: array[0..2] of TNewRadioButton;
  InstDesc, InstTitle: array[0..2] of String;
  GamePage: TInputDirWizardPage;
  PickPage: TInputOptionWizardPage;
  LaunchCheck: TNewCheckBox;
  PickReady, InstallOK: Boolean;
  GamePageReady, LogAllowed: Boolean;
  CleanNote: String;
  DetectedFrom, InstDir, InstVer, InstModeText: String;
  IsInstalled, ExitNow: Boolean;
  InstBM, InstChoice: Integer;      { InstChoice: 0 yeniden kur/onar, 1 kaldır, 2 çık }
  DlcRep: TArrayOfString;           { f3patch dlc raporu (geçici klasörde üretilir, oyun klasörüne henüz yazılmaz) }
  BakSrcBook, BakSrcFont, OrigSrcBook, OrigSrcFont: String;
  QuarBook, QuarFont, SaveUnkBook, SaveUnkFont: Boolean;

{ ------------------------------------------------------------ yardımcılar }
function AppDirNow: String;
begin
  if IsUninstaller then
    Result := ExpandConstant('{app}')
  else
    Result := WizardDirValue;
end;

function LogPath(const Dir: String): String;
begin
  Result := AppDirNow + '\kurulum_log.txt';
end;

{ Günlük, oyun klasörüne değil kendi uygulama klasörümüze yazılır. }
procedure WriteLog(const Dir, Msg: String);
begin
  if LogAllowed or DirExists(AppDirNow) then
  begin
    ForceDirectories(AppDirNow);
    SaveStringToFile(LogPath(Dir), GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':') + '  ' + Msg + #13#10, True);
  end;
  { Kaldırmada uygulama klasöründeki kurulum_log.txt kaldırıcı bitince silinir; kalıcı iz için aynı satır kullanıcının TEMP klasörüne de yazılır. }
  if IsUninstaller then
    SaveStringToFile(ExpandConstant('{%TEMP}') + '\Fable3_Turkce_Yama_kaldirma_log.txt', GetDateTimeString('yyyy/mm/dd hh:nn:ss', '-', ':') + '  ' + Msg + #13#10, True);
end;

{ Bilgi kutusunun TAM metnini günlüğe yazıp kutuyu gösterir (kutuda ne yazdığı sonradan okunabilsin). }
procedure InfoBox(const Dir, Msg: String; Kind: TMsgBoxType);
var
  L: String;
begin
  L := Msg;
  StringChangeEx(L, #13#10, ' | ', True);
  WriteLog(Dir, 'BİLGİ KUTUSU: ' + L);
  SuppressibleMsgBox(Msg, Kind, MB_OK, IDOK);
end;

function BookPath(const Dir: String): String;
begin
  Result := Dir + '\data\language\en-uk\text\book.babel';
end;

function FontPath(const Dir: String): String;
begin
  Result := Dir + '\data\language\en-uk\fonts\gui_normal.bft';
end;

function IsGameDir(const Dir: String): Boolean;
begin
  Result := (Dir <> '') and FileExists(BookPath(Dir)) and FileExists(FontPath(Dir));
end;

function Hash(const F: String): String;
begin
  if FileExists(F) then
    Result := Lowercase(GetSHA256OfFile(F))
  else
    Result := '';
end;

{ ------------------------------------------------------- oyun klasörü bulma }
function SteamLibraryGame(const LibRoot: String): String;
var
  P: String;
begin
  Result := '';
  P := AddBackslash(LibRoot) + 'steamapps\common\Fable 3';
  if IsGameDir(P) then
    Result := P;
end;

function FindInVdf(const Steam: String): String;
var
  Lines: TArrayOfString;
  I, A, B: Integer;
  L, Path: String;
begin
  Result := '';
  if not LoadStringsFromFile(AddBackslash(Steam) + 'steamapps\libraryfolders.vdf', Lines) then
    Exit;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    L := Trim(Lines[I]);
    if Pos('"path"', Lowercase(L)) = 1 then
    begin
      Delete(L, 1, 6);
      L := Trim(L);
      if (Length(L) > 2) and (L[1] = '"') then
      begin
        Delete(L, 1, 1);
        B := Pos('"', L);
        if B > 0 then
        begin
          Path := Copy(L, 1, B - 1);
          StringChangeEx(Path, '\\', '\', True);
          Result := SteamLibraryGame(Path);
          if Result <> '' then
            Exit;
        end;
      end;
    end;
  end;
end;

{ ------------------------------------------------------- oyun klasörü adayları }
function GetDriveTypeW(lpRootPathName: String): Cardinal;
  external 'GetDriveTypeW@kernel32.dll stdcall';
function GetTickCount: Cardinal;
  external 'GetTickCount@kernel32.dll stdcall';

var
  Cands: array of String;
  CandSrc: array of String;
  NC: Integer;
  CollectDone: Boolean;
  ScanDeadline: Cardinal;

procedure AddCand(const P, Src: String);
var
  I: Integer;
  Q: String;
begin
  Q := RemoveBackslash(P);
  if not IsGameDir(Q) then
    Exit;
  for I := 0 to NC - 1 do
    if CompareText(Cands[I], Q) = 0 then
      Exit;
  SetArrayLength(Cands, NC + 1);
  SetArrayLength(CandSrc, NC + 1);
  Cands[NC] := Q;
  CandSrc[NC] := Src;
  NC := NC + 1;
end;

function RegRead(const Name: String): String;
var
  V: String;
begin
  Result := '';
  if RegQueryStringValue(HKLM, 'SOFTWARE\Fable3TurkceYama', Name, V) then
    Result := V
  else if RegQueryStringValue(HKCU, 'SOFTWARE\Fable3TurkceYama', Name, V) then
    Result := V;
end;

{ Uninstall kayıtlarında DisplayName'i "Fable" içeren (bizimki hariç) tüm girişlerin konumu }
procedure ScanUninstall(Root: Integer);
var
  Base, K, DN, IL, US: String;
  Names: TArrayOfString;
  I: Integer;
begin
  Base := 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall';
  if not RegGetSubkeyNames(Root, Base, Names) then
    Exit;
  for I := 0 to GetArrayLength(Names) - 1 do
  begin
    if Pos('7C1D3B52', Names[I]) > 0 then
      Continue;
    K := Base + '\' + Names[I];
    DN := '';
    if RegQueryStringValue(Root, K, 'DisplayName', DN) then
      if (Pos('fable', Lowercase(DN)) > 0) and (Pos('türkçe', Lowercase(DN)) = 0) then
      begin
        IL := '';
        if RegQueryStringValue(Root, K, 'InstallLocation', IL) then
          AddCand(IL, 'kurulum kaydı');
        US := '';
        if RegQueryStringValue(Root, K, 'UninstallString', US) then
          AddCand(ExtractFileDir(RemoveQuotes(US)), 'kurulum kaydı');
        US := '';
        if RegQueryStringValue(Root, K, 'DisplayIcon', US) then
          AddCand(ExtractFileDir(RemoveQuotes(US)), 'kurulum kaydı');
      end;
  end;
end;

function SkipScanName(const N: String): Boolean;
var
  L: String;
begin
  L := Lowercase(N);
  Result := (N = '.') or (N = '..') or (L = 'windows') or (L = '$recycle.bin') or (L = 'system volume information') or
            (L = 'windowsapps') or (L = 'programdata') or (L = 'appdata') or (L = 'recovery') or (L = '$windows.~bt') or
            (L = 'winsxs') or (L = 'node_modules') or (L = 'perflogs');
end;

{ Kök + 2 alt düzey; FableLauncher.exe ve en-uk\text\book.babel olan klasörler. Süre sınırlı. }
procedure ScanDirs(const Root: String; Level: Integer);
var
  FR: TFindRec;
  S: String;
begin
  if GetTickCount > ScanDeadline then
    Exit;
  if FindFirst(AddBackslash(Root) + '*', FR) then
  try
    repeat
      if GetTickCount > ScanDeadline then
        Break;
      if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and (not SkipScanName(FR.Name)) then
      begin
        S := AddBackslash(Root) + FR.Name;
        if FileExists(S + '\FableLauncher.exe') and IsGameDir(S) then
          AddCand(S, 'sürücü taraması')
        else if Level < 2 then
          ScanDirs(S, Level + 1);
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
end;

procedure CollectCandidates;
var
  Steam, Loc, K: String;
  I: Integer;
begin
  if CollectDone then
    Exit;
  CollectDone := True;
  NC := 0;
  { 1) önceki kurulumun kayıt defterine yazdığı oyun klasörü }
  AddCand(RegRead('OyunKlasoru'), 'önceki kurulum');
  { 2) Steam kaydı + libraryfolders.vdf }
  Steam := '';
  if not RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Valve\Steam', 'InstallPath', Steam) then
    if not RegQueryStringValue(HKLM32, 'SOFTWARE\Valve\Steam', 'InstallPath', Steam) then
      if not RegQueryStringValue(HKCU, 'SOFTWARE\Valve\Steam', 'SteamPath', Steam) then
        Steam := '';
  if Steam <> '' then
  begin
    StringChangeEx(Steam, '/', '\', True);
    AddCand(SteamLibraryGame(Steam), 'Steam');
    AddCand(FindInVdf(Steam), 'Steam');
  end;
  { 3) Steam uninstall kaydı (App ID 105400) }
  Loc := '';
  if not RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 105400', 'InstallLocation', Loc) then
    if not RegQueryStringValue(HKLM32, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 105400', 'InstallLocation', Loc) then
      Loc := '';
  AddCand(Loc, 'Steam');
  { 4) Adında "Fable" geçen tüm uninstall kayıtları (Steam dışı kurulumlar dahil) }
  ScanUninstall(HKLM);
  ScanUninstall(HKLM32);
  ScanUninstall(HKCU);
  { 5) bilinen yollar }
  AddCand('C:\Games\Fable 3', 'bilinen yol');
  AddCand(ExpandConstant('{commonpf32}') + '\Steam\steamapps\common\Fable 3', 'bilinen yol');
  AddCand(ExpandConstant('{commonpf}') + '\Steam\steamapps\common\Fable 3', 'bilinen yol');
  AddCand(ExpandConstant('{commonpf32}') + '\Lionhead Studios Ltd\Fable III', 'bilinen yol');
  { 6) sabit sürücülerde kök + 2 alt düzey (en çok ~3 sn) }
  ScanDeadline := GetTickCount + 3000;
  for I := 0 to 23 do
  begin
    K := Chr(Ord('C') + I) + ':\';
    if (GetTickCount <= ScanDeadline) and (GetDriveTypeW(K) = 3) then
      ScanDirs(K, 1);
  end;
end;

function CandidateDir: String;
begin
  Result := ExpandConstant('{param:GAME|}');
  if Result <> '' then
    Exit;
  CollectCandidates;
  if NC > 0 then
  begin
    Result := Cands[0];
    DetectedFrom := CandSrc[0];
  end;
end;

function GameRunning: Boolean;
var
  RC: Integer;
begin
  Result := False;
  if Exec(ExpandConstant('{sys}\cmd.exe'), '/c tasklist /FI "IMAGENAME eq Fable3.exe" /NH | find /I "Fable3.exe" >nul', '', SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) then
    Result := True;
  if Exec(ExpandConstant('{sys}\cmd.exe'), '/c tasklist /FI "IMAGENAME eq FableLauncher.exe" /NH | find /I "FableLauncher.exe" >nul', '', SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) then
    Result := True;
end;

{ ---------------------------------------------- güvenli silme (oyun klasörü) }
{ Oyun klasöründe YALNIZCA _TR_yedek içindeki bilinen dosyalar silinir. DelTree KULLANILMAZ. }
function IsRootLike(const P: String): Boolean;
begin
  Result := Length(RemoveBackslash(P)) <= 3;
end;

function IsBakFile(const N: String): Boolean;
begin
  Result := (CompareText(N, 'book.babel') = 0) or (CompareText(N, 'gui_normal.bft') = 0) or (CompareText(N, 'kurulum_log.txt') = 0);
end;

function IsSupFile(const N: String): Boolean;
begin
  Result := (Pos('book.babel.', Lowercase(N)) = 1) or (Pos('gui_normal.bft.', Lowercase(N)) = 1);
end;

{ _TR_yedek içinde beklenmeyen kaç öğe var? (-1: güvenlik koşulu sağlanmadı) }
function CountUnexpected(const Game: String): Integer;
var
  FR: TFindRec;
  Bak, Sup: String;
  IsDir: Boolean;
begin
  Result := 0;
  if (not IsGameDir(Game)) or IsRootLike(Game) then
  begin
    Result := -1;
    Exit;
  end;
  Bak := RemoveBackslash(Game) + '\_TR_yedek';
  Sup := Bak + '\supheli';
  if not DirExists(Bak) then
    Exit;
  if FindFirst(Bak + '\*', FR) then
  try
    repeat
      if (FR.Name <> '.') and (FR.Name <> '..') then
      begin
        IsDir := (FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0;
        if IsDir then
        begin
          if CompareText(FR.Name, 'supheli') <> 0 then Result := Result + 1;
        end
        else if not IsBakFile(FR.Name) then
          Result := Result + 1;
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
  if DirExists(Sup) then
    if FindFirst(Sup + '\*', FR) then
    try
      repeat
        if (FR.Name <> '.') and (FR.Name <> '..') then
        begin
          if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) or (not IsSupFile(FR.Name)) then
            Result := Result + 1;
        end;
      until not FindNext(FR);
    finally
      FindClose(FR);
    end;
end;

{ Yalnızca CountUnexpected = 0 iken çağrılır. Silinen her yol _TR_yedek altındaki izinli listedendir. }
procedure RemoveBackupSafe(const Game: String);
var
  FR: TFindRec;
  Bak, Sup: String;
begin
  Bak := RemoveBackslash(Game) + '\_TR_yedek';
  Sup := Bak + '\supheli';
  if DirExists(Sup) then
  begin
    if FindFirst(Sup + '\*', FR) then
    try
      repeat
        if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) = 0) and IsSupFile(FR.Name) then
          DeleteFile(Sup + '\' + FR.Name);
      until not FindNext(FR);
    finally
      FindClose(FR);
    end;
    RemoveDir(Sup);
  end;
  if FileExists(Bak + '\book.babel') then DeleteFile(Bak + '\book.babel');
  if FileExists(Bak + '\gui_normal.bft') then DeleteFile(Bak + '\gui_normal.bft');
  if FileExists(Bak + '\kurulum_log.txt') then DeleteFile(Bak + '\kurulum_log.txt');
  RemoveDir(Bak);
end;

{ ---------------------------------------------- DLC klasörümüz (DLC\99_tr_yama) }
{ Yalnızca KENDİ klasörümüz: içinde YALNIZCA bildiğimiz dosyalar varsa silinir. DelTree KULLANILMAZ; DLC\ ve diğer DLC'lere dokunulmaz. }
function DlcPkgDir(const Game: String): String;
begin
  Result := RemoveBackslash(Game) + '\DLC\99_tr_yama';
end;

function IsDlcKnown(const Rel: String): Boolean;
var
  L: String;
begin
  L := Lowercase(Rel);
  Result := (L = 'content.xbx') or (L = 'tr_yama.txt') or (L = 'content\package_collection_info.xmb') or
            (L = 'content\tr_yama_us.bnk') or (L = 'content\tr_yama_us.bnk.dat') or
            (L = 'content\tr_yama_tk.bnk') or (L = 'content\tr_yama_tk.bnk.dat');
end;

{ bilinmeyen öğe sayısı (-1: klasör yok) }
function CountDlcUnexpected(const Game: String): Integer;
var
  FR: TFindRec;
  Pkg: String;
begin
  Result := -1;
  Pkg := DlcPkgDir(Game);
  if not DirExists(Pkg) then Exit;
  Result := 0;
  if FindFirst(Pkg + '\*', FR) then
  try
    repeat
      if (FR.Name <> '.') and (FR.Name <> '..') then
      begin
        if (FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        begin
          if CompareText(FR.Name, 'Content') <> 0 then Result := Result + 1;
        end
        else if not IsDlcKnown(FR.Name) then
          Result := Result + 1;
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
  if DirExists(Pkg + '\Content') then
    if FindFirst(Pkg + '\Content\*', FR) then
    try
      repeat
        if (FR.Name <> '.') and (FR.Name <> '..') then
        begin
          if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) or (not IsDlcKnown('Content\' + FR.Name)) then
            Result := Result + 1;
        end;
      until not FindNext(FR);
    finally
      FindClose(FR);
    end;
end;

{ Dönen: 0 klasör yoktu, 1 silindi, 2 bilinmeyen dosya olduğu için DOKUNULMADI }
function RemoveDlcSafe(const Game: String): Integer;
var
  Pkg: String;
  I: Integer;
  Names: array[0..6] of String;
begin
  Result := 0;
  if (not IsGameDir(Game)) or IsRootLike(Game) then Exit;
  I := CountDlcUnexpected(Game);
  if I < 0 then Exit;
  Pkg := DlcPkgDir(Game);
  if I > 0 then
  begin
    WriteLog(Game, 'DLC\99_tr_yama içinde bilinmeyen ' + IntToStr(I) + ' öğe var; hiçbir şey silinmedi.');
    Result := 2;
    Exit;
  end;
  Names[0] := 'content.xbx';
  Names[1] := 'tr_yama.txt';
  Names[2] := 'Content\package_collection_info.xmb';
  Names[3] := 'Content\tr_yama_us.bnk';
  Names[4] := 'Content\tr_yama_us.bnk.dat';
  Names[5] := 'Content\tr_yama_tk.bnk';
  Names[6] := 'Content\tr_yama_tk.bnk.dat';
  for I := 0 to 6 do
    if FileExists(Pkg + '\' + Names[I]) then DeleteFile(Pkg + '\' + Names[I]);
  RemoveDir(Pkg + '\Content');
  RemoveDir(Pkg);
  WriteLog(Game, 'DLC\99_tr_yama kaldırıldı.');
  Result := 1;
end;

{ ---------------------------------------------- kayıt taraması (YALNIZCA OKUR) ve yer tutucu paket
  Neden: v1.1.0 paketi kayda "zorunlu paket" (RequiredPackage 120/121) olarak yazılıyordu. Böyle kayıtlar, DLC\99_tr_yama kaldırılınca
  "required downloadable content" uyarısı verir. Kaldırırken kayıt klasörü okunur (HİÇBİR kayıt dosyasına yazılmaz); 120/121 gerektiren
  kayıt varsa (ya da klasör okunamazsa: güvenli taraf) paket silinmez, oyuna hiçbir şey eklemeyen boş bir yer tutucuya çevrilir. }
var
  DlcWhy: String;

function SavesRoot: String;
begin
  Result := GetEnv('F3_SAVESDIR');      { yalnızca testler için; normalde %USERPROFILE%\Saved Games\Lionhead Studios\Fable 3 }
  if Result = '' then
    Result := ExpandConstant('{%USERPROFILE}') + '\Saved Games\Lionhead Studios\Fable 3';
  Result := RemoveBackslash(Result);
end;

{ chaptersave.bin: 4 bayt başlık + düz XML. RequiredPackage listesinde 120/121 var mı: 1 evet, 0 hayır, -1 okunamadı/biçim tanınmadı }
function SaveRequiresTr(const FileName: String): Integer;
var
  S: AnsiString;
  T, Id: String;
  P, Q: Integer;
begin
  Result := -1;
  if not LoadStringFromFile(FileName, S) then Exit;
  T := S;
  if Pos('<SaveInfo>', T) = 0 then Exit;
  Result := 0;
  P := Pos('<RequiredPackage>', T);
  while P > 0 do
  begin
    Delete(T, 1, P + 16);
    Q := Pos('<PackageId type="uint">', T);
    if Q > 0 then
    begin
      Delete(T, 1, Q + 22);
      Id := '';
      while (Length(T) > 0) and (T[1] >= '0') and (T[1] <= '9') do
      begin
        Id := Id + T[1];
        Delete(T, 1, 1);
      end;
      if (Id = '120') or (Id = '121') then Result := 1;
    end;
    P := Pos('<RequiredPackage>', T);
  end;
end;

{ Dönen: True = 120/121 gerektiren kayıt var; Unreadable: okunamayan kayıt var }
function ScanSaves(const Dir: String; Depth: Integer; var Unreadable: Boolean): Boolean;
var
  FR: TFindRec;
  Full, L: String;
  R: Integer;
begin
  Result := False;
  if FindFirst(Dir + '\*', FR) then
  try
    repeat
      if (FR.Name <> '.') and (FR.Name <> '..') then
      begin
        Full := Dir + '\' + FR.Name;
        if (FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
        begin
          if Depth < 3 then
            if ScanSaves(Full, Depth + 1, Unreadable) then Result := True;
        end
        else
        begin
          L := Lowercase(FR.Name);
          if (Length(L) >= 15) and (Copy(L, Length(L) - 14, 15) = 'chaptersave.bin') then
          begin
            R := SaveRequiresTr(Full);
            if R = 1 then Result := True
            else if R < 0 then Unreadable := True;
          end;
        end;
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
end;

{ True = yer tutucu bırakılmalı. Klasör yoksa/okunamazsa True (güvenli taraf). }
function SavesNeedPlaceholder: Boolean;
var
  Root: String;
  Unr: Boolean;
begin
  Result := True;
  Root := SavesRoot;
  if not DirExists(Root) then
  begin
    DlcWhy := 'kayıt klasörü bulunamadığı için (güvenli tarafta kalındı)';
    Exit;
  end;
  Unr := False;
  if ScanSaves(Root, 0, Unr) then
  begin
    DlcWhy := 'v1.1.0 ile alınmış ve yama paketini gerektiren kayıt(lar) bulunduğu için';
    Exit;
  end;
  if Unr then
  begin
    DlcWhy := 'bazı kayıtlar okunamadığı için (güvenli tarafta kalındı)';
    Exit;
  end;
  DlcWhy := 'hiçbir kayıt yama paketini gerektirmiyor';
  Result := False;
end;

function PlaceholderRoot: String;
begin
  Result := ExpandConstant('{tmp}') + '\placeholder';
  if DirExists(Result) then Exit;
  Result := ExpandConstant('{app}') + '\placeholder';
  if DirExists(Result) then Exit;
  Result := '';
end;

{ DLC\99_tr_yama içindeki bilinen dosyaları yer tutucu dosyalarla değiştirir (aynı kimlikler 120/121; kitap/metin YOK). }
function PlaceholderPack(const Game: String): Boolean;
var
  Pkg, V, Src, Root: String;
  Us, Tk: Boolean;
  I: Integer;
  Names: array[0..6] of String;
begin
  Result := False;
  Pkg := DlcPkgDir(Game);
  Us := FileExists(Pkg + '\Content\tr_yama_us.bnk');
  Tk := FileExists(Pkg + '\Content\tr_yama_tk.bnk');
  if Us and (not Tk) then V := 'us'
  else if Tk and (not Us) then V := 'tk'
  else V := 'both';
  Root := PlaceholderRoot;
  if Root = '' then
  begin
    WriteLog(Game, 'Yer tutucu paket dosyaları bulunamadı.');
    Exit;
  end;
  Src := Root + '\' + V + '\99_tr_yama';
  if not FileExists(Src + '\content.xbx') then
  begin
    WriteLog(Game, 'Yer tutucu paket eksik: ' + Src);
    Exit;
  end;
  Names[0] := 'content.xbx';
  Names[1] := 'tr_yama.txt';
  Names[2] := 'Content\package_collection_info.xmb';
  Names[3] := 'Content\tr_yama_us.bnk';
  Names[4] := 'Content\tr_yama_us.bnk.dat';
  Names[5] := 'Content\tr_yama_tk.bnk';
  Names[6] := 'Content\tr_yama_tk.bnk.dat';
  ForceDirectories(Pkg + '\Content');
  for I := 0 to 6 do
  begin
    if FileExists(Src + '\' + Names[I]) then
    begin
      if (not FileCopy(Src + '\' + Names[I], Pkg + '\' + Names[I], False)) or
         (Hash(Pkg + '\' + Names[I]) <> Hash(Src + '\' + Names[I])) then
      begin
        WriteLog(Game, 'Yer tutucu dosyası yazılamadı: ' + Names[I]);
        Exit;
      end;
    end
    else if FileExists(Pkg + '\' + Names[I]) then
      DeleteFile(Pkg + '\' + Names[I]);
  end;
  Result := True;
end;

{ DLC\99_tr_yama'yı kaldırırken: 0 klasör yoktu, 1 silindi, 2 bilinmeyen dosya var (dokunulmadı),
  3 yer tutucuya çevrildi, 4 yer tutucu hazırlanamadı (paket olduğu gibi bırakıldı) }
function RetireDlc(const Game: String): Integer;
var
  U: Integer;
begin
  Result := 0;
  DlcWhy := '';
  if (not IsGameDir(Game)) or IsRootLike(Game) then Exit;
  U := CountDlcUnexpected(Game);
  if U < 0 then Exit;
  if U > 0 then
  begin
    WriteLog(Game, 'DLC\99_tr_yama içinde bilinmeyen ' + IntToStr(U) + ' öğe var; hiçbir şey silinmedi.');
    Result := 2;
    Exit;
  end;
  if SavesNeedPlaceholder then
  begin
    if PlaceholderPack(Game) then
    begin
      WriteLog(Game, 'DLC\99_tr_yama yer tutucuya çevrildi (' + DlcWhy + '). Kayıt dosyalarına dokunulmadı.');
      Result := 3;
    end
    else
    begin
      WriteLog(Game, 'Yer tutucu hazırlanamadı; DLC\99_tr_yama olduğu gibi bırakıldı (güvenli taraf).');
      Result := 4;
    end;
  end
  else
  begin
    Result := RemoveDlcSafe(Game);
    WriteLog(Game, 'DLC\99_tr_yama kaldırıldı (' + DlcWhy + ').');
  end;
end;

{ ---------------------------------------------- orijinal yedek bulma / geri yükleme }
function OrigIn(const Path, Orig: String): Boolean;
begin
  Result := FileExists(Path) and (Hash(Path) = Orig);
end;

{ Geçerli (SHA256'sı orijinal) yedeği bulur: önce _TR_yedek, sonra .bat kurulumlarının eski konumları. }
function FindOrig(const Dir, Name, Orig: String): String;
var
  L: String;
begin
  Result := '';
  L := Dir + '\data\language\en-uk';
  if OrigIn(Dir + '\_TR_yedek\' + Name, Orig) then
    Result := Dir + '\_TR_yedek\' + Name
  else if OrigIn(L + '\_TR_yedek\' + Name, Orig) then
    Result := L + '\_TR_yedek\' + Name
  else if OrigIn(Dir + '\_TR_yedek_supheli\' + Name, Orig) then
    Result := Dir + '\_TR_yedek_supheli\' + Name
  else if OrigIn(L + '\_TR_yedek_supheli\' + Name, Orig) then
    Result := L + '\_TR_yedek_supheli\' + Name;
end;

{ Orijinal dosyaları geri yükler ve doğrular. Oyun klasöründe yalnızca book.babel, gui_normal.bft
  yazılır ve _TR_yedek (izinli içerikle) silinir. Başka hiçbir şeye dokunulmaz. }
function DoRestore(const Dir: String): Boolean;
var
  Bak, SB, SF: String;
  AnyBak: Boolean;
  U: Integer;
begin
  Result := False;
  if (not IsGameDir(Dir)) or IsRootLike(Dir) then
  begin
    WriteLog(Dir, 'KALDIRMA: kayıtlı oyun klasörü geçerli bir Fable III klasörü değil, hiçbir dosyaya dokunulmadı: ' + Dir);
    SuppressibleMsgBox('Kayıtlı oyun klasörü geçerli bir Fable III klasörü olarak görünmüyor; oyun dosyalarına hiç dokunulmadı.' + #13#10 + Dir + #13#10#13#10 + 'Orijinale dönmek için Steam''de "Oyun dosyalarının bütünlüğünü doğrula" seçeneğini kullanın.', mbError, MB_OK, IDOK);
    Exit;
  end;
  Bak := Dir + '\_TR_yedek';
  case RetireDlc(Dir) of
    2: InfoBox(Dir, 'DLC\99_tr_yama klasöründe bu kurulumun oluşturmadığı dosyalar var; güvenlik için o klasörde hiçbir şey silinmedi. İsterseniz elle silebilirsiniz:' + #13#10 + DlcPkgDir(Dir), mbInformation);
    3: InfoBox(Dir, 'DLC\99_tr_yama klasörü SİLİNMEDİ; içi metin içermeyen boş bir YER TUTUCUYA çevrildi (' + DlcWhy + ').' + #13#10#13#10 +
         'Bu kayıtlar v1.1.0 ile alındığı için açılabilsin diye boş bir yer tutucu bırakıldı; oyuna hiçbir şey eklemez. ' +
         'Yamayı yeniden kurup oyunu bir kez kaydederseniz bu kayıtlar yamadan bağımsız olur.' + #13#10#13#10 +
         'Kayıt dosyalarınıza dokunulmadı (yalnızca okundu).', mbInformation);
    4: InfoBox(Dir, 'DLC\99_tr_yama için yer tutucu hazırlanamadı; kayıtlarınız açılabilsin diye paket olduğu gibi bırakıldı (' + DlcWhy + ').' + #13#10 +
         'Paket oyuna Türkçe DLC metni eklemeye devam eder. Yeniden denemek için kurulum programını çalıştırıp "Yamayı kaldır"ı seçin.', mbInformation);
  end;
  SB := FindOrig(Dir, 'book.babel', ORIG_BOOK);
  SF := FindOrig(Dir, 'gui_normal.bft', ORIG_FONT);
  if (SB = '') or (SF = '') then
  begin
    AnyBak := FileExists(Bak + '\book.babel') or FileExists(Bak + '\gui_normal.bft');
    if not AnyBak then
    begin
      WriteLog(Dir, 'KALDIRMA: yedek bulunamadı.');
      SuppressibleMsgBox('Orijinal dosya yedeği bulunamadı; oyundaki Türkçe dosyalar olduğu gibi kaldı.' + #13#10#13#10 + 'Orijinale dönmek için Steam''de oyunun Özellikler > Yerel Dosyalar > "Oyun dosyalarının bütünlüğünü doğrula" seçeneğini kullanın.', mbError, MB_OK, IDOK);
    end
    else
    begin
      WriteLog(Dir, 'KALDIRMA: yedek orijinal değil (book=' + IntToStr(Ord(SB <> '')) + ' font=' + IntToStr(Ord(SF <> '')) + ').');
      SuppressibleMsgBox('Yedekteki dosyalar ORİJİNAL oyun dosyalarıyla eşleşmiyor (eski bir yama ya da test dosyası yedeklenmiş olabilir); bu yüzden geri yüklenmedi ve yedek klasörü silinmedi.' + #13#10#13#10 + 'Orijinale dönmek için Steam''de "Oyun dosyalarının bütünlüğünü doğrula" seçeneğini kullanın.', mbError, MB_OK, IDOK);
    end;
    Exit;
  end;
  if (not FileCopy(SB, BookPath(Dir), False)) or (Hash(BookPath(Dir)) <> ORIG_BOOK) or
     (not FileCopy(SF, FontPath(Dir), False)) or (Hash(FontPath(Dir)) <> ORIG_FONT) then
  begin
    WriteLog(Dir, 'KALDIRMA: geri yükleme doğrulanamadı.');
    SuppressibleMsgBox('Orijinal dosyalar geri yüklenemedi ya da doğrulanamadı. Oyun açıksa kapatıp tekrar deneyin ya da Steam''de dosya bütünlüğünü doğrulayın.', mbError, MB_OK, IDOK);
    Exit;
  end;
  WriteLog(Dir, 'KALDIRMA: orijinal dosyalar geri yüklendi ve doğrulandı (kaynak: ' + SB + ').');
  Result := True;
  U := CountUnexpected(Dir);
  if U <> 0 then
  begin
    WriteLog(Dir, 'KALDIRMA: _TR_yedek içinde izinli listede olmayan ' + IntToStr(U) + ' öğe var; hiçbir şey silinmedi.');
    SuppressibleMsgBox('Orijinal dosyalar geri yüklendi, ancak _TR_yedek klasöründe bu kurulumun oluşturmadığı dosyalar var. Güvenlik için o klasörde hiçbir şey silinmedi; isterseniz elle silebilirsiniz:' + #13#10 + Bak, mbInformation, MB_OK, IDOK);
    Exit;
  end;
  RemoveBackupSafe(Dir);
  WriteLog(Dir, 'KALDIRMA: _TR_yedek temizlendi.');
end;

{ ---------------------------------------------- eski hatalı kurulum kaydı }
{ Önceki sürüm uygulama klasörü olarak OYUN klasörünü kullanıyordu. Böyle bir kayıt bulunursa kaydı siler,
  oyun klasöründeki eski unins000 dosyalarını kaldırır; oyun dosyalarına dokunmaz. }
function LooksLikeGameRoot(const Dir: String): Boolean;
begin
  Result := (Dir <> '') and (IsGameDir(Dir) or FileExists(Dir + '\Fable3.exe') or FileExists(Dir + '\FableLauncher.exe') or DirExists(Dir + '\data\language'));
end;

function CleanOldRecord(Root: Integer): String;
var
  K, Loc, U, B, D: String;
  DatTxt: AnsiString;
begin
  Result := '';
  K := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1';
  Loc := '';
  if not RegQueryStringValue(Root, K, 'InstallLocation', Loc) then
    Exit;
  Loc := RemoveBackslash(Loc);
  if not LooksLikeGameRoot(Loc) then
    Exit;
  U := '';
  RegQueryStringValue(Root, K, 'UninstallString', U);
  U := RemoveQuotes(U);
  RegDeleteKeyIncludingSubkeys(Root, K);
  Result := 'Eski hatalı kaldırma kaydı silindi (oyun klasörünü uygulama klasörü sayıyordu): ' + Loc;
  if (U <> '') and (CompareText(RemoveBackslash(ExtractFileDir(U)), Loc) = 0) and (Pos('unins', Lowercase(ExtractFileName(U))) = 1) then
  begin
    B := Copy(U, 1, Length(U) - Length(ExtractFileExt(U)));
    D := '';
    { yalnızca BİZİM kaldırıcımızsa sil: unins*.dat içinde bizim AppId'miz geçmeli (başka bir kurulum programınınki silinmez) }
    DatTxt := '';
    if not (FileExists(B + '.dat') and LoadStringFromFile(B + '.dat', DatTxt) and (Pos('7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411', DatTxt) > 0)) then
    begin
      Result := Result + ' | ' + ExtractFileName(U) + ' bize ait görünmediği için silinmedi';
      Exit;
    end;
    if FileExists(U) then if DeleteFile(U) then D := D + ' exe';
    if FileExists(B + '.dat') then if DeleteFile(B + '.dat') then D := D + ' dat';
    if FileExists(B + '.msg') then if DeleteFile(B + '.msg') then D := D + ' msg';
    Result := Result + ' | silinen eski kaldırıcı dosyaları:' + D;
  end;
end;

{ ------------------------------------------------------- oyun klasörü doğrulama }
function LangList(const Game: String): String;
var
  FR: TFindRec;
begin
  Result := '';
  if FindFirst(Game + '\data\language\*', FR) then
  try
    repeat
      if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and (FR.Name <> '.') and (FR.Name <> '..') then
      begin
        if Result <> '' then Result := Result + ', ';
        Result := Result + FR.Name;
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
end;

{ Seçilen klasörün altında (en çok 2 düzey) Fable III klasörü ara. }
function FindGameBelow(const Root: String; Depth: Integer): String;
var
  FR: TFindRec;
  S: String;
begin
  Result := '';
  if Depth < 0 then
    Exit;
  if FindFirst(AddBackslash(Root) + '*', FR) then
  try
    repeat
      if ((FR.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) and (FR.Name <> '.') and (FR.Name <> '..') then
      begin
        S := AddBackslash(Root) + FR.Name;
        if IsGameDir(S) then
        begin
          Result := S;
          Break;
        end;
        if Depth > 0 then
        begin
          Result := FindGameBelow(S, Depth - 1);
          if Result <> '' then Break;
        end;
      end;
    until not FindNext(FR);
  finally
    FindClose(FR);
  end;
end;

{ Kullanıcı data\... gibi alt klasörü seçtiyse üst klasörlerde ara. }
function FindGameAbove(const D: String): String;
var
  P, Q: String;
  I: Integer;
begin
  Result := '';
  P := RemoveBackslash(D);
  for I := 1 to 6 do
  begin
    Q := RemoveBackslash(ExtractFileDir(P));
    if (Q = '') or (Q = P) then Break;
    P := Q;
    if IsGameDir(P) then
    begin
      Result := P;
      Break;
    end;
  end;
end;

function WhyNotGame(const D: String): String;
var
  Langs: String;
begin
  Langs := LangList(D);
  if DirExists(D + '\data\language') then
  begin
    if not DirExists(D + '\data\language\en-uk') then
      Result := 'Bu klasörde Fable III var gibi görünüyor ancak İngilizce (UK) dil klasörü (data\language\en-uk) yok.' + #13#10 +
                'Bulunan diller: ' + Langs + #13#10#13#10 + 'Yama yalnızca İngilizce (UK) dil dosyalarını değiştirir. Oyunun dil klasörleri eksikse Steam''de dosya bütünlüğünü doğrulayın.'
    else
    begin
      Result := 'Bu klasörde data\language\en-uk var, ancak şu dosyalar eksik:' + #13#10;
      if not FileExists(BookPath(D)) then Result := Result + '  data\language\en-uk\text\book.babel' + #13#10;
      if not FileExists(FontPath(D)) then Result := Result + '  data\language\en-uk\fonts\gui_normal.bft' + #13#10;
      Result := Result + #13#10 + 'Bulunan diller: ' + Langs + #13#10#13#10 + 'Oyun hâlâ indiriliyorsa bitmesini bekleyin; ya da Steam''de dosya bütünlüğünü doğrulayın.';
    end;
  end
  else
    Result := 'Bu bir Fable III klasörü değil.' + #13#10#13#10 + 'Seçilen klasörde şu dosyalar bulunamadı:' + #13#10 + 'data\language\en-uk\text\book.babel' + #13#10 + 'data\language\en-uk\fonts\gui_normal.bft' + #13#10#13#10 + 'Oyunun kurulu olduğu klasörü seçin (dilin İngilizce (UK) olması gerekir).';
end;

{ Seçimi çözer: geçerliyse (üst/alt klasörde bulunmuş olsa da) D güncellenir ve True döner. }
function ResolveGameDir(var D: String): Boolean;
var
  Found, Msg: String;
begin
  D := RemoveBackslash(D);
  Result := IsGameDir(D);
  if Result then
    Exit;
  Found := FindGameAbove(D);
  Msg := 'Seçtiğiniz klasör doğrudan oyun klasörü değil. Oyun şurada bulundu ve bu klasör kullanılacak:';
  if Found = '' then
  begin
    Found := FindGameBelow(D, 1);
  end;
  if Found <> '' then
  begin
    SuppressibleMsgBox(Msg + #13#10#13#10 + Found, mbInformation, MB_OK, IDOK);
    D := Found;
    Result := True;
  end
  else
    SuppressibleMsgBox(WhyNotGame(D), mbError, MB_OK, IDOK);
end;

function AppDirBad(const App, Game: String): Boolean;
var
  A, G: String;
begin
  A := Lowercase(RemoveBackslash(App));
  G := Lowercase(RemoveBackslash(Game));
  Result := LooksLikeGameRoot(RemoveBackslash(App)) or (A = G) or (Pos(G + '\', A + '\') = 1);
end;

{ ------------------------------------------------------------- sihirbaz }
function GameDirValue: String;
begin
  if GamePageReady then
    Result := RemoveBackslash(GamePage.Values[0])
  else
    Result := '';
end;

function GameDirP(Param: String): String;
begin
  Result := GameDirValue;
end;

function HasLauncher: Boolean;
begin
  Result := FileExists(GameDirValue + '\FableLauncher.exe');
end;

procedure DetectInstalled;
var
  FontPatched: Boolean;
  HB, HF, SB, SF: String;
begin
  IsInstalled := False;
  InstDir := CandidateDir;
  if not IsGameDir(InstDir) then
    Exit;
  InstBM := BookModeOf(Hash(BookPath(InstDir)));
  FontPatched := IsKnownFont(Hash(FontPath(InstDir)));
  IsInstalled := (InstBM <> 0) or FontPatched;
  if not IsInstalled then
    Exit;
  { dosya hash'i kayıt defterinden daha güvenilirdir }
  { dosya hash'i kayıt defterinden daha güvenilirdir: 1 = güncel sürüm, 2 = eski sürüm (Standart ya da eski Tam altyazı) }
  InstVer := RegRead('Surum');
  if InstVer = '' then
  begin
    if InstBM = 1 then InstVer := '{#Version}'
    else if InstBM = 2 then InstVer := 'eski sürüm'
    else InstVer := 'bilinmiyor';
  end;
  HB := Hash(BookPath(InstDir));
  HF := Hash(FontPath(InstDir));
  if HB = ORIG_BOOK then SB := 'orijinal'
  else if InstBM = 1 then SB := 'yama (güncel sürüm)'
  else if InstBM = 2 then SB := 'yama (eski sürüm)'
  else SB := 'bilinmeyen (ne orijinal ne bizim yamamız)';
  if HF = ORIG_FONT then SF := 'orijinal'
  else if HF = EXP_FONT then SF := 'yama (güncel sürüm)'
  else if IsKnownFont(HF) then SF := 'yama (eski sürüm)'
  else SF := 'bilinmeyen (ne orijinal ne bizim yamamız)';
  InstModeText := 'book.babel: ' + SB + #13#10 + 'gui_normal.bft: ' + SF;
end;

{ ------------------------------------------------------------ kendi kendini sınama (/SELFTEST=günlük.txt /ORIGDIR=klasör) }
procedure SelfLog(const F, S: String);
begin
  SaveStringToFile(F, S + #13#10, True);
end;

{ Gömülü paketleri, xdelta3'ü ve f3patch'i sınar; ORIGDIR (içinde book.babel ve gui_normal.bft ORİJİNALLERİ) verilmişse
  iki modda kitabı, ayrıca fontu üretip beklenen SHA256 ile karşılaştırır. Oyun klasörüne ve kayıt defterine HİÇ dokunmaz. }
function RunSelfTest(const LogF, OrigDir: String): Boolean;
var
  Tmp, Cmd, H: String;
  RC, I: Integer;
  Names: array[0..6] of String;
begin
  Result := True;
  DeleteFile(LogF);
  SelfLog(LogF, 'Fable III Türkçe Yama - kendi kendini sınama, sürüm ' + '{#Version}');
  try
    SelfLog(LogF, 'Çıkarılan dosya sayısı: ' + IntToStr(ExtractTemporaryFiles('*')));
  except
    SelfLog(LogF, 'HATA   gömülü dosyalar çıkarılamadı: ' + GetExceptionMessage);
    Result := False;
    Exit;
  end;
  Tmp := ExpandConstant('{tmp}');
  SelfLog(LogF, 'Geçici klasör: ' + Tmp);
  Names[0] := 'book_pack.lzma';
  Names[1] := 'font.xdelta';
  Names[2] := 'xdelta3.exe';
  Names[3] := 'f3patch\f3patch.exe';
  Names[4] := 'placeholder\both\99_tr_yama\content.xbx';
  Names[5] := 'placeholder\us\99_tr_yama\Content\tr_yama_us.bnk';
  Names[6] := 'placeholder\tk\99_tr_yama\Content\tr_yama_tk.bnk.dat';
  for I := 0 to 6 do
    if FileExists(Tmp + '\' + Names[I]) then
      SelfLog(LogF, 'TAMAM  gömülü dosya: ' + Names[I])
    else
    begin
      SelfLog(LogF, 'HATA   gömülü dosya eksik: ' + Names[I]);
      Result := False;
    end;
  if not Result then Exit;
  if Exec(Tmp + '\xdelta3.exe', '-V', Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) then
    SelfLog(LogF, 'TAMAM  xdelta3 çalışıyor')
  else
  begin
    SelfLog(LogF, 'HATA   xdelta3 çalışmadı (kod ' + IntToStr(RC) + ')');
    Result := False;
  end;
  if Exec(Tmp + '\f3patch\f3patch.exe', 'book', Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 2) then
    SelfLog(LogF, 'TAMAM  f3patch çalışıyor (eksik argümanda kod 2 verdi)')
  else
  begin
    SelfLog(LogF, 'HATA   f3patch beklenen davranışı vermedi (kod ' + IntToStr(RC) + ')');
    Result := False;
  end;
  if OrigDir = '' then
  begin
    SelfLog(LogF, 'ATLANDI orijinal dosya verilmedi (/ORIGDIR): uygulama sınaması yapılmadı');
    Exit;
  end;
  if (Hash(OrigDir + '\book.babel') <> ORIG_BOOK) or (Hash(OrigDir + '\gui_normal.bft') <> ORIG_FONT) then
  begin
    SelfLog(LogF, 'HATA   ORIGDIR içindeki dosyalar desteklenen orijinaller değil');
    Result := False;
    Exit;
  end;
  { yamalı kitap (tam altyazı: tek sonuç) }
  DeleteFile(Tmp + '\o.bin');
  FileCopy(OrigDir + '\book.babel', Tmp + '\o.bin', False);
  DeleteFile(Tmp + '\book_out.bin');
  Cmd := 'book --orig o.bin --pack book_pack.lzma --orig-sha ' + ORIG_BOOK + ' --expect ' + EXP_BOOK + ' --out book_out.bin';
  H := '';
  if Exec(Tmp + '\f3patch\f3patch.exe', Cmd, Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) then H := Hash(Tmp + '\book_out.bin');
  if H = EXP_BOOK then SelfLog(LogF, 'TAMAM  book.babel (tam altyazi) ' + H)
  else begin SelfLog(LogF, 'HATA   book.babel (kod ' + IntToStr(RC) + ') ' + H); Result := False; end;
  { orijinal olmayan girdi reddedilmeli ve çıktı yazılmamalı }
  DeleteFile(Tmp + '\book_out.bin');
  SaveStringToFile(Tmp + '\o.bin', 'bu orijinal degil', False);
  Cmd := 'book --orig o.bin --pack book_pack.lzma --orig-sha ' + ORIG_BOOK + ' --expect ' + EXP_BOOK + ' --out book_out.bin';
  if Exec(Tmp + '\f3patch\f3patch.exe', Cmd, Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 3) and (not FileExists(Tmp + '\book_out.bin')) then
    SelfLog(LogF, 'TAMAM  orijinal olmayan girdi reddedildi (kod 3, çıktı yazılmadı)')
  else begin SelfLog(LogF, 'HATA   orijinal olmayan girdi reddedilmedi (kod ' + IntToStr(RC) + ')'); Result := False; end;
  { font }
  DeleteFile(Tmp + '\o.bin');
  FileCopy(OrigDir + '\gui_normal.bft', Tmp + '\o.bin', False);
  DeleteFile(Tmp + '\font_out.bin');
  H := '';
  if Exec(Tmp + '\xdelta3.exe', '-d -f -s o.bin font.xdelta font_out.bin', Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) then H := Hash(Tmp + '\font_out.bin');
  if H = EXP_FONT then SelfLog(LogF, 'TAMAM  gui_normal.bft ' + H)
  else begin SelfLog(LogF, 'HATA   gui_normal.bft (kod ' + IntToStr(RC) + ') ' + H); Result := False; end;
  { DLC paketi: ORIGDIR\DLC varsa (sahte/gerçek oyun kopyası) f3patch dlc sınanır; DLC dosyalarına yazılmaz }
  if DirExists(OrigDir + '\DLC') then
  begin
    DeleteFile(Tmp + '\dlc_out\rapor.txt');
    if Exec(Tmp + '\f3patch\f3patch.exe', 'dlc --game "' + OrigDir + '" --pack book_pack.lzma --out dlc_out --version {#Version}', Tmp, SW_HIDE, ewWaitUntilTerminated, RC) and (RC = 0) and
       FileExists(Tmp + '\dlc_out\rapor.txt') then
      SelfLog(LogF, 'TAMAM  f3patch dlc raporu uretildi')
    else begin SelfLog(LogF, 'HATA   f3patch dlc (kod ' + IntToStr(RC) + ')'); Result := False; end;
  end;
end;

{ Zip içinden (Gezgin'in geçici açtığı klasörden) çalıştırılıyor mu? }
function RunningFromZip: Boolean;
var
  P: String;
begin
  P := Lowercase(ExpandConstant('{srcexe}'));
  Result := (Pos('.zip\', P) > 0) or (Pos('.zip/', P) > 0);
end;

function InitializeSetup: Boolean;
var
  LogF: String;
begin
  Result := True;
  LogF := ExpandConstant('{param:SELFTEST|}');
  if LogF <> '' then
  begin
    if RunSelfTest(LogF, ExpandConstant('{param:ORIGDIR|}')) then
      SelfLog(LogF, 'SONUC: GECTI')
    else
      SelfLog(LogF, 'SONUC: BASARISIZ');
    Result := False;
    Exit;
  end;
  if RunningFromZip then
  begin
    SuppressibleMsgBox('Kurulum programı bir zip dosyasının içinden çalıştırılıyor.' + #13#10#13#10 +
      'Lütfen zip dosyasını önce bir klasöre çıkarın (sağ tık > Tümünü ayıkla), sonra kurulum programını o klasörden çalıştırın.',
      mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
  CleanNote := CleanOldRecord(HKLM);
  if CleanNote = '' then
    CleanNote := CleanOldRecord(HKCU)
  else
    CleanOldRecord(HKCU);
end;

procedure InitializeWizard;
var
  G: String;
  I: Integer;
begin
  GamePage := CreateInputDirPage(wpWelcome, 'Oyun klasörünü seçin',
    'Fable III oyun klasörü', 'Fable III oyun klasörü aşağıda gösterilmiştir. Farklıysa "Gözat" ile oyunun kurulu olduğu klasörü seçin. Yama programı bu klasöre KURULMAZ; yalnızca oyunun dil dosyaları (ve DLC kuruluysa kendi DLC klasörümüz) değiştirilir.',
    False, '');
  GamePage.Add('');
  G := CandidateDir;
  if G = '' then G := 'C:\Games\Fable 3';
  GamePage.Values[0] := G;
  GamePageReady := True;

  { birden fazla Fable III klasörü bulunduysa listeden seçtir }
  if (ExpandConstant('{param:GAME|}') = '') and (NC > 1) then
  begin
    PickPage := CreateInputOptionPage(wpWelcome, 'Birden fazla Fable III bulundu',
      'Hangi oyun klasörüne kurulsun?', 'Bilgisayarınızda birden fazla Fable III klasörü bulundu. Birini seçin (sonraki sayfada değiştirebilirsiniz).', True, False);
    for I := 0 to NC - 1 do
      PickPage.Add(Cands[I] + '   (' + CandSrc[I] + ')');
    PickPage.SelectedValueIndex := 0;
    PickReady := True;
  end;

  LaunchCheck := TNewCheckBox.Create(WizardForm);
  LaunchCheck.Parent := WizardForm.FinishedPage;
  LaunchCheck.Caption := 'Oyunu başlat (FableLauncher.exe)';
  LaunchCheck.Checked := True;

  InstChoice := -1;
  DetectInstalled;
  if IsInstalled then
  begin
    InstPage := CreateCustomPage(wpWelcome, 'Yama zaten kurulu', 'Kurulu sürüm: ' + InstVer);
    InstDesc[0] := 'Yama yeniden kurulur (tüm konuşmalarda Türkçe altyazı + DLC metinleri). Orijinal yedeğe dokunulmaz.';
    if InstBM = 2 then
      InstDesc[0] := 'Güncel sürüme geçilir (tüm konuşmalarda Türkçe altyazı + DLC metinleri). Orijinal yedeğinize dokunulmaz.';
    InstDesc[1] := 'Orijinal dosyalar yedekten geri yüklenir; DLC klasörümüz silinir.';
    InstDesc[2] := 'Hiçbir değişiklik yapmadan kapat.';
    InstTitle[0] := 'Yeniden kur / onar';
    InstTitle[1] := 'Yamayı kaldır';
    InstTitle[2] := 'Çık';
    with TNewStaticText.Create(InstPage) do
    begin
      Parent := InstPage.Surface;
      AutoSize := False;
      WordWrap := True;
      Left := 0;
      Top := 0;
      Width := InstPage.SurfaceWidth;
      Height := ScaleY(32);
      Caption := InstModeText;
    end;
    for I := 0 to 2 do
    begin
      InstRB[I] := TNewRadioButton.Create(InstPage);
      InstRB[I].Parent := InstPage.Surface;
      InstRB[I].Left := 0;
      InstRB[I].Top := ScaleY(48 + I * 62);
      InstRB[I].Width := InstPage.SurfaceWidth;
      InstRB[I].Height := ScaleY(20);
      InstRB[I].Caption := InstTitle[I];
      InstRB[I].Checked := (I = 0);
      InstRB[I].TabStop := True;
    end;
    for I := 0 to 2 do
    begin
      with TNewStaticText.Create(InstPage) do
      begin
        Parent := InstPage.Surface;
        AutoSize := False;
        WordWrap := True;
        Left := ScaleX(20);
        Top := ScaleY(48 + I * 62 + 22);
        Width := InstPage.SurfaceWidth - ScaleX(20);
        Height := ScaleY(32);
        Caption := InstDesc[I];
      end;
    end;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if not IsInstalled then
    Exit;
  { yama kuruluyken: yeniden kur / onar seçildiyse klasör sayfaları atlanır }
  if PageID = GamePage.ID then
    Result := (InstChoice = 0)
  else if PickReady and (PageID = PickPage.ID) then
    Result := (InstChoice = 0);
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if ExitNow then
    Confirm := False;
end;

{ Verilen kökteki kaldırma kaydı, TAM OLARAK bu oyun klasörüne ait mi? (başka bir kurulumun kaldırıcısı çalıştırılmaz) }
function UninstallerFor(Root: Integer; const Game: String): String;
var
  S, K, Reg: String;
begin
  Result := '';
  S := '';
  K := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{7C1D3B52-5E0A-4B53-9A6E-F3A1B7D2C411}_is1';
  if not RegQueryStringValue(Root, K, 'UninstallString', S) then
    Exit;
  S := RemoveQuotes(S);
  if not FileExists(S) then
    Exit;
  Reg := '';
  RegQueryStringValue(Root, 'SOFTWARE\Fable3TurkceYama', 'OyunKlasoru', Reg);
  if CompareText(RemoveBackslash(Reg), RemoveBackslash(Game)) = 0 then
    Result := S;
end;

function UninstallerPath: String;
begin
  Result := UninstallerFor(HKLM, InstDir);
  if Result = '' then
    Result := UninstallerFor(HKCU, InstDir);
end;

function DlcSummary: String;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to GetArrayLength(DlcRep) - 1 do
    if Pos('OK|Content\tr_yama_', DlcRep[I]) = 1 then
      if Pos('.bnk|', DlcRep[I]) > 0 then N := N + 1;
  if N > 0 then
    Result := #13#10#13#10 + 'DLC metinleri de Türkçeleştirildi (' + IntToStr(N) + ' DLC paketi).'
  else
    Result := '';
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if IsInstalled and (CurPageID = InstPage.ID) then
    WizardForm.ActiveControl := InstRB[0];
  if CurPageID = GamePage.ID then
  begin
    if DetectedFrom <> '' then
      WizardForm.PageDescriptionLabel.Caption := 'Fable III otomatik bulundu (' + DetectedFrom + ').'
    else
      WizardForm.PageDescriptionLabel.Caption := 'Fable III otomatik bulunamadı; lütfen klasörü seçin.';
  end;
  if CurPageID = wpFinished then
  begin
    WizardForm.FinishedLabel.Caption := 'Fable III Türkçe Yama kuruldu ve doğrulandı.' + DlcSummary + #13#10#13#10 + 'Orijinal dosyalar oyun klasöründeki _TR_yedek klasörüne yedeklendi. Kaldırmak için Windows "Uygulamalar ve Özellikler" listesinden "Fable III Türkçe Yama"yı kaldırın (ya da bu kurulum programını yeniden çalıştırıp "Yamayı kaldır"ı seçin).' + #13#10#13#10 + 'ÖNEMLİ: Altyazıların görünmesi için oyunun Seçenekler menüsünde "Altyazılar" ayarı açık olmalıdır. Oyun yalnızca FableLauncher.exe ile başlar. Steam''de "Oyun dosyalarının bütünlüğünü doğrula" yamayı siler; bunu yaparsanız bu kurulumu yeniden çalıştırın.';
    WizardForm.FinishedLabel.Height := ScaleY(235);
    LaunchCheck.Left := WizardForm.FinishedLabel.Left;
    LaunchCheck.Width := WizardForm.FinishedLabel.Width;
    LaunchCheck.Top := WizardForm.FinishedLabel.Top + WizardForm.FinishedLabel.Height + ScaleY(8);
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var
  U, D: String;
  RC: Integer;
begin
  Result := True;
  if IsInstalled and (CurPageID = InstPage.ID) then
  begin
    InstChoice := 0;
    if InstRB[1].Checked then InstChoice := 1
    else if InstRB[2].Checked then InstChoice := 2;
    if InstChoice = 0 then
      GamePage.Values[0] := InstDir
    else if InstChoice = 1 then
    begin
      if GameRunning then
      begin
        SuppressibleMsgBox('Fable III (Fable3.exe / FableLauncher.exe) açık görünüyor. Lütfen oyunu ve başlatıcıyı kapatın, sonra tekrar deneyin.', mbError, MB_OK, IDOK);
        Result := False;
        Exit;
      end;
      U := UninstallerPath;
      if U <> '' then
        Exec(U, '', ExpandConstant('{sys}'), SW_SHOWNORMAL, ewWaitUntilTerminated, RC)
      else
      begin
        WriteLog(InstDir, 'KALDIRMA (kurulum programından): kaldırma kaydı yok, doğrudan geri yükleme.');
        if DoRestore(InstDir) then
          InfoBox(InstDir, 'Türkçe yama kaldırıldı; orijinal dosyalar geri yüklendi ve doğrulandı.', mbInformation);
      end;
      ExitNow := True;
      WizardForm.Close;
    end
    else
    begin
      ExitNow := True;
      WizardForm.Close;
    end;
    Exit;
  end;
  if PickReady and (CurPageID = PickPage.ID) then
    GamePage.Values[0] := Cands[PickPage.SelectedValueIndex];
  if CurPageID = GamePage.ID then
  begin
    D := GamePage.Values[0];
    if ResolveGameDir(D) then
      GamePage.Values[0] := D
    else
      Result := False;
  end;
end;

{ --------------------------------------------------------- ön kontroller }
function StatusName(C: Integer; IsOld: Boolean): String;
begin
  if C = 0 then
    Result := 'orijinal'
  else if C = 1 then
  begin
    if IsOld then Result := 'eski yama sürümü' else Result := 'güncel yama sürümü';
  end
  else
    Result := 'bilinmeyen';
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Dir, HB, HF, Msg, Lines: String;
  CB, CF: Integer; { 0 orijinal, 1 bizim yama, 2 bilinmeyen }
  OwnB, OwnF, FoundB, FoundF: String;
  BadB, BadF: Boolean;
begin
  Result := '';
  Dir := GameDirValue;
  LogAllowed := True;
  BakSrcBook := ''; BakSrcFont := ''; OrigSrcBook := ''; OrigSrcFont := ''; QuarBook := False; QuarFont := False; SaveUnkBook := False; SaveUnkFont := False;
  if not IsGameDir(Dir) then
  begin
    Result := 'Bu bir Fable III klasörü değil: ' + Dir;
    Exit;
  end;
  if AppDirBad(WizardDirValue, Dir) then
  begin
    Result := 'Güvenlik: kurulum programının kendi klasörü oyun klasörü olamaz: ' + WizardDirValue;
    Exit;
  end;
  if GameRunning then
  begin
    Result := 'Fable III (Fable3.exe / FableLauncher.exe) açık görünüyor. Lütfen oyunu ve başlatıcıyı kapatın, sonra tekrar deneyin.';
    Exit;
  end;
  HB := Hash(BookPath(Dir));
  HF := Hash(FontPath(Dir));
  { iki dosya birbirinden bağımsız değerlendirilir }
  if HB = ORIG_BOOK then CB := 0 else if IsKnownBook(HB) then CB := 1 else CB := 2;
  if HF = ORIG_FONT then CF := 0 else if IsKnownFont(HF) then CF := 1 else CF := 2;
  OwnB := '';
  if OrigIn(Dir + '\_TR_yedek\book.babel', ORIG_BOOK) then OwnB := Dir + '\_TR_yedek\book.babel';
  OwnF := '';
  if OrigIn(Dir + '\_TR_yedek\gui_normal.bft', ORIG_FONT) then OwnF := Dir + '\_TR_yedek\gui_normal.bft';
  FoundB := FindOrig(Dir, 'book.babel', ORIG_BOOK);
  FoundF := FindOrig(Dir, 'gui_normal.bft', ORIG_FONT);
  if CleanNote <> '' then WriteLog(Dir, CleanNote);
  WriteLog(Dir, '--- KURULUM v{#Version} | klasör: ' + Dir);
  WriteLog(Dir, 'book.babel mevcut: ' + HB + ' (' + StatusName(CB, BookModeOf(HB) = 2) + ')');
  WriteLog(Dir, 'gui_normal.bft mevcut: ' + HF + ' (' + StatusName(CF, False) + ')');
  WriteLog(Dir, 'orijinal yedek: book=' + FoundB + ' | font=' + FoundF);

  { book.babel }
  BadB := False;
  if OwnB <> '' then
    { zaten geçerli yedek var: dokunma }
  else if CB = 0 then
  begin
    BakSrcBook := BookPath(Dir);
    QuarBook := FileExists(Dir + '\_TR_yedek\book.babel');
  end
  else if FoundB <> '' then
  begin
    BakSrcBook := FoundB;
    QuarBook := FileExists(Dir + '\_TR_yedek\book.babel');
    WriteLog(Dir, 'book.babel: orijinal yedek eski konumdan alındı: ' + FoundB);
  end
  else
    BadB := True;
  SaveUnkBook := (CB = 2);
  { gui_normal.bft }
  BadF := False;
  if OwnF <> '' then
  else if CF = 0 then
  begin
    BakSrcFont := FontPath(Dir);
    QuarFont := FileExists(Dir + '\_TR_yedek\gui_normal.bft');
  end
  else if FoundF <> '' then
  begin
    BakSrcFont := FoundF;
    QuarFont := FileExists(Dir + '\_TR_yedek\gui_normal.bft');
    WriteLog(Dir, 'gui_normal.bft: orijinal yedek eski konumdan alındı: ' + FoundF);
  end
  else
    BadF := True;
  SaveUnkFont := (CF = 2);

  { delta yöntemi orijinal dosyaya ihtiyaç duyar: güncel orijinal (oyundaki ya da geçerli yedek) yoksa HİÇBİR ŞEY değiştirilmez }
  if CB = 0 then OrigSrcBook := BookPath(Dir) else OrigSrcBook := FoundB;
  if CF = 0 then OrigSrcFont := FontPath(Dir) else OrigSrcFont := FoundF;
  Msg := '';
  if BadB or BadF then
  begin
    Lines := '';
    if BadB then Lines := Lines + '  • book.babel: ' + StatusName(CB, BookModeOf(HB) = 2) + ' (SHA256 ' + Copy(HB, 1, 12) + '…); desteklenen orijinal: ' + Copy(ORIG_BOOK, 1, 12) + '…' + #13#10;
    if BadF then Lines := Lines + '  • gui_normal.bft: ' + StatusName(CF, False) + ' (SHA256 ' + Copy(HF, 1, 12) + '…); desteklenen orijinal: ' + Copy(ORIG_FONT, 1, 12) + '…' + #13#10;
    WriteLog(Dir, 'DURDU: orijinal dosya bulunamadı; hiçbir şey değiştirilmedi.');
    Result := 'Bu oyun sürümü desteklenmiyor ya da oyun dosyaları değişmiş. Hiçbir şey değiştirilmedi.' + #13#10#13#10 +
              'Yama, orijinal oyun dosyalarından üretilir; şu dosyalar için geçerli bir orijinal bulunamadı:' + #13#10#13#10 + Lines + #13#10 +
              'Çözüm: Steam''de oyunun Özellikler > Yerel Dosyalar > "Oyun dosyalarının bütünlüğünü doğrula" seçeneğini çalıştırın, sonra bu kurulumu tekrarlayın. Oyunun farklı bir sürümünü kullanıyorsanız bu yama uyumlu olmayabilir.';
    Exit;
  end;
end;

{ ------------------------------------------------------------ oyunu başlat }
{ ShellExec kullanılır: FableLauncher.exe yönetici izni istiyorsa (hata 740) Windows UAC sorabilir. }
procedure LaunchGame(const Dir: String);
var
  L: String;
  RC: Integer;
begin
  L := Dir + '\FableLauncher.exe';
  if FileExists(L) then
  begin
    if ShellExec('open', L, '', Dir, SW_SHOWNORMAL, ewNoWait, RC) then
    begin
      WriteLog(Dir, 'Oyun başlatıldı: FableLauncher.exe (ShellExec).');
      Exit;
    end;
    WriteLog(Dir, 'FableLauncher.exe başlatılamadı (hata kodu ' + IntToStr(RC) + ').');
    if RC = 1223 then
    begin
      WriteLog(Dir, 'Yükseltme (UAC) kullanıcı tarafından iptal edildi; oyun başlatılmadı.');
      Exit;
    end;
  end;
  if ExpandConstant('{param:TESTLAUNCH|0}') = '1' then
  begin
    WriteLog(Dir, 'TEST: Steam yedeği çağrılacaktı (steam://rungameid/105400).');
    SuppressibleMsgBox('Oyunu FableLauncher.exe ile başlatabilirsiniz.', mbInformation, MB_OK, IDOK);
    Exit;
  end;
  if ShellExec('open', 'steam://rungameid/105400', '', '', SW_SHOWNORMAL, ewNoWait, RC) then
  begin
    WriteLog(Dir, 'Oyun Steam üzerinden başlatıldı (steam://rungameid/105400).');
    Exit;
  end;
  WriteLog(Dir, 'Steam ile de başlatılamadı (hata kodu ' + IntToStr(RC) + ').');
  SuppressibleMsgBox('Oyunu FableLauncher.exe ile başlatabilirsiniz.', mbInformation, MB_OK, IDOK);
end;

{ ------------------------------------------------------------ kurulum }
procedure Fail(const Dir, Msg: String);
begin
  WriteLog(Dir, 'HATA: ' + Msg);
  RaiseException(Msg + #13#10#13#10 + 'Ayrıntılar: ' + LogPath(Dir));
end;

procedure Quarantine(const Dir, Name: String);
var
  Q: String;
begin
  Q := Dir + '\_TR_yedek\supheli';
  ForceDirectories(Q);
  if FileCopy(Dir + '\_TR_yedek\' + Name, Q + '\' + Name + '.' + GetDateTimeString('yyyymmdd_hhnnss', '-', ':'), False) then
    DeleteFile(Dir + '\_TR_yedek\' + Name);
  WriteLog(Dir, 'Geçersiz eski yedek karantinaya alındı: ' + Name);
end;

procedure RestorePrev(const Dir: String);
begin
  if FileExists(ExpandConstant('{tmp}\prev_book')) then FileCopy(ExpandConstant('{tmp}\prev_book'), BookPath(Dir), False);
  if FileExists(ExpandConstant('{tmp}\prev_font')) then FileCopy(ExpandConstant('{tmp}\prev_font'), FontPath(Dir), False);
  WriteLog(Dir, 'Önceki dosyalar geri yüklendi.');
end;

{ Kitap: kullanıcının kendi book.babel dosyasından, çeviri paketiyle f3patch yardımcısı üretir. Çıkış kodları: bkz. f3patch.py }
procedure ApplyBook(const Dir, OrigPath, Expected: String);
var
  Tmp, Cmd: String;
  RC: Integer;
begin
  Tmp := ExpandConstant('{tmp}');
  DeleteFile(Tmp + '\o.bin');
  DeleteFile(Tmp + '\book_out.bin');
  if (OrigPath = '') or (not FileCopy(OrigPath, Tmp + '\o.bin', False)) then
    Fail(Dir, 'Orijinal dosya okunamadı: ' + OrigPath);
  Cmd := 'book --orig o.bin --pack book_pack.lzma --orig-sha ' + ORIG_BOOK + ' --expect ' + Expected + ' --out book_out.bin';
  if not Exec(Tmp + '\f3patch\f3patch.exe', Cmd, Tmp, SW_HIDE, ewWaitUntilTerminated, RC) then
    Fail(Dir, 'Yardımcı program (f3patch) çalıştırılamadı (antivirüs engellemiş olabilir).');
  if RC = 3 then
    Fail(Dir, 'book.babel orijinal sürümle eşleşmiyor; hiçbir şey değiştirilmedi.');
  if RC <> 0 then
    Fail(Dir, 'Yamalı book.babel üretilemedi (yardımcı çıkış kodu ' + IntToStr(RC) + '); hiçbir şey değiştirilmedi.');
  if Hash(Tmp + '\book_out.bin') <> Expected then
    Fail(Dir, 'Üretilen book.babel SHA256 değeri beklenenle uyuşmuyor; hiçbir şey değiştirilmedi.');
  WriteLog(Dir, 'book.babel çeviri paketinden üretildi ve doğrulandı (tam altyazı): ' + Expected);
end;

{ xdelta3 ASCII argv kullanır: dosyalar geçici klasörde ASCII adlarla, çalışma dizini geçici klasör olarak işlenir. }
procedure ApplyDelta(const Dir, OrigPath, DeltaName, Expected, OutName: String);
var
  Tmp: String;
  RC: Integer;
begin
  Tmp := ExpandConstant('{tmp}');
  DeleteFile(Tmp + '\o.bin');
  DeleteFile(Tmp + '\' + OutName);
  if (OrigPath = '') or (not FileCopy(OrigPath, Tmp + '\o.bin', False)) then
    Fail(Dir, 'Orijinal dosya okunamadı: ' + OrigPath);
  if not Exec(Tmp + '\xdelta3.exe', '-d -f -s o.bin ' + DeltaName + ' ' + OutName, Tmp, SW_HIDE, ewWaitUntilTerminated, RC) then
    Fail(Dir, 'xdelta3 çalıştırılamadı.');
  if RC <> 0 then
    Fail(Dir, 'Delta uygulanamadı (xdelta3 çıkış kodu ' + IntToStr(RC) + '): ' + DeltaName);
  if Hash(Tmp + '\' + OutName) <> Expected then
    Fail(Dir, 'Üretilen dosyanın SHA256 değeri beklenenle uyuşmuyor (' + OutName + '); hiçbir şey değiştirilmedi.');
  WriteLog(Dir, 'Delta uygulandı ve doğrulandı: ' + DeltaName + ' -> ' + Expected);
end;

{ DLC paketi önce GEÇİCİ klasörde f3patch ile üretilir (kullanıcının kendi DLC kitapları yalnızca OKUNUR); oyun klasörüne henüz yazılmaz. }
procedure BuildDlc(const Dir: String);
var
  Tmp: String;
  RC: Integer;
begin
  Tmp := ExpandConstant('{tmp}');
  SetArrayLength(DlcRep, 0);
  DeleteFile(Tmp + '\dlc_out\rapor.txt');
  if not Exec(Tmp + '\f3patch\f3patch.exe', 'dlc --game "' + Dir + '" --pack book_pack.lzma --out dlc_out --version {#Version}', Tmp, SW_HIDE, ewWaitUntilTerminated, RC) then
    Fail(Dir, 'Yardımcı program (f3patch) DLC adımında çalıştırılamadı.');
  if RC <> 0 then
    Fail(Dir, 'DLC paketi üretilemedi (yardımcı çıkış kodu ' + IntToStr(RC) + '); hiçbir şey değiştirilmedi.');
  if not LoadStringsFromFile(Tmp + '\dlc_out\rapor.txt', DlcRep) then
    SetArrayLength(DlcRep, 0);
end;

{ Raporda OK olan dosyalar DLC\99_tr_yama altına kopyalanır ve SHA256 ile doğrulanır. DLC yoksa (OK yok) var olan eski paketimiz güvenle kaldırılır. }
procedure InstallDlc(const Dir: String);
var
  I, P1, P2, Cnt: Integer;
  L, Rel, H, Src, Dst, Pkg: String;
begin
  Pkg := DlcPkgDir(Dir);
  for I := 0 to GetArrayLength(DlcRep) - 1 do
    if Pos('OK|', DlcRep[I]) <> 1 then
      WriteLog(Dir, 'DLC: ' + DlcRep[I]);
  Cnt := 0;
  for I := 0 to GetArrayLength(DlcRep) - 1 do
    if Pos('OK|', DlcRep[I]) = 1 then Cnt := Cnt + 1;
  if Cnt = 0 then
  begin
    WriteLog(Dir, 'DLC: eklenecek paket yok (desteklenen DLC kurulu değil).');
    RetireDlc(Dir);
    Exit;
  end;
  { v1.1.0 paketi ya da yer tutucu varsa bilinen dosyaları silinip yenisi yazılır (aynı kimlikler 120/121) }
  RemoveDlcSafe(Dir);
  ForceDirectories(Pkg + '\Content');
  for I := 0 to GetArrayLength(DlcRep) - 1 do
  begin
    L := Trim(DlcRep[I]);
    if Pos('OK|', L) <> 1 then Continue;
    Delete(L, 1, 3);
    P1 := Pos('|', L);
    Rel := Copy(L, 1, P1 - 1);
    H := Lowercase(Copy(L, P1 + 1, 64));
    if not IsDlcKnown(Rel) then
      Fail(Dir, 'DLC raporunda beklenmeyen dosya adı: ' + Rel);
    Src := ExpandConstant('{tmp}\dlc_out\99_tr_yama\') + Rel;
    Dst := Pkg + '\' + Rel;
    if (not FileCopy(Src, Dst, False)) or (Hash(Dst) <> H) then
    begin
      RetireDlc(Dir);
      Fail(Dir, 'DLC paketi dosyası kopyalanamadı ya da doğrulanamadı: ' + Rel + '. DLC klasörümüz temizlendi (ana yama kuruldu).');
    end;
  end;
  P2 := Cnt;
  WriteLog(Dir, 'DLC\99_tr_yama kuruldu ve doğrulandı (' + IntToStr(P2) + ' dosya).');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Dir, SrcBook, SrcFont, HSrc, FSrc, BakDir: String;
  BName: String;
begin
  if CurStep = ssDone then
  begin
    if InstallOK and (not WizardSilent) and LaunchCheck.Checked then
      LaunchGame(GameDirValue);
    Exit;
  end;
  if CurStep <> ssInstall then
    Exit;
  Dir := GameDirValue;
  BakDir := Dir + '\_TR_yedek';
  ForceDirectories(BakDir);

  { yamalı dosyalar önce GEÇİCİ klasörde delta ile üretilir ve hash ile doğrulanır; oyun klasörüne henüz dokunulmaz }
  ExtractTemporaryFiles('*');
  ApplyBook(Dir, OrigSrcBook, EXP_BOOK);
  ApplyDelta(Dir, OrigSrcFont, 'font.xdelta', EXP_FONT, 'font_out.bin');
  BuildDlc(Dir);
  { yardımcı program işi bitince geçici klasörden silinir (yalnızca kurulum geçici klasörümüz) }
  if (Pos(Lowercase(ExpandConstant('{tmp}')) + '\', Lowercase(ExpandConstant('{tmp}\f3patch')) + '\') = 1) and DirExists(ExpandConstant('{tmp}\f3patch')) then
    DelTree(ExpandConstant('{tmp}\f3patch'), True, True, True);
  SrcBook := ExpandConstant('{tmp}\book_out.bin');
  SrcFont := ExpandConstant('{tmp}\font_out.bin');

  { geri alma için mevcut dosyalar }
  FileCopy(BookPath(Dir), ExpandConstant('{tmp}\prev_book'), False);
  FileCopy(FontPath(Dir), ExpandConstant('{tmp}\prev_font'), False);

  { yedek }
  if BakSrcBook <> '' then
  begin
    if QuarBook then Quarantine(Dir, 'book.babel');
    if (not FileCopy(BakSrcBook, BakDir + '\book.babel', False)) or (Hash(BakDir + '\book.babel') <> ORIG_BOOK) then
      Fail(Dir, 'book.babel yedeği alınamadı ya da doğrulanamadı.');
    WriteLog(Dir, 'book.babel orijinal yedeklendi.');
  end;
  if BakSrcFont <> '' then
  begin
    if QuarFont then Quarantine(Dir, 'gui_normal.bft');
    if (not FileCopy(BakSrcFont, BakDir + '\gui_normal.bft', False)) or (Hash(BakDir + '\gui_normal.bft') <> ORIG_FONT) then
      Fail(Dir, 'gui_normal.bft yedeği alınamadı ya da doğrulanamadı.');
    WriteLog(Dir, 'gui_normal.bft orijinal yedeklendi.');
  end;
  if SaveUnkBook or SaveUnkFont then
  begin
    ForceDirectories(BakDir + '\supheli');
    if SaveUnkBook then FileCopy(ExpandConstant('{tmp}\prev_book'), BakDir + '\supheli\book.babel.bilinmeyen', False);
    if SaveUnkFont then FileCopy(ExpandConstant('{tmp}\prev_font'), BakDir + '\supheli\gui_normal.bft.bilinmeyen', False);
    WriteLog(Dir, 'Bilinmeyen dosyalar _TR_yedek\supheli altına kopyalandı (orijinal değil).');
  end;

  { kopyala + doğrula }
  HSrc := Hash(SrcBook);
  FSrc := Hash(SrcFont);
  if (not FileCopy(SrcBook, BookPath(Dir), False)) or (Hash(BookPath(Dir)) <> HSrc) then
  begin
    RestorePrev(Dir);
    Fail(Dir, 'book.babel kopyalanamadı ya da SHA256 doğrulaması başarısız. Önceki dosyalar geri yüklendi.');
  end;
  WriteLog(Dir, 'book.babel kuruldu, SHA256 doğrulandı: ' + HSrc);
  if (not FileCopy(SrcFont, FontPath(Dir), False)) or (Hash(FontPath(Dir)) <> FSrc) then
  begin
    RestorePrev(Dir);
    Fail(Dir, 'gui_normal.bft kopyalanamadı ya da SHA256 doğrulaması başarısız. Önceki dosyalar geri yüklendi.');
  end;
  WriteLog(Dir, 'gui_normal.bft kuruldu, SHA256 doğrulandı: ' + FSrc);
  InstallDlc(Dir);
  WriteLog(Dir, 'Kurulum doğrulandı.');
  InstallOK := True;
end;

{ ------------------------------------------------------------- kaldırma }
function InitializeUninstall: Boolean;
begin
  Result := True;
  if LooksLikeGameRoot(RemoveBackslash(ExpandConstant('{app}'))) then
  begin
    SuppressibleMsgBox('Güvenlik: bu kaldırıcı bir oyun klasöründe çalışıyor (eski hatalı kurulum). Hiçbir şey silinmeyecek. Yeni kurulum programını çalıştırın; eski kaydı güvenle temizler.', mbError, MB_OK, IDOK);
    Result := False;
    Exit;
  end;
  if GameRunning then
  begin
    SuppressibleMsgBox('Fable III (Fable3.exe / FableLauncher.exe) açık görünüyor. Lütfen oyunu ve başlatıcıyı kapatın, sonra kaldırmayı tekrar çalıştırın.', mbError, MB_OK, IDOK);
    Result := False;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Game: String;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  Game := '';
  if not RegQueryStringValue(HKA, 'SOFTWARE\Fable3TurkceYama', 'OyunKlasoru', Game) then
    Game := '';
  Game := RemoveBackslash(Game);
  if Game = '' then
  begin
    WriteLog('', 'KALDIRMA: kayıt defterinde oyun klasörü yok; oyun dosyalarına dokunulmadı.');
    SuppressibleMsgBox('Kayıt defterinde oyun klasörü bilgisi bulunamadı; oyun dosyalarına dokunulmadı. Orijinale dönmek için Steam''de "Oyun dosyalarının bütünlüğünü doğrula" seçeneğini kullanın.', mbError, MB_OK, IDOK);
    Exit;
  end;
  if DoRestore(Game) then
    InfoBox(Game, 'Türkçe yama kaldırıldı; orijinal dosyalar geri yüklendi ve doğrulandı.', mbInformation);
end;
