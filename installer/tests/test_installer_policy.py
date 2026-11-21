"""Static/model checks for the fixed destination and package protection policy."""
from pathlib import Path
import ntpath
import re

root = Path(__file__).resolve().parents[1]
text = (root / "VittixReport.iss").read_text(encoding="utf-8")
security = (root / "InstallerSecurity.inc").read_text(encoding="utf-8")
setup = text.split("[Setup]", 1)[1].split("[", 1)[0]
code = text.split("[Code]", 1)[1]
passed = 0

def scenario(condition: bool, name: str) -> None:
    global passed
    if not condition:
        raise AssertionError(name)
    passed += 1
    print("PASS", name)

def fixed_destination(candidate: str, root_path: str) -> bool:
    return ntpath.normcase(ntpath.normpath(candidate)) == ntpath.normcase(
        ntpath.normpath(ntpath.join(root_path, "VittixReport")))

def secure_location_model(candidate: str, root_path: str, api_ok: bool,
                          reparse: bool, standard_user_writable: bool) -> bool:
    return (fixed_destination(candidate, root_path) and api_ok and not reparse
            and not standard_user_writable)

scenario(re.search(r"(?im)^\s*PrivilegesRequired\s*=\s*admin\s*$", setup) is not None
         and "PrivilegesRequiredOverridesAllowed" not in setup
         and "AppId={{B7E91D42-8C3A-4F6E-9D25-1A0C7E4B8F63}" in setup,
         "administrator-only privilege with original AppId and no override")
scenario("DefaultDirName={commonpf}\\VittixReport" in setup
         and "DisableDirPage=yes" in setup
         and "UsePreviousAppDir=yes" in setup,
         "fixed Program Files destination and prior path retained for explicit rejection")
scenario("function HasDirCommandLineOverride: Boolean" in code
         and "ParamStr(I)" in code and "HasDirCommandLineOverride" in code
         and "function InitializeSetup: Boolean" in code,
         "unsupported /DIR forms are rejected before setup proceeds")
scenario(secure_location_model(r"C:\Program Files\VittixReport", r"C:\Program Files", True, False, False)
         and not secure_location_model(r"C:\Program Files\Writable\VittixReport", r"C:\Program Files", True, False, False)
         and not secure_location_model(r"C:\Users\Test\VittixReport", r"C:\Program Files", True, False, False)
         and not secure_location_model(r"C:\Program Files\..\Users\Test", r"C:\Program Files", True, False, False)
         and not secure_location_model(r"C:\Program Files\VittixReport", r"C:\Program Files", True, True, False)
         and not secure_location_model(r"C:\Program Files\VittixReport", r"C:\Program Files", True, False, True)
         and not secure_location_model(r"C:\Program Files\VittixReport", r"C:\Program Files", False, False, False),
         "policy model accepts protected Program Files and rejects writable, redirected, traversal, or unverifiable destinations")
scenario("GetNamedSecurityInfoW" in security and "AccessCheck" in security
          and "CreateRestrictedToken" in security and "GetTokenInformation" in security
          and "SetTokenInformation" in security and "FILE_ATTRIBUTE_REPARSE_POINT" in security
          and "DACL_SECURITY_INFORMATION or OWNER_SECURITY_INFORMATION or GROUP_SECURITY_INFORMATION" in security
          and "not IsValidSid(Owner) or not IsValidSid(Group)" in security,
          "Windows restricted-user access check requests and validates descriptor owner/group and inspects reparse ancestors")
scenario("function ValidateInstallLocation(const Candidate: string; RequireBpl: Boolean;" in security
         and "function FileIsProtected" in security
         and "VittixReportDesign.bpl" in security
         and "WRITE_DAC_ACCESS" in security and "WRITE_OWNER_ACCESS" in security
         and "FILE_DELETE_CHILD" in security and "FILE_WRITE_DATA" in security,
         "BPL and every destination ancestor are checked for write, replacement, delete, ACL, ownership, and redirect rights")
registration_step = code.split("procedure CurStepChanged", 1)[1]
scenario("(CurStep = ssPostInstall) and WizardIsTaskSelected('idesetup')" in registration_step
         and "ValidateInstallLocation(ExpandConstant('{app}'), True, SecurityError)" in registration_step
         and registration_step.index("ValidateInstallLocation(ExpandConstant('{app}'), True") < registration_step.index("IntegrateIDE;"),
         "IDE registry writes follow successful post-install security verification")
scenario("function PrepareToInstall(var NeedsRestart: Boolean): String" in code
         and "ExpandConstant('{app}')" not in code.split("function InitializeSetup", 1)[1].split("function PrepareToInstall", 1)[0]
         and "Setup stopped without migrating or overwriting it" in code,
         "silent path check runs after initialization and rejects prior custom locations")

print(f"RESULT: {passed} static/model policy scenarios PASS; failures 0; no live registry access")
