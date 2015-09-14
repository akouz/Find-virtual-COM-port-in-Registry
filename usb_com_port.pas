unit usb_com_port;
{
* Find a virtual COM port of a USB device with specified VID+PID
* Author    A.Kouznetsov
* Rev       1.00 dated 14/9/2015
Redistribution and use in source and binary forms, with or without modification, are permitted.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.}

{$mode objfpc}{$H+}

// ######################################################################
interface
// ######################################################################

uses
  Classes, SysUtils, Registry ;

type

  { TUsbComPort }

  TUsbComPort = class(TStringList)
  private
    FPID : integer;
    FVID : integer;
    FExtra : string;
    Fcom : TStringList;                 // list of COM ports
    function FFindVidPidPort : integer;
    function FListComPorts : integer;
  public
    function FindUsbComPort(VID:integer; PID:integer; Extra:string) : string;   // Extra is optional, it can be revision, for example
    constructor Create;
    destructor Destroy; override;
end;


// ######################################################################
implementation
// ######################################################################

// =====================================================
// Extract first decimal number from a string
// =====================================================
function extract_first_number(ss : string) : string;
var i : integer;
    c : char;
begin
  result := '';
  for i:=1 to length(ss)+1 do begin
    c := ss[i];
    if c in ['0'..'9'] then
      result := result + c
    else if result <> '' then  // number extracted
      break;
  end;
end;

{ TUsbComPort }

// =====================================================
// Find specified VID+PID+Extra in registry and extract associated COM port
// =====================================================
function TUsbComPort.FFindVidPidPort: integer;
var
  pvstr : string;
  reg: TRegistry;
  ts, vs: TStringList;
  s, ss, sr: string;
  i, j: integer;
begin
  result := 0;
  if (FPID>0) and (FVID>0) then begin
    ts := TStringList.Create;
    vs := TStringList.Create;
    // ---------------------------
    // make search string
    // ---------------------------
    pvstr := 'Vid_' + IntToHex(FVID,4) + '&Pid_' + IntToHex(FPID,4);
    if (FExtra <> '') then
        pvstr := pvstr + '&' + FExtra;
    reg := TRegistry.Create(KEY_READ);
    reg.RootKey := HKEY_LOCAL_MACHINE;
    ss := 'system\CurrentControlSet\Enum\USB\' + pvstr;
    // ---------------------------
    // get all subkeys for this VID+PID
    // ---------------------------
    reg.OpenKey(ss, False);
    reg.GetKeyNames(ts);
    reg.CloseKey;
    // ---------------------------
    // for every subkey get associated COM port
    // ---------------------------
    for i := 0 to ts.Count - 1 do  begin
      s := ss + '\' + ts.Strings[i] +'\Device Parameters';
      reg.OpenKey(s, False);
      reg.GetValueNames(vs); // read all values
      for j := 0 to vs.Count - 1 do  begin
        sr := vs.Strings[j];
        if AnsiUpperCase(sr) = 'PORTNAME' then begin
          sr := reg.ReadString(sr);
          Self.Add(extract_first_number(sr));
          inc(result);
        end;
      end;
      reg.CloseKey;
    end;
    // ---------------------------
    // Finish
    // ---------------------------
    reg.Free;
    ts.Free;
    vs.Free;
  end;
end;

// =====================================================
// Find all existing at the moment COM ports
// =====================================================
function TUsbComPort.FListComPorts: integer;
var
  i: integer;
  reg: TRegistry;
  ts: TStringList;
  s, ss, pno: string;
begin
  result := 0;
  reg := TRegistry.Create(KEY_READ);
  reg.RootKey := HKEY_LOCAL_MACHINE;
  reg.OpenKey('hardware\devicemap\serialcomm', False);
  ts := TStringList.Create;
  // ------------------------------
  // read all COM ports from registry
  // ------------------------------
  reg.GetValueNames(ts);
  // ------------------------------
  // out of all serial ports, select USB virtual COM ports
  // ------------------------------
  s := '\DEVICE\USBSER';
  for i := 0 to ts.Count - 1 do  begin
    ss := AnsiUpperCase(ts.Strings[i]);
    ss := copy(ss, 1, length(s)); // cut off index
    if (ss = s) then begin
      pno := extract_first_number(reg.ReadString(ts.Strings[i]));
      FCom.Add(pno);
      inc(result);
    end;
  end;
  ts.Free;
  reg.Free;
end;

// =====================================================
// Find virtual COM port and return its number
// =====================================================
// "Extra" is optional
function TUsbComPort.FindUsbComPort(VID: integer; PID: integer; Extra: string) : string;
var i, j : integer;
begin
  result := '';
  FPID := PID;
  FVID := VID;
  FExtra := Extra;
  FCom.Clear;
  Self.Clear;
  if (FListComPorts>0) and (FFindVidPidPort>0) then begin
     for i:= 0 to Self.Count-1 do begin    // for all virtual COM ports with that VID+PID
         for j:=0 to FCom.Count-1 do begin  // for all existing COM ports
           if (Self.Strings[i] = FCom.Strings[j]) then begin
              result := 'COM'+Self.Strings[i];  // have found that port
              exit;
           end;
         end;
     end;
  end;
end;

// =====================================================
// Create
// =====================================================
constructor TUsbComPort.Create;
begin
  FCom := TStringList.Create;
end;

// =====================================================
// Destroy
// =====================================================
destructor TUsbComPort.Destroy;
begin
  FCom.Free;
  inherited Destroy;
end;

end.
