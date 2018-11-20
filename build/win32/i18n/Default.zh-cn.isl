; *** Inno Setup version 5.5.3+ Simplified Chinese messages ***
;
; To download user-contributed translations of this file, go to:
;   http://www.jrsoftware.org/files/istrans/
;
; Note: When translating this text, do not add periods (.) to the end of
; messages that didn't have them already, because on those messages Inno
; Setup adds the periods automatically (appending a period would result in
; two periods being displayed).
[LangOptions]
; The following three entries are very important. Be sure to read and 
; understand the '[LangOptions] section' topic in the help file.
LanguageName=Simplified Chinese
LanguageID=$0804
LanguageCodePage=936
; If the language you are translating to requires special font faces or
; sizes, uncomment any of the following entries and change them accordingly.
;DialogFontName=
;DialogFontSize=8
;WelcomeFontName=Verdana
;WelcomeFontSize=12
;TitleFontName=Arial
;TitleFontSize=29
;CopyrightFontName=Arial
;CopyrightFontSize=8
[Messages]
; *** Application titles
SetupAppTitle=��װ����
SetupWindowTitle=��װ���� - %1
UninstallAppTitle=ж��
UninstallAppFullTitle=%1 ж��
; *** Misc. common
InformationTitle=��Ϣ
ConfirmTitle=ȷ��
ErrorTitle=����
; *** SetupLdr messages
SetupLdrStartupMessage=�⽫��װ %1���Ƿ�Ҫ����?
LdrCannotCreateTemp=�޷�������ʱ�ļ�����װ��������ֹ
LdrCannotExecTemp=�޷�����ʱĿ¼��ִ���ļ�����װ��������ֹ
; *** Startup error messages
LastErrorMessage=%1��%n%n���� %2: %3
SetupFileMissing=��װĿ¼ȱʧ�ļ� %1���������������ȡ��������¸�����
SetupFileCorrupt=��װ�����ļ������𻵡����ȡ�ó�����¸�����
SetupFileCorruptOrWrongVer=��װ�����ļ������𻵻���˰�װ����汾�����ݡ��������������ȡ�ó�����¸�����
InvalidParameter=������ %n%n%1 �ϴ�����һ����Ч����
SetupAlreadyRunning=��װ�����������С�
WindowsVersionNotSupported=�˳���֧�������������е� Windows �汾��
WindowsServicePackRequired=�˳�����Ҫ %1 ����� %2 ����߰汾��
NotOnThisPlatform=�˳��򽫲��� %1 �����С�
OnlyOnThisPlatform=�˳�������� %1 �����С�
OnlyOnTheseArchitectures=�˳�����ɰ�װ��Ϊ���´�������ϵ�ṹ��Ƶ� Windows �汾��:%n%n%1
MissingWOW64APIs=�������е� Windows �汾��������װ����ִ�� 64 λ��װ����Ĺ��ܡ�Ҫ���������⣬�밲װ����� %1��
WinVersionTooLowError=�˳�����Ҫ %1 �汾 %2 ����߰汾��
WinVersionTooHighError=�˳����ܰ�װ�� %1 �汾 %2 ����ߵİ汾�ϡ�
AdminPrivilegesRequired=�ڰ�װ�˳���ʱ������Ϊ����Ա��¼��
PowerUserPrivilegesRequired=��װ�˳���ʱ�����Թ���Ա�� Power User ���Ա��ݵ�¼��
SetupAppRunningError=��װ�����⵽ %1 ��ǰ�������С�%n%n�������ر���������ʵ����Ȼ�󵥻���ȷ�����Լ������򵥻���ȡ�������˳���
UninstallAppRunningError=ж�ؼ�⵽ %1 ��ǰ�������С�%n%n�������ر���������ʵ����Ȼ�󵥻���ȷ�����Լ����򵥻���ȡ�������˳���
; *** Misc. errors
ErrorCreatingDir=��װ�����޷�����Ŀ¼��%1��
ErrorTooManyFilesInDir=�޷���Ŀ¼��%1���д����ļ�����Ϊ������̫���ļ�
; *** Setup common messages
ExitSetupTitle=�˳���װ����
ExitSetupMessage=��װ����δ��ɡ���������˳��������ᰲװ�ó���%n%n��������ʱ���ٴ����а�װ��������ɰ�װ��%n%n�Ƿ��˳���װ����?
AboutSetupMenuItem=���ڰ�װ����(&A)...
AboutSetupTitle=���ڰ�װ����
AboutSetupMessage=%1 �汾 %2%n%3%n%n%1 ��ҳ:%n%4
AboutSetupNote=
TranslatorNote=
; *** Buttons
ButtonBack=< ��һ��(&B)
ButtonNext=��һ��(&N) >
ButtonInstall=��װ(&I)
ButtonOK=ȷ��
ButtonCancel=ȡ��
ButtonYes=��(&Y)
ButtonYesToAll=����ȫ��(&A)
ButtonNo=��(&N)
ButtonNoToAll=��ȫ��(&O)
ButtonFinish=���(&F)
ButtonBrowse=���(&B)...
ButtonWizardBrowse=���(&R)...
ButtonNewFolder=�½��ļ���(&M)
; *** "Select Language" dialog messages
SelectLanguageTitle=ѡ��װ��������
SelectLanguageLabel=ѡ��װʱҪʹ�õ�����:
; *** Common wizard text
ClickNext=��������һ�����Լ������򵥻���ȡ�������˳���װ����
BeveledLabel=
BrowseDialogTitle=��������ļ���
BrowseDialogLabel=�������б���ѡ��һ���ļ��У�Ȼ�󵥻���ȷ������
NewFolderName=�½��ļ���
; *** "Welcome" wizard page
WelcomeLabel1=��ӭʹ�� [name] ��װ��
WelcomeLabel2=�⽫�ڼ�����ϰ�װ [name/ver]��%n%n����ر���������Ӧ�ó����ټ�����
; *** "Password" wizard page
WizardPassword=����
PasswordLabel1=�˰�װ�����뱣����
PasswordLabel3=���ṩ���룬Ȼ�󵥻�����һ�����Լ������������ִ�Сд��
PasswordEditLabel=����(&P):
IncorrectPassword=��������벻��ȷ�������ԡ�
; *** "License Agreement" wizard page
WizardLicense=���Э��
LicenseLabel=���ڼ�������ǰ�Ķ�������Ҫ��Ϣ��
LicenseLabel3=���Ķ��������Э�顣������ܴ�Э������ſɼ�����װ��
LicenseAccepted=�ҽ���Э��(&A)
LicenseNotAccepted=�Ҳ�����Э��(&D)
; *** "Information" wizard pages
WizardInfoBefore=��Ϣ
InfoBeforeLabel=���ڼ�������ǰ�Ķ�������Ҫ��Ϣ��
InfoBeforeClickLabel=׼���ü�����װ�󣬵�������һ������
WizardInfoAfter=��Ϣ
InfoAfterLabel=���ڼ�������ǰ�Ķ�������Ҫ��Ϣ��
InfoAfterClickLabel=׼���ü�����װ�󣬵�������һ������
; *** "User Information" wizard page
WizardUserInfo=�û���Ϣ
UserInfoDesc=�����������Ϣ��
UserInfoName=�û���(&U):
UserInfoOrg=��֯(&O):
UserInfoSerial=���к�(&S):
UserInfoNameRequired=�����������ơ�
; *** "Select Destination Location" wizard page
WizardSelectDir=ѡ��Ŀ��λ��
SelectDirDesc=Ӧ�� [name] ��װ������?
SelectDirLabel3=��װ����Ὣ [name] ��װ�������ļ��С�
SelectDirBrowseLabel=��Ҫ��������������һ�����������ѡ�������ļ��У��������������
DiskSpaceMBLabel=��Ҫ���� [mb] MB ���ô��̿ռ䡣
CannotInstallToNetworkDrive=��װ�����޷���װ��������������
CannotInstallToUNCPath=��װ�����޷���װ�� UNC ·����
InvalidPath=����������������ŵ�����·��(����:%n%nC:\APP%n%n)�����¸�ʽ�� UNC ·��:%n%n\\server\share
InvalidDrive=��ѡ�������� UNC �������ڻ򲻿ɷ��ʡ�������ѡ��
DiskSpaceWarningTitle=���̿ռ䲻��
DiskSpaceWarning=��װ������Ҫ���� %1 KB ���ÿռ�����װ������ѡ���������� %2 KB ���ÿռ䡣%n%n�Ƿ���Ҫ����?
DirNameTooLong=�ļ������ƻ�·��̫����
InvalidDirName=�ļ���������Ч��
BadDirName32=�ļ��������ܰ���������һ�ַ�:%n%n%1
DirExistsTitle=�ļ��д���
DirExists=�ļ���:%n%n%1%n%n�Ѵ��ڡ��Ƿ���Ҫ��װ�����ļ���?
DirDoesntExistTitle=�ļ��в�����
DirDoesntExist=�ļ���:%n%n%1%n%n�����ڡ��Ƿ�Ҫ�������ļ���?
; *** "Select Components" wizard page
WizardSelectComponents=ѡ�����
SelectComponentsDesc=Ӧ��װ��Щ���?
SelectComponentsLabel2=ѡ��ϣ����װ������������ϣ����װ�������׼�������󵥻�����һ�����Լ�����
FullInstallation=��ȫ��װ
; if possible don't translate 'Compact' as 'Minimal' (I mean 'Minimal' in your language)
CompactInstallation=��లװ
CustomInstallation=�Զ��尲װ
NoUninstallWarningTitle=�������
NoUninstallWarning=��װ�����⵽��������Ѱ�װ�������:%n%n%1%n%nȡ��ѡ����Щ���������ж�����ǡ�%n%n�Ƿ���Ҫ����?
ComponentSize1=%1 KB
ComponentSize2=%1 MB
ComponentsDiskSpaceMBLabel=��ǰѡ����Ҫ���� [mb] MB ���̿ռ䡣
; *** "Select Additional Tasks" wizard page
WizardSelectTasks=ѡ����������
SelectTasksDesc=Ӧִ����Щ��������?
SelectTasksLabel2=ѡ��װ [name] ʱϣ����װ������ִ�е���������Ȼ�󵥻�����һ������
; *** "Select Start Menu Folder" wizard page
WizardSelectProgramGroup=ѡ��ʼ�˵��ļ���
SelectStartMenuFolderDesc=��װ����Ӧ������Ŀ�ݷ�ʽ���õ�����?
SelectStartMenuFolderLabel3=��װ���������¿�ʼ�˵��ļ����д����ó���Ŀ�ݷ�ʽ��
SelectStartMenuFolderBrowseLabel=��Ҫ��������������һ�����������ѡ�������ļ��У��������������
MustEnterGroupName=���������ļ�������
GroupNameTooLong=�ļ������ƻ�·��̫����
InvalidGroupName=�ļ���������Ч��
BadGroupName=�ļ��������ܱ���������һ�ַ�:%n%n%1
NoProgramGroupCheck2=��������ʼ�˵��ļ���(&D)
; *** "Ready to Install" wizard page
WizardReady=��װ׼������
ReadyLabel1=��װ��������׼�����ڼ�����ϰ�װ [name]��
ReadyLabel2a=��������װ���Լ�����װ������鿴������κ������򵥻�"����"��
ReadyLabel2b=��������װ���Լ�����װ��
ReadyMemoUserInfo=�û���Ϣ:
ReadyMemoDir=Ŀ��λ��:
ReadyMemoType=��װ��������:
ReadyMemoComponents=��ѡ���:
ReadyMemoGroup=��ʼ�˵��ļ���:
ReadyMemoTasks=��������:
; *** "Preparing to Install" wizard page
WizardPreparing=����׼����װ
PreparingDesc=��װ������׼���ڼ�����ϰ�װ [name]��
PreviousInstallNotCompleted=��һ������İ�װ/ɾ��δ��ɡ����������������ɸð�װ��%n%n������������������а�װ��������� [name] �İ�װ��
CannotContinue=��װ�����޷��������뵥��"ȡ��"���˳���
ApplicationsFound=����Ӧ�ó�������ʹ����Ҫͨ����װ������и��µ��ļ�����������װ�����Զ��ر���ЩӦ�ó���
ApplicationsFound2=����Ӧ�ó�������ʹ����Ҫͨ����װ������и��µ��ļ�����������װ�����Զ��ر���ЩӦ�ó�����ɰ�װ�󣬰�װ���򽫳�������Ӧ�ó���
CloseApplications=�Զ��ر�Ӧ�ó���(&A)
DontCloseApplications=���ر�Ӧ�ó���(&D)
ErrorCloseApplications=��װ�����޷��Զ��ر�����Ӧ�ó��򡣽����ڼ�������֮ǰ�ȹر�����ʹ����ͨ����װ������и��µ��ļ���Ӧ�ó���
; *** "Installing" wizard page
WizardInstalling=���ڰ�װ
InstallingLabel=��װ�������ڼ�����ϰ�װ [name]�����Եȡ�
; *** "Setup Completed" wizard page
FinishedHeadingLabel=��� [name] ��װ��
FinishedLabelNoIcons=��װ�������ڼ��������ɰ�װ [name]��
FinishedLabel=��װ�������ڼ��������ɰ�װ [name]��ͨ��ѡ��װ�Ŀ�ݷ�ʽ����������Ӧ�ó���
ClickFinish=��������ɡ����˳���װ����
FinishedRestartLabel=Ҫ��� [name] �İ�װ����װ�������������������Ƿ�Ҫ��������?
FinishedRestartMessage=Ҫ��� [name] �İ�װ����װ������������������%n%n�Ƿ�Ҫ��������?
ShowReadmeCheck=�ǣ���ϣ���鿴 README �ļ�
YesRadio=�ǣ��������������(&Y)
NoRadio=���ҽ��Ժ����������(&N)
; used for example as 'Run MyProg.exe'
RunEntryExec=���� %1
; used for example as 'View Readme.txt'
RunEntryShellExec=�鿴 %1
; *** "Setup Needs the Next Disk" stuff
ChangeDiskTitle=��װ������Ҫ��һ������
SelectDiskLabel2=�������� %1 �������ȷ������%n%n����˴����ϵ��ļ����������ļ�����������ļ������ҵ�����������ȷ·���򵥻����������
PathLabel=·��(&P):
FileNotInDir2=�ڡ�%2�����޷���λ�ļ���%1�����������ȷ�Ĵ��̻�ѡ�������ļ��С�
SelectDirectoryLabel=��ָ����һ�����̵�λ�á�
; *** Installation phase messages
SetupAborted=��װ����δ��ɡ�%n%n��������Ⲣ�������а�װ����
EntryAbortRetryIgnore=���������ԡ����ٴγ��ԣ����������ԡ��Լ������򵥻�����ֹ����ȡ����װ��
; *** Installation status messages
StatusClosingApplications=���ڹر�Ӧ�ó���...
StatusCreateDirs=���ڴ���Ŀ¼...
StatusExtractFiles=���ڽ�ѹ���ļ�...
StatusCreateIcons=���ڴ�����ݷ�ʽ...
StatusCreateIniEntries=���ڴ��� INI ��...
StatusCreateRegistryEntries=���ڴ���ע�����...
StatusRegisterFiles=����ע���ļ�...
StatusSavingUninstall=���ڱ���ж����Ϣ...
StatusRunProgram=������ɰ�װ...
StatusRestartingApplications=��������Ӧ�ó���...
StatusRollback=���ڻ��˸���...
; *** Misc. errors
ErrorInternal2=�ڲ�����: %1
ErrorFunctionFailedNoCode=%1 ʧ��
ErrorFunctionFailed=%1 ʧ�ܣ����� %2
ErrorFunctionFailedWithMessage=%1 ʧ�ܣ����� %2��%n%3
ErrorExecutingProgram=�޷�ִ���ļ�:%n%1
; *** Registry errors
ErrorRegOpenKey=��ע�����ʱ����:%n%1\%2
ErrorRegCreateKey=����ע�����ʱ����:%n%1\%2
ErrorRegWriteKey=д��ע�����ʱ����:%n%1\%2
; *** INI errors
ErrorIniEntry=���ļ���%1���д��� INI ��ʱ����
; *** File copying errors
FileAbortRetryIgnore=���������ԡ����ٴβ��������������ԡ����������ļ�(������˲���)���򵥻�����ֹ����ȡ����װ��
FileAbortRetryIgnore2=���������ԡ����ٴβ��������������ԡ��Լ���(������˲���)���򵥻�����ֹ����ȡ����װ��
SourceIsCorrupted=Դ�ļ�����
SourceDoesntExist=Դ�ļ���%1��������
ExistingFileReadOnly=�����ļ������Ϊֻ��״̬��%n%n���������ԡ���ɾ��ֻ�����Բ����ԣ����������ԡ����������ļ����򵥻�����ֹ����ȡ����װ��
ErrorReadingExistingDest=���Զ�ȡ�����ļ�ʱ����:
FileExists=���ļ��Ѵ��ڡ�%n%n�Ƿ�Ҫ��װ���򸲸���?
ExistingFileNewer=�����ļ��Ȱ�װ���������԰�װ���ļ����¡����鱣�������ļ���%n%n�Ƿ�Ҫ���������ļ�?
ErrorChangingAttr=���Ը��������ļ����Գ���:
ErrorCreatingTemp=������Ŀ��Ŀ¼�����ļ�ʱ����:
ErrorReadingSource=���Զ�ȡԴ�ļ�ʱ����:
ErrorCopying=���Ը����ļ�ʱ����:
ErrorReplacingExistingFile=�����滻�����ļ�ʱ����:
ErrorRestartReplace=RestartReplace ʧ��:
ErrorRenamingTemp=������Ŀ��Ŀ¼�������ļ�ʱ����:
ErrorRegisterServer=�޷�ע�� DLL/OCX: %1
ErrorRegSvr32Failed=RegSvr32 ʧ�ܣ��˳�����Ϊ %1
ErrorRegisterTypeLib=�޷�ע�����Ϳ�: %1
; *** Post-installation errors
ErrorOpeningReadme=���Դ� README �ļ�ʱ����
ErrorRestartingComputer=��װ�����޷���������������ֶ�ִ�д˲�����
; *** Uninstaller messages
UninstallNotFound=�ļ���%1�������ڡ��޷���װ��
UninstallOpenError=�޷����ļ���%1�����޷�ж��
UninstallUnsupportedVer=ж����־��%1���ĸ�ʽ�޷����˰汾��ж�س���ʶ���޷�ж��
UninstallUnknownEntry=ж����־�з���δ֪��Ŀ(%1)
ConfirmUninstall=ȷ��Ҫ����ɾ�� %1 �ͼ���ȫ�����?
UninstallOnlyOnWin64=������ 64 λ Windows ��ж�ش˰�װ��
OnlyAdminCanUninstall=�����й���Ȩ�޵��û��ſ�ж�ش˰�װ��
UninstallStatusLabel=���Ӽ����ɾ�� %1�����Եȡ�
UninstalledAll=�ѳɹ��Ӽ������ɾ�� %1��
UninstalledMost=%1 ж����ɡ�%n%n�޷�ɾ��һЩԪ�ء��ɽ����ֶ�ɾ����
UninstalledAndNeedsRestart=Ҫ��� %1 ��ж�أ����������������%n%n�Ƿ�Ҫ��������?
UninstallDataCorrupted=��%1���ļ����𻵡��޷�ж��
; *** Uninstallation phase messages
ConfirmDeleteSharedFileTitle=ɾ�������ļ�?
ConfirmDeleteSharedFile2=ϵͳ��ʾ���¹����ļ����ٱ��κγ���ʹ�á��Ƿ�Ҫж��ɾ���˹����ļ�?%n%n������г�������ʹ�ô��ļ�������ɾ�����������ܲ����������С������ȷ������ѡ�񡰷񡱡����ļ���סϵͳ�ϲ�������κ����⡣
SharedFileNameLabel=�ļ���:
SharedFileLocationLabel=λ��:
WizardUninstalling=ж��״̬
StatusUninstalling=����ж�� %1...
; *** Shutdown block reasons
ShutdownBlockReasonInstallingApp=���ڰ�װ %1��
ShutdownBlockReasonUninstallingApp=����ж�� %1��
; The custom messages below aren't used by Setup itself, but if you make
; use of them in your scripts, you'll want to translate them.
[CustomMessages]
NameAndVersion=%1 �汾 %2
AdditionalIcons=������ݷ�ʽ:
CreateDesktopIcon=���������ݷ�ʽ(&D)
CreateQuickLaunchIcon=��������������ݷ�ʽ(&Q)
ProgramOnTheWeb=Web �ϵ� %1
UninstallProgram=ж�� %1
LaunchProgram=���� %1
AssocFileExtension=�� %1 �� %2 �ļ���չ������(&A)
AssocingFileExtension=���� %1 �� %2 �ļ���չ������...
AutoStartProgramGroupDescription=����:
AutoStartProgram=�Զ����� %1
AddonHostProgramNotFound=�޷�����ѡ�ļ����ж�λ %1��%n%n�Ƿ���Ҫ����?