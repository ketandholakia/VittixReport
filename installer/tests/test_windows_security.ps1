param([string]$EvidenceDir)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Run this file in a child PowerShell process. A native API defect cannot take
# down the caller or the surrounding test runner.
if (-not $EvidenceDir) {
  $EvidenceDir = Join-Path $PSScriptRoot ('..\..\build\release-audit\windows-security-' + [guid]::NewGuid().ToString('N'))
}
$EvidenceDir = [IO.Path]::GetFullPath($EvidenceDir)
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$fixture = Join-Path $EvidenceDir 'ntfs-fixtures'
New-Item -ItemType Directory -Path $fixture | Out-Null
$results = [Collections.Generic.List[object]]::new()

$native = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public static class InstallerSecurityNativeProbe {
  const uint TOKEN_DUPLICATE=2, TOKEN_QUERY=8, TOKEN_ADJUST_DEFAULT=0x80;
  const uint DISABLE_MAX_PRIVILEGE=1, FILE_WRITE_DATA=2, FILE_APPEND_DATA=4,
    FILE_WRITE_EA=0x10, FILE_DELETE_CHILD=0x40, FILE_WRITE_ATTRIBUTES=0x100,
    DELETE=0x10000, WRITE_DAC=0x40000, WRITE_OWNER=0x80000;
  const uint ERROR_INSUFFICIENT_BUFFER=122, SE_FILE_OBJECT=1, DACL_SECURITY_INFORMATION=4;
  const uint SE_GROUP_USE_FOR_DENY_ONLY=0x10;

  [StructLayout(LayoutKind.Sequential)] public struct SID_AND_ATTRIBUTES { public IntPtr Sid; public uint Attributes; }
  [StructLayout(LayoutKind.Sequential)] struct TOKEN_GROUPS_ONE { public uint Count; public SID_AND_ATTRIBUTES First; }
  [StructLayout(LayoutKind.Sequential)] struct GENERIC_MAPPING { public uint Read,Write,Execute,All; }
  [StructLayout(LayoutKind.Sequential)] struct TOKEN_OWNER { public IntPtr Owner; }

  [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",SetLastError=true)] static extern IntPtr LocalFree(IntPtr p);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,uint a,out IntPtr t);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool ConvertStringSidToSid(string s,out IntPtr sid);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool IsValidSid(IntPtr sid);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool EqualSid(IntPtr a,IntPtr b);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool CreateRestrictedToken(IntPtr t,uint flags,uint n,ref SID_AND_ATTRIBUTES disable,uint dn,IntPtr del,uint rn,IntPtr restrict,out IntPtr result);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetTokenInformation(IntPtr t,int cls,IntPtr buffer,uint size,out uint needed);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool SetTokenInformation(IntPtr t,int cls,ref TOKEN_OWNER owner,uint size);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool DuplicateTokenEx(IntPtr t,uint access,IntPtr attrs,int level,int type,out IntPtr dup);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern uint GetNamedSecurityInfo(string name,uint type,uint info,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr sd);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool IsValidSecurityDescriptor(IntPtr sd);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorOwner(IntPtr sd,out IntPtr owner,out bool defaulted);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorGroup(IntPtr sd,out IntPtr group,out bool defaulted);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorControl(IntPtr sd,out ushort control,out uint revision);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetSecurityDescriptorDacl(IntPtr sd,out bool present,out IntPtr dacl,out bool defaulted);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetAclInformation(IntPtr acl,out ACL_SIZE info,uint size,int cls);
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool GetAce(IntPtr acl,uint index,out IntPtr ace);
  [StructLayout(LayoutKind.Sequential)] struct ACL_SIZE { public uint AceCount, AclBytesInUse, AclBytesFree; }
  [DllImport("advapi32.dll",SetLastError=true)] static extern bool AccessCheck(IntPtr sd,IntPtr token,uint desired,ref GENERIC_MAPPING mapping,IntPtr privileges,ref uint privilegeBytes,out uint granted,out bool access);

  static void Need(bool b,string what) { if(!b) { int e=Marshal.GetLastWin32Error(); throw new Win32Exception(e,what+" (Win32 "+e+")"); } }
  static IntPtr Sid(string s) { IntPtr p; Need(ConvertStringSidToSid(s,out p),"ConvertStringSidToSid"); return p; }
  static IntPtr Query(IntPtr token,int cls,out int required) {
    uint n; bool ok=GetTokenInformation(token,cls,IntPtr.Zero,0,out n); int error=Marshal.GetLastWin32Error();
    if(ok || error!=(int)ERROR_INSUFFICIENT_BUFFER || n<4 || n>65536) throw new Exception("sizing contract class="+cls+" ok="+ok+" error="+error+" size="+n);
    required=(int)n; IntPtr p=Marshal.AllocHGlobal(required);
    try { Need(GetTokenInformation(token,cls,p,n,out n),"GetTokenInformation class "+cls); if(n>required || n<4) throw new Exception("invalid returned length"); return p; }
    catch { Marshal.FreeHGlobal(p); throw; }
  }
  public static string Run(string protectedPath,string protectedBpl,string writablePath,string inheritedPath,string writableFile,string writableParent,string deleteChild,string writeDac,string writeOwner,string deleteFile,string reparsePath) {
    IntPtr admin=IntPtr.Zero,users=IntPtr.Zero,currentUser=IntPtr.Zero,process=IntPtr.Zero,restricted=IntPtr.Zero,impersonation=IntPtr.Zero,userBuf=IntPtr.Zero,groupsBuf=IntPtr.Zero,sd=IntPtr.Zero;
    string report="";
    try {
      admin=Sid("S-1-5-32-544"); users=Sid("S-1-5-32-545"); currentUser=Sid(SidStringForCurrentUser());
      Need(OpenProcessToken(GetCurrentProcess(),TOKEN_DUPLICATE|TOKEN_QUERY|TOKEN_ADJUST_DEFAULT,out process),"OpenProcessToken");
      int userLength; userBuf=Query(process,1,out userLength);
      SID_AND_ATTRIBUTES tu=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(userBuf,typeof(SID_AND_ATTRIBUTES));
      Need(tu.Sid!=IntPtr.Zero && IsValidSid(tu.Sid),"TOKEN_USER SID validity");
      if(!EqualSid(tu.Sid,currentUser)) throw new Exception("TOKEN_USER SID differs from current identity");
      report+="PASS TokenUser two-call size="+userLength+" and valid identity SID; ";
      SID_AND_ATTRIBUTES disable=new SID_AND_ATTRIBUTES{Sid=admin,Attributes=0};
      Need(CreateRestrictedToken(process,DISABLE_MAX_PRIVILEGE,1,ref disable,0,IntPtr.Zero,0,IntPtr.Zero,out restricted),"CreateRestrictedToken");
      int groupsLength; groupsBuf=Query(restricted,2,out groupsLength);
      int offset=Marshal.OffsetOf(typeof(TOKEN_GROUPS_ONE),"First").ToInt32(), stride=Marshal.SizeOf(typeof(SID_AND_ATTRIBUTES));
      uint count=(uint)Marshal.ReadInt32(groupsBuf); if(count>1024 || offset+(long)count*stride>groupsLength) throw new Exception("TOKEN_GROUPS bounds invalid count="+count+" length="+groupsLength+" offset="+offset+" stride="+stride);
      bool usersRetained=false,adminDenyOnly=false;
      for(int i=0;i<count;i++) { SID_AND_ATTRIBUTES g=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(IntPtr.Add(groupsBuf,offset+i*stride),typeof(SID_AND_ATTRIBUTES)); if(g.Sid==IntPtr.Zero||!IsValidSid(g.Sid)) throw new Exception("invalid group SID index="+i); if(EqualSid(g.Sid,users)) usersRetained=true; if(EqualSid(g.Sid,admin)) adminDenyOnly=(g.Attributes&SE_GROUP_USE_FOR_DENY_ONLY)!=0; }
      if(!usersRetained||!adminDenyOnly) throw new Exception("group policy users="+usersRetained+" adminDenyOnly="+adminDenyOnly);
      report+="PASS TokenGroups count="+count+" x64offset="+offset+" Users retained/Admin deny-only; ";
      TOKEN_OWNER owner=new TOKEN_OWNER{Owner=tu.Sid}; Need(SetTokenInformation(restricted,4,ref owner,(uint)Marshal.SizeOf(typeof(TOKEN_OWNER))),"SetTokenInformation(TokenOwner)");
      int ownerLength; IntPtr ownerBuf=Query(restricted,4,out ownerLength); try { SID_AND_ATTRIBUTES actualOwner=(SID_AND_ATTRIBUTES)Marshal.PtrToStructure(ownerBuf,typeof(SID_AND_ATTRIBUTES)); if(actualOwner.Sid==IntPtr.Zero||!IsValidSid(actualOwner.Sid)||!EqualSid(actualOwner.Sid,tu.Sid)) throw new Exception("TokenOwner readback mismatch"); } finally { Marshal.FreeHGlobal(ownerBuf); }
      Need(DuplicateTokenEx(restricted,TOKEN_QUERY|TOKEN_DUPLICATE,IntPtr.Zero,2,2,out impersonation),"DuplicateTokenEx impersonation");
      report+="PASS TokenOwner set while SID buffer alive; impersonation token created; ";
      string[] paths={protectedPath,protectedBpl,writablePath,inheritedPath,writableFile,writableParent,deleteChild,writeDac,writeOwner,deleteFile};
      uint[] rights={DELETE,FILE_DELETE_CHILD,WRITE_DAC,WRITE_OWNER,FILE_WRITE_DATA,FILE_APPEND_DATA,FILE_WRITE_EA,FILE_WRITE_ATTRIBUTES};
      foreach(string path in paths) {
        if(path==protectedPath) {
          IntPtr oo,gg,dd,ss,daclOnly; uint drc=GetNamedSecurityInfo(path,SE_FILE_OBJECT,DACL_SECURITY_INFORMATION,out oo,out gg,out dd,out ss,out daclOnly);
          if(drc!=0) throw new Win32Exception((int)drc,"GetNamedSecurityInfo DACL-only");
          try { bool dvalid=IsValidSecurityDescriptor(daclOnly), od,gd; IntPtr doOwner,doGroup; Need(GetSecurityDescriptorOwner(daclOnly,out doOwner,out od),"DACL-only owner query"); Need(GetSecurityDescriptorGroup(daclOnly,out doGroup,out gd),"DACL-only group query"); GENERIC_MAPPING dm=new GENERIC_MAPPING{Read=0x00120089,Write=0x00120116,Execute=0x001200A0,All=0x001F01FF}; IntPtr dp=Marshal.AllocHGlobal(1024); try { uint dl=1024,dg; bool da; bool dcall=AccessCheck(daclOnly,impersonation,DELETE,ref dm,dp,ref dl,out dg,out da); int de=Marshal.GetLastWin32Error(); if(!dvalid||doOwner!=IntPtr.Zero||doGroup!=IntPtr.Zero||dcall||de!=1338) throw new Exception("DACL-only descriptor regression unexpected valid="+dvalid+" owner="+doOwner+" group="+doGroup+" call="+dcall+" error="+de); report+="PASS reproduced DACL-only AccessCheck ERROR_INVALID_SECURITY_DESCR; owner/group omitted; "; } finally { Marshal.FreeHGlobal(dp); } }
          finally { LocalFree(daclOnly); }
        }
        IntPtr o,g,d,s; uint rc=GetNamedSecurityInfo(path,SE_FILE_OBJECT,DACL_SECURITY_INFORMATION|1|2,out o,out g,out d,out s,out sd);
        if(rc!=0) throw new Win32Exception((int)rc,"GetNamedSecurityInfo "+path);
        bool validSd=IsValidSecurityDescriptor(sd), validOwner=o!=IntPtr.Zero&&IsValidSid(o), validGroup=g!=IntPtr.Zero&&IsValidSid(g); IntPtr sdOwner,sdGroup; bool ownerDefaulted,groupDefaulted; ushort control; uint revision;
        Need(GetSecurityDescriptorOwner(sd,out sdOwner,out ownerDefaulted),"GetSecurityDescriptorOwner"); Need(GetSecurityDescriptorGroup(sd,out sdGroup,out groupDefaulted),"GetSecurityDescriptorGroup"); Need(GetSecurityDescriptorControl(sd,out control,out revision),"GetSecurityDescriptorControl");
        if(!validSd||!validOwner||!validGroup||sdOwner==IntPtr.Zero||sdGroup==IntPtr.Zero||!IsValidSid(sdOwner)||!IsValidSid(sdGroup)) throw new Exception("invalid security descriptor owner/group: "+path+" validSD="+validSd+" owner="+o+" group="+g+" sdOwner="+sdOwner+" sdGroup="+sdGroup);
        report+="SD "+System.IO.Path.GetFileName(path)+" valid owner/group; control=0x"+control.ToString("x")+" revision="+revision+"; ";
        bool present,defaulted; IntPtr checkDacl; Need(GetSecurityDescriptorDacl(sd,out present,out checkDacl,out defaulted)&&present&&checkDacl!=IntPtr.Zero,"GetSecurityDescriptorDacl"); ACL_SIZE aclInfo; Need(GetAclInformation(checkDacl,out aclInfo,(uint)Marshal.SizeOf(typeof(ACL_SIZE)),2),"GetAclInformation"); for(uint ai=0;ai<aclInfo.AceCount;ai++){IntPtr ace;Need(GetAce(checkDacl,ai,out ace),"GetAce");IntPtr aceSid=IntPtr.Add(ace,8);if(!IsValidSid(aceSid))throw new Exception("invalid ACE SID index="+ai+" path="+path);}
        GENERIC_MAPPING map=new GENERIC_MAPPING{Read=0x00120089,Write=0x00120116,Execute=0x001200A0,All=0x001F01FF};
        foreach(uint right in rights) { IntPtr priv=Marshal.AllocHGlobal(1024); try { uint plen=1024,granted; bool access; bool call=AccessCheck(sd,impersonation,right,ref map,priv,ref plen,out granted,out access); string leaf=System.IO.Path.GetFileName(path); if(!call) report+="API=FALSE ACCESS_ERROR "+leaf+"/0x"+right.ToString("x")+" Win32="+Marshal.GetLastWin32Error()+"; "; else { bool? expected=null; if(leaf=="protected"||leaf=="protected.bpl") expected=false; if((leaf=="writable"||leaf=="inherited.txt"||leaf=="writable.bpl")&&(right==FILE_WRITE_DATA||right==DELETE)) expected=true; if(leaf=="writable-parent"&&(right==FILE_WRITE_DATA||right==FILE_APPEND_DATA)) expected=true; if(leaf=="delete-child"&&right==FILE_DELETE_CHILD) expected=true; if(leaf=="write-dac"&&right==WRITE_DAC) expected=true; if(leaf=="write-owner"&&right==WRITE_OWNER) expected=true; if(leaf=="delete-file"&&right==DELETE) expected=true; if(expected.HasValue&&access!=expected.Value) throw new Exception("unexpected access decision "+leaf+" right=0x"+right.ToString("x")+" expected="+expected+" actual="+access); report+="API=TRUE ACCESS "+leaf+"/0x"+right.ToString("x")+"="+access+"/0x"+granted.ToString("x")+"; "; } } finally { Marshal.FreeHGlobal(priv); } }
        LocalFree(sd); sd=IntPtr.Zero;
      }
      IntPtr missingOwner,missingGroup,missingDacl,missingSacl,missingSd; uint missing=GetNamedSecurityInfo(System.IO.Path.Combine(System.IO.Path.GetDirectoryName(protectedPath),"does-not-exist"),SE_FILE_OBJECT,DACL_SECURITY_INFORMATION,out missingOwner,out missingGroup,out missingDacl,out missingSacl,out missingSd);
      if(missing==0) throw new Exception("missing-path security descriptor unexpectedly succeeded"); report+="PASS missing-path security lookup fails closed; ";
      return report;
    } finally { if(sd!=IntPtr.Zero)LocalFree(sd); if(impersonation!=IntPtr.Zero)CloseHandle(impersonation); if(restricted!=IntPtr.Zero)CloseHandle(restricted); if(process!=IntPtr.Zero)CloseHandle(process); if(userBuf!=IntPtr.Zero)Marshal.FreeHGlobal(userBuf); if(groupsBuf!=IntPtr.Zero)Marshal.FreeHGlobal(groupsBuf); if(admin!=IntPtr.Zero)LocalFree(admin); if(users!=IntPtr.Zero)LocalFree(users); if(currentUser!=IntPtr.Zero)LocalFree(currentUser); }
  }
  static string SidStringForCurrentUser() { return System.Security.Principal.WindowsIdentity.GetCurrent().User.Value; }
}
'@

function Record($name, $status, $detail) { $results.Add([ordered]@{name=$name;status=$status;detail=$detail}) }
try {
  Add-Type -TypeDefinition $native
  $protected=Join-Path $fixture 'protected'; $writable=Join-Path $fixture 'writable'; $inherited=Join-Path $fixture 'inherited'; $writableParent=Join-Path $fixture 'writable-parent'; $deleteChild=Join-Path $fixture 'delete-child'; $writeDac=Join-Path $fixture 'write-dac'; $writeOwner=Join-Path $fixture 'write-owner'
  foreach($d in @($protected,$writable,$inherited,$writableParent,$deleteChild,$writeDac,$writeOwner)){New-Item -ItemType Directory -Path $d|Out-Null}
  & icacls.exe $protected /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F' | Out-Null
  & icacls.exe $writable /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null
  & icacls.exe $inherited /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null
  & icacls.exe $writableParent /grant '*S-1-5-32-545:(OI)(CI)M' | Out-Null
  & icacls.exe $deleteChild /grant '*S-1-5-32-545:(DC)' | Out-Null
  & icacls.exe $writeDac /grant '*S-1-5-32-545:(WDAC)' | Out-Null
  & icacls.exe $writeOwner /grant '*S-1-5-32-545:(WO)' | Out-Null
  $bpl=Join-Path $protected 'protected.bpl'; [IO.File]::WriteAllText($bpl,'fixture'); $protectedBpl=Join-Path $fixture 'protected.bpl'; [IO.File]::WriteAllText($protectedBpl,'fixture'); & icacls.exe $protectedBpl /inheritance:r /grant:r '*S-1-5-32-544:F' '*S-1-5-18:F'|Out-Null
  $writableFile=Join-Path $protected 'writable.bpl'; [IO.File]::WriteAllText($writableFile,'fixture'); & icacls.exe $writableFile /grant '*S-1-5-32-545:M'|Out-Null
  $deleteFile=Join-Path $fixture 'delete-file'; [IO.File]::WriteAllText($deleteFile,'fixture'); & icacls.exe $deleteFile /grant '*S-1-5-32-545:D'|Out-Null
  $inheritedFile=Join-Path $inherited 'child.txt'; [IO.File]::WriteAllText($inheritedFile,'fixture')
  $parentFile=Join-Path $writableParent 'child.txt'; [IO.File]::WriteAllText($parentFile,'fixture')
  $junction=Join-Path $fixture 'junction'; New-Item -ItemType Junction -Path $junction -Target $protected | Out-Null
  $symlink=Join-Path $fixture 'symlink'; New-Item -ItemType SymbolicLink -Path $symlink -Target $protected | Out-Null
  $ancestor=Join-Path $junction 'nested'; $attr=[IO.File]::GetAttributes($junction)
  Record 'native token/access harness' 'RUNNING' 'isolated child process; typed TOKEN_GROUPS offset and bounds validation'
  $detail=[InstallerSecurityNativeProbe]::Run($protected,$protectedBpl,$writable,$inheritedFile,$writableFile,$writableParent,$deleteChild,$writeDac,$writeOwner,$deleteFile,$junction)
  Record 'TokenUser/TokenGroups/restricted-token/owner' 'PASS' (($detail -split '; ' | Where-Object {$_ -like 'PASS Token*' -or $_ -like 'PASS TokenOwner*'}) -join '; ')
  $accessDetail=($detail -split '; ' | Where-Object {$_ -like '* ACCESS *' -or $_ -like 'ACCESS_ERROR*' -or $_ -like 'SD *' -or $_ -like 'PASS reproduced DACL-only*'} ) -join '; '
  $accessStatus=if($accessDetail -match 'ACCESS_ERROR'){'ERROR'}else{'PASS'}
  Record 'AccessCheck ACL matrix' $accessStatus $accessDetail
  Record 'missing descriptor fail-closed probe' $(if($detail -match 'PASS missing-path security lookup fails closed'){'PASS'}else{'ERROR'}) 'GetNamedSecurityInfo on missing fixture path must return failure'
  Record 'junction reparse attribute' $(if(([IO.File]::GetAttributes($junction) -band [IO.FileAttributes]::ReparsePoint)){'PASS'}else{'FAIL'}) $junction
  Record 'symbolic-link reparse attribute' $(if(([IO.File]::GetAttributes($symlink) -band [IO.FileAttributes]::ReparsePoint)){'PASS'}else{'FAIL'}) $symlink
  Record 'reparse parent component' $(if(([IO.File]::GetAttributes($junction) -band [IO.FileAttributes]::ReparsePoint)){'PASS'}else{'FAIL'}) $ancestor
} catch { Record 'native Windows security suite' 'ERROR' $_.Exception.ToString() }

$results | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $EvidenceDir 'windows-security-results.json') -Encoding UTF8
Write-Output "EVIDENCE=$EvidenceDir"
$results | ForEach-Object { '{0} {1}: {2}' -f $_.status,$_.name,$_.detail }
if(@($results | Where-Object status -in @('FAIL','ERROR')).Count){exit 1}
