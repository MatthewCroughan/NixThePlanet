# Windows 2000's unattended installation feature is a bit tricky to figure out.
# The SUPPORT/TOOLS/SETUP.EXE in the install disk ISO crashes DOSBox-X, but
# SUPPORT/TOOLS/SREADME.DOC says that it doesn't install the relevant deployment
# tools in DEPLOY.CAB anyway.  If you extract SUPPORT/TOOLS/DEPLOY.CAB with
# cabextract, there is setupmgr.exe inside that has a GUI for creating the
# answer files.  It must be run in the same directory as setupmgx.dll, also
# included in DEPLOY.CAB.  There is also documentation in DEPLOY.CAB in the
# deptool.chm, readme.txt, and unattend.doc files.  The setupmgr.exe tool
# doesn't ask for a product key, so that has to be added to UserData.ProductID
# separately. Otherwise, during the install there will be an error asking the
# user to input it. The unattend.doc file also contains documentation of the
# different answer file options. A web version of unattend.doc is at
# https://web.archive.org/web/20040314065512/https://www.microsoft.com/technet/prodtechnol/Windows2000Pro/deploy/unattend/default.mspx

{
  Data = {
    AutoPartition = 1;
    MsDosInitiated = "0";
    UnattendedInstall = "Yes";
  };
  Unattended = {
    UnattendMode = "FullUnattended";
    OemSkipEula = "Yes";
    OemPreinstall = "No";
    TargetPath = "WINDOWS";
  };
  GuiUnattended = {
    AdminPassword = "*";
    AutoLogon = "Yes";
    OEMSkipRegional = 1;
    TimeZone = 4;
    OemSkipWelcome = 1;
  };
  UserData = {
    FullName = "user";
    OrgName = "NixThePlanet";
    ComputerName = "*";
    ProductID = "RBDC9-VTRC8-D7972-J97JY-PRVMG";
  };
  RegionalSettings.LanguageGroup = 1;
  Identification.JoinWorkgroup = "WORKGROUP";
  Networking.InstallDefaultComponents = "Yes";
}
