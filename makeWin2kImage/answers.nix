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
