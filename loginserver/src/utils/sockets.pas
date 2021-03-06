unit sockets;

(*

Unit que cont�m o gerenciamento dos sockets.

Organizado por:
Felipe de Souza Camargo(Kurama)

Sobre o funcionamento do c�digo:
Serve para organizar cada cliente em uma matriz e usar
os recursos de cada um, individualmente ou n�o.

Refer�ncias:
http://docwiki.embarcadero.com/RADStudio/XE5/en/Installing_Socket_Components

*)

interface

uses Windows, SysUtils, ScktComp, colors, funcoes, crypts, ChecarLogin, database,
EnviarKey, SalvarNick, ChecarNick, Codigo2, TerminarPrimeiroLogin;

type
  TObjeto = class(TObject)
   public
    procedure OnListen(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
end;

TLista = record
  status: boolean;
  socket: TCustomWinSocket;
  key: integer;
  login: AnsiString;
  nick: AnsiString;
  uid: integer;
  codigo1: ansistring;
  codigo2: ansistring;
  data: AnsiString;
end;

var
  Objeto: TObjeto;
  Socket: TServerSocket;
  Lista: array of TLista;

function iniciarsocket(porta: integer): boolean;

implementation

function iniciarsocket(porta: integer): boolean;
begin
  TObjeto.Create;
  Socket:=TServerSocket.Create(nil);
  Socket.OnListen:=Objeto.OnListen;
  Socket.OnClientConnect:=Objeto.OnConnect;
  Socket.OnClientDisconnect:=Objeto.OnDisconnect;
  Socket.OnClientRead:=Objeto.OnRead;
  Socket.OnClientError:=Objeto.OnError;
  Socket.Port:=porta;
  Socket.ServerType:=StNonBlocking;
  try
    Socket.Open;
  except
    on E: Exception do begin
      writeln('[SERVER_S] Error ao iniciar o servidor! ('+e.Message+')');
      result:=false;
      exit;
    end;
  end;
  result:=true;
end;

procedure TObjeto.OnListen(Sender: TObject; Socket: TCustomWinSocket);
begin
  TextColor(10);
  Writeln('[SERVER_S] Servidor ligado.');
  TextColor(7);
end;

procedure TObjeto.OnConnect(Sender: TObject; Socket: TCustomWinSocket);
var
  teste: boolean;
  i: integer;
begin
  teste:=false;
  for i:=0 to length(Lista)-1 do
    if not Lista[i].status then begin
      teste:=true;
      break;
    end;
    if not teste then begin
      setlength(Lista, length(Lista)+1);
      i:=length(Lista)-1;
    end;
    Lista[i].status:=true;
    Lista[i].socket:=socket;
    randomize;
    Lista[i].key:=Random(15)+1;
    TextColor(10);
    Writeln('[SERVER_S] Cliente recebido com sucesso! key: '+inttostr(Lista[i].key-1)+' ('+inttostr(i)+')');
    TextColor(7);
    PxKey(i);
end;

procedure TObjeto.OnDisconnect(Sender: TObject; Socket: TCustomWinSocket);
var
  i: integer;
begin
  for i:=0 to length(Lista)-1 do
    if Lista[i].status then
      if Lista[i].socket=socket then begin
        Lista[i].status:=false;
        if Lista[i].uid > 0 then begin
          MySQL.Connected:=true;
          Query.Close;
          Query.SQL.Clear;
          Query.SQL.Add('update py_members set loginstatus = 0 where uid = '+QuotedStr(inttostr(Lista[i].uid))+'');
          Query.ExecSQL;
          MySQL.Connected:=false;
          TextColor(12);
          Writeln('[SERVER_S] Cliente desconectado! ('+inttostr(i)+')');
          TextColor(7);
        end;
        break;
      end;
end;

procedure TObjeto.OnRead(Sender: TObject; Socket: TCustomWinSocket);
var
  i, packetid, x, y, nrand, size: integer;
  datacortada, datadec: ansistring;
begin
  for i:=0 to length(Lista)-1 do begin
    if Lista[i].status then
    if Lista[i].socket=socket then begin
      Lista[i].data:=Lista[i].data+socket.receivetext;
      while true do begin
        size:=0;
        if length(Lista[i].data) > 0 then size:=returnsize(Lista[i].data[2]+Lista[i].data[3]);
        if size=0 then Break;
        if size<=Length(Lista[i].data) then begin
          datacortada:=Copy(Lista[i].data,1,size);
          if length(datacortada)=returnsize(datacortada[2]+datacortada[3]) then begin
            nrand:=ord(datacortada[1]);
            x:=byte(keys[((Lista[i].key-1) shl 8)+nrand+1]);
            y:=byte(keys[((Lista[i].key-1) shl 8)+nrand+4097]);
            if y=(x xor ord(datacortada[5])) then begin
              datadec:=decryptS(datacortada,Lista[i].key);
              packetid:=returnsize(datadec[6]+datadec[7])-4;
              case packetid of
                1: LxChecarLogin(datadec,i);
                3: Px03(i);
                6: Px01n(datadec,i);
                7: LxChecarNick(datadec,i);
                8: LxTerminarPrimeiroLogin(datadec,i);
                11: ; //n�o � usado no oficial e n�o � necess�rio, por�m � um aviso de desconex�o de usu�rio
              else begin
                writeln('packet id: '+inttostr(packetid));
                writeln(space(stringtohex(datadec)));
              end;
              end;
              Delete(Lista[i].data,1,size);
            end
            else begin
              Lista[i].socket.close;
            end;
          end
          else begin
            Lista[i].socket.close;
          end;
        end
        else break;
      end;
    end;
  end;
end;

procedure TObjeto.OnError(Sender: TObject; Socket: TCustomWinSocket; ErrorEvent: TErrorEvent; var ErrorCode: Integer);
var
  i: integer;
begin
  for i:=0 to length(Lista)-1 do
    if Lista[i].status then
      if Lista[i].socket=socket then begin
        Lista[i].status:=false;
        if Lista[i].uid > 0 then begin
          Query.Close;
          Query.SQL.Clear;
          Query.SQL.Add('update py_members set loginstatus = 0 where uid = '+QuotedStr(inttostr(Lista[i].uid))+'');
          Query.ExecSQL;
          TextColor(12);
          Writeln('[SERVER_S] Cliente desconectado! ('+inttostr(i)+')');
          TextColor(7);
        end;
        break;
      end;
end;

end.
