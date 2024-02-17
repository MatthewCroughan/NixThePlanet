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
    EncryptedAdminPassword = "NO";
    OEMSkipRegional = 1;
    TimeZone = 4;
    OemSkipWelcome = 1;
  };
  UserData = {
    ProductKey = "MRX3F-47B9T-2487J-KWKMF-RPWBY";
    FullName = "user";
    OrgName = "NixThePlanet";
    ComputerName = "*";
  };
  Identification.JoinWorkgroup = "WORKGROUP";
  Networking.InstallDefaultComponents = "Yes";
}
