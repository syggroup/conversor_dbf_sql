/*
 *   $Id: dbf2sql.prg 2141 2012-04-06 22:43:44Z leonardo $
 */

#include "hwgui.ch"
#include "common.ch"
#include "Directry.ch"
#include "hbclass.ch"

#include "sqlrdd.ch"
#include "pgs.ch"        // PARA POSTGRESQL
#include "mysql.ch"      // PARA MYSQL
#include "firebird.ch"   // PARA FIREBIRD
#include "oracle.ch"     // PARA ORACLE

#define x_BLUE       16711680
#define x_DARKBLUE   10027008
#define x_WHITE      16777215
#define x_CYAN       16776960
#define x_BLACK             0
#define x_RED             255
#define x_GREEN         32768
#define x_GRAY        8421504
#define x_YELLOW        65535
#define CORPADRAO  COLOR_3DLIGHT+3
#define HB_EXT_INKEY
#define DC_CALL_STD 0x0020

#define HKEY_LOCAL_MACHINE 2147483650

#define LWA_COLORKEY 0x1
#define LWA_ALPHA 0x2

#define WS_EX_LAYERED  524288

REQUEST SQLRDD
REQUEST SR_PGS       // PARA POSTGRESQL
REQUEST SR_MYSQL     // PARA MYSQL
REQUEST SR_FIREBIRD  // PARA FIREBIRD
REQUEST SR_ORACLE    // PARA ORACLE

REQUEST DBFCDX
REQUEST DBFFPT

FUNCTION MAIN(SESSAO)
Local oMainWindow, oTrayMenu, oIcon := HIcon():AddResource(1004)
Local vINICIA := .F.

IF Os_IsWtsClient()=.T.
   IF !MsgYesNo("Deseja Realmente Iniciar o Sincronizador pelo Terminal Service(Acesso Remoto) ?")
      MyExitProc()
   ENDIF
ENDIF

IF SESSAO#NIL
   Dirchange(SESSAO)
ENDIF

RddSetDefault("DBFCDX")
DBSETDRIVER("DBFCDX")

Public oDirec:=CAMINHO_EXE() //DiskName()+":\"+CurDir()   // GetEnv("USERPROFILE")

IF ( hWnd := Hwg_FindWindow( oMainWindow, "Sistema de Sincronização da Sygecom" ) ) != 0 // verefica se o sistema já esta aberto na estação
   Hwg_SetForegroundWindow( hWnd )
   _NewAlert("Esse sistema Já esta aberto, Favor Revisar")
   MyExitProc()
ENDIF

IF IsDirectory( "temp_sql" ) = .F.
   Makedir("temp_sql")
ENDIF

IF !File("DBF2SQL.DBF")
   private aField[10]
   aField[01] := {"TIPO_SQL", "C", 10,  0}  // FIREBIRD, MYSQL, POSTGRE
   aField[02] := {"HOST"    , "C", 60,  0}
   aField[03] := {"PORTA"   , "C",  5,  0}
   aField[04] := {"DATABASE", "C", 40,  0}
   aField[05] := {"USUARIO" , "C", 30,  0}
   aField[06] := {"SENHA"   , "C", 30,  0}
   aField[07] := {"CHARSET" , "C", 15,  0}
   aField[08] := {"INI_AUTO", "L",  1,  0}
   aField[09] := {"PASTA"   , "C", 80,  0}
   aField[10] := {"DBFSQL"  , "C",  7,  0}  // DBF2SQL ou SQL2DBF
   DBcreate("DBF2SQL", aField,"DBFCDX")
   Configura_Servidor()
ENDIF
DBCLOSEALL()

IF Use_Arq("DBF2SQL",,.F.,.F.,.F.)=.F.  // EXCLUSIVO
   _NewAlert("Já existe uma estação usando o sistema, Favor Revisar")
   MyExitProc()
ENDIF
SELE DBF2SQL
dbgotop()
eTIPO_SQL=ALLTRIM(TIPO_SQL)
eHOST    =ALLTRIM(HOST)
ePORTA   =ALLTRIM(PORTA)
eDATABASE=ALLTRIM(DATABASE)
eCHARSET =ALLTRIM(CHARSET)
eINI_AUTO=INI_AUTO
ePASTA   =ALLTRIM(PASTA)
eDBFSQL  =DBFSQL
eUSUARIO =alltrim(USUARIO)
eSENHA   =alltrim(SENHA)

public :=eTIPO_SQL; public :=eHOST    ; public :=ePORTA
public :=eDATABASE; public :=eUSUARIO ; public :=eSENHA
public :=eCHARSET ; public :=eINI_AUTO; public :=ePASTA
public :=eDBFSQL

ferase("canc_dbf2sql.txt")

SetToolTipBalloon(.t.)

IF EMPTY(eHOST)
   _NEWALERT('Sistema Iniciado, Favor configurar os Parametros.','Sincorização',2500)
ELSE
   _NEWALERT('Sistema Iniciado...','Sincorização')
ENDIF

   INIT WINDOW oMainWindow MAIN TITLE "Sistema de Sincronização da Sygecom";
   ON EXIT {|| MyExitProc() }

   CONTEXT MENU oTrayMenu
      MENUITEM "Configurar Conexão"  ACTION Configura_Servidor()
      SEPARATOR
      MENUITEM "Testar Conexão com o Servidor SQL"   ACTION Testar_CONEXAO()
      SEPARATOR
      MENUITEM "Iniciar Sincronização Agora"   ACTION Ini_sincro(10000)
      SEPARATOR
      MENUITEM "Parar Sincronização"   ACTION Ini_sincro(0)
      SEPARATOR
      MENUITEM "Sobre"       ACTION Sobre()
      SEPARATOR
      MENUITEM "Fechar"      ACTION EndWindow()
   ENDMENU

   SET TIMER oTime OF oMainWindow ID 9008 VALUE 30000 ACTION {|| Sincroniza_DBF2SQL() }  //300000

   oMainWindow:InitTray( oIcon,,oTrayMenu,"Sistema de Sincronização da Sygecom")

   ACTIVATE WINDOW oMainWindow NOSHOW
   oTrayMenu:End()

Return Nil

*************************
Function Ini_sincro(vHAB)
*************************
Otime:interval := vHAB
Return

***********************
Function Testar_CONEXAO
***********************
Local nCnn_Teste
AJUSTA_CONEXAO_SQLRDD()

Otime:interval := 0  // DA UM STOP NO TIMER

IF EMPTY(eHOST) .OR. EMPTY(eUSUARIO) .OR. EMPTY(eSENHA) .OR. EMPTY(eDATABASE)
   MsgInfo("Os parametros de conexão estão incompleto, Favor revisar")
   Return
ENDIF

PRIVATE oDlgHabla:=NIL
MsgRun("Conectando ao Banco de Dados...")

IF eTIPO_SQL="MYSQL"
   nCnn_Teste := SR_AddConnection(CONNECT_MYSQL   , "MySQL="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";DTB="+eDATABASE+";PRT="+ePORTA )
ELSEIF eTIPO_SQL="POSTGRESQL"
   nCnn_Teste := SR_AddConnection(CONNECT_POSTGRES, "PGS="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";DTB="+eDATABASE+";PRT="+ePORTA )
ELSEIF eTIPO_SQL="FIREBIRD"
   nCnn_Teste := SR_AddConnection(CONNECT_FIREBIRD, "FIREBIRD="+eHOST+":"+eDATABASE+";UID="+eUSUARIO+";pwd="+eSENHA+"+;charset="+eCHARSET)
ELSEIF eTIPO_SQL="ORACLE"
   nCnn_Teste := SR_AddConnection(CONNECT_ORACLE, "OCI="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";TNS="+eDATABASE )
ENDIF
If nCnn_Teste < 0
   Fim_Run()
   MsgInfo("Não Conectou ao Banco On-Line")
ELSE
   SR_EndConnection( nCnn_Teste )
   Fim_Run()
   MsgInfo("Conectou com Sucesso ao Banco On-Line")
EndIf
oTime:interval := 300000  // INICIA O TIMER NOVAMENTE
Return

******************************
Function Iniciar_Windows(vHAB)
******************************
// vHAB = .T. (Aciona a execução automatica)
// vHAB = .F. (Desativa a execução automatica)
IF vHAB = .T.
   SetRegistry( HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Windows\CurrentVersion\Run","dbf2sql", oDirec+"\dbf2sql.exe "+ oDirec )
ELSE
   SetRegistry( HKEY_LOCAL_MACHINE, "SOFTWARE\Microsoft\Windows\CurrentVersion\Run","dbf2sql", "" )
ENDIF
Return Nil

***************************
Function Configura_Servidor
***************************
PRIVATE oJanela
PRIVATE oFont, oOwnerbutton1
PRIVATE aItens  :={"MYSQL","POSTGRESQL","FIREBIRD","ORACLE"}

PRIVATE oTIPO_SQL
PRIVATE oHOST
PRIVATE oPORTA
PRIVATE oDATABASE
PRIVATE oUSUARIO
PRIVATE oSENHA
PRIVATE oCHARSET
PRIVATE oINI_AUTO
PRIVATE oPASTA
PRIVATE oRadiobutton1, oRadiobutton2, LPASTA

PRIVATE vTIPO_SQL:=aItens[1]
PRIVATE vHOST    :=""
PRIVATE vPORTA   :=""
PRIVATE vDATABASE:=""
PRIVATE vUSUARIO :=""
PRIVATE vSENHA   :=""
PRIVATE vCHARSET :=""
PRIVATE vINI_AUTO:=.F.
PRIVATE vPASTA   :=""
PRIVATE vRadiogroup1 := 1
PRIVATE vDBFSQL  :="DBF2SQL"

IF SELECT("DBF2SQL")=0
   IF Use_Arq("DBF2SQL",,.F.,.F.,.F.)=.F.  // EXCLUSIVO
      _NewAlert("Já existe uma estação usando o sistema, Favor Revisar")
      MyExitProc()
   ENDIF
ENDIF
SELE DBF2SQL
IF LASTREC() > 0
   dbgotop()
   vTIPO_SQL=ALLTRIM(TIPO_SQL)
   vHOST    =ALLTRIM(HOST)
   vPORTA   =ALLTRIM(PORTA)
   vDATABASE=ALLTRIM(DATABASE)
   vUSUARIO =ALLTRIM(USUARIO)
   vSENHA   =ALLTRIM(SENHA)
   vCHARSET =ALLTRIM(CHARSET)
   vINI_AUTO=INI_AUTO
   vPASTA   =ALLTRIM(PASTA)
   vDBFSQL  =DBFSQL
   
   IF vDBFSQL = "DBF2SQL"
      vRadiogroup1 := 1
   ELSE
      vRadiogroup1 := 2
   ENDIF
ELSE
   AppRede()
   Replace TIPO_SQL with vTIPO_SQL,;
   DBFSQL           with "DBF2SQL"
   LIBERAREG()
   dbcommit()
ENDIF
SetToolTipBalloon(.t.)
SetColorinFocus( .t. )

PREPARE FONT oFont NAME "Arial" WIDTH 0 HEIGHT -12 WEIGHT 400
INIT DIALOG oJanela CLIPPER NOEXIT TITLE "Configuração de Conexão com Servidor";
AT 0,0 SIZE 600,310;
ICON HIcon():AddResource(1004) ;
ON INIT {|| IIF(vDBFSQL = "DBF2SQL",(LPASTA:setvalue("Pasta Monitorada:")),(LPASTA:setvalue("Salvar na Pasta:"))),.T.};
FONT oFont ;
STYLE DS_CENTER + WS_VISIBLE + WS_CAPTION + WS_SYSMENU

@ 5,5 GROUPBOX grpConfiguracao        CAPTION "Configuração de Conexão com Servidor" SIZE 590,255;
COLOR 16711680

@ 31 ,42  SAY LINICIAR CAPTION "Tipo de Banco:" SIZE 100,22
@ 120,40 GET COMBOBOX oTIPO_SQL VAR vTIPO_SQL ITEMS aItens SIZE 150,24 TEXT;
ON CHANGE { || Atualiza_porta(vTIPO_SQL) };
VALID { || Atualiza_porta(vTIPO_SQL) };
TOOLTIP 'Selecione Aqui o Tipo de Banco de Dados'

@ 320,42  SAY LINICIAR CAPTION "Porta de Conexão:" SIZE 100,22
@ 434,40 GET oPORTA VAR vPORTA SIZE 100,24;
STYLE ES_AUTOHSCROLL PICTURE '99999';
TOOLTIP 'Informe a porta de Conexão com o Banco de dados'

@ 15 ,72  SAY LINICIAR CAPTION "Host de Conexão:" SIZE 100,22
@ 120,70 GET oHOST VAR vHOST SIZE 415,24;
STYLE ES_AUTOHSCROLL MAXLENGTH 60;
TOOLTIP 'Informe o Host ou IP de Conexão com o Banco de dados'

@ 27 ,102 SAY LINICIAR CAPTION "Base de dados:" SIZE 100,22
@ 120,100 GET oDATABASE VAR vDATABASE SIZE 415,24;
STYLE ES_AUTOHSCROLL MAXLENGTH 40;
TOOLTIP 'Informe o nome do banco de dados'

@ 62 ,132 SAY LINICIAR CAPTION "Usuario:" SIZE 100,22
@ 120,130 GET oUSUARIO VAR vUSUARIO SIZE 150,24;
STYLE ES_AUTOHSCROLL MAXLENGTH 30;
TOOLTIP 'Informe o usuario para a conexão'

@ 330,132 SAY LINICIAR CAPTION "Senha:" SIZE 100,22
@ 385,130 GET oSENHA VAR vSENHA SIZE 150,24 PASSWORD;
STYLE ES_AUTOHSCROLL MAXLENGTH 30;
TOOLTIP 'Informe a senha do usuario'

@ 64 ,162 SAY LINICIAR CAPTION "CharSet:" SIZE 100,22
@ 120,160 GET oCHARSET VAR vCHARSET SIZE 150,24;
STYLE ES_AUTOHSCROLL MAXLENGTH 15;
TOOLTIP 'Informe o Ecoding ou Charset de conexão'

GET RADIOGROUP vRadiogroup1
    @ 120,190 RADIOBUTTON oRadiobutton1 CAPTION "De DBF para SQL" SIZE 130,22   ;
    ON CLICK {|| LPASTA:setvalue("Pasta Monitorada:") } ;
    TOOLTIP 'Clique Aqui Sincronizar de DBF para SQL'

    @ 300,190 RADIOBUTTON oRadiobutton2 CAPTION "De SQL para DBF" SIZE 130,22   ;
    ON CLICK {|| LPASTA:setvalue("Salvar na Pasta:") } ;
    TOOLTIP 'Clique Aqui Sincronizar de SQL para DBF'
END RADIOGROUP //SELECTED 1


@ 17 ,222 SAY LPASTA CAPTION "Pasta Monitorada:" SIZE 100,22
@ 120,220 GET oPASTA VAR vPASTA SIZE 415,24;
STYLE ES_AUTOHSCROLL PICTURE '@!' MAXLENGTH 40;
TOOLTIP 'Selecione a pasta que será Monitorada'

   @ 550,222 OWNERBUTTON oOwnerbutton1  SIZE 24,24    FLAT  ;
   BITMAP 1002 FROM RESOURCE  TRANSPARENT  ;
   ON CLICK {|| Busca_Local() } ;
   TOOLTIP 'Clique aqui para Buscar um Local onde vai ser Monitorado';
   STYLE WS_TABSTOP

@ 17,270 GET CHECKBOX oINI_AUTO VAR vINI_AUTO CAPTION "Iniciar esse Aplicativo Junto com Windows" TRANSPARENT SIZE 275,22;
ON CLICK {|| Iniciar_Windows(vINI_AUTO) }

@ 385,265 BUTTONEX oButton1 CAPTION "&Salvar" SIZE 100, 38 ;
BITMAP (HBitmap():AddResource(1006)):handle  ;
BSTYLE 0;
TOOLTIP "Salvar a seleção de Impressora de Cheque";
ON CLICK {||  Salva_dados() };
STYLE WS_TABSTOP

@ 495,265 BUTTONEX oButton2 CAPTION "&Cancelar" SIZE 100,38 ;
BITMAP (HBitmap():AddResource(1005)):handle  ;
BSTYLE 0;
TOOLTIP "Sair e Voltar ao Menu";
ON CLICK {|| oJanela:Close() };
STYLE WS_TABSTOP

oJanela:Activate()

RETURN nil

********************
Function Busca_Local
********************
vPASTA := SELECTFOLDER()
oPASTA:SetText(vPASTA)
oPASTA:refresh()
Return Nil

********************
Function Salva_dados
********************
IF EMPTY(vHOST)
   MsgInfo("Obrigatorio informar o Host de conexão, Favor revisar")
   oHOST:setfocus()
 	 RETURN
ENDIF

IF EMPTY(vDATABASE)
   MsgInfo("Obrigatorio informar o Banco de dados de Acesso, Favor revisar")
   oDATABASE:setfocus()
 	 RETURN
ENDIF

IF EMPTY(vUSUARIO)
   MsgInfo("Obrigatorio informar o Usuario de Acesso, Favor revisar")
   oUSUARIO:setfocus()
 	 RETURN
ENDIF

IF EMPTY(vSENHA)
   MsgInfo("Obrigatorio informar a Senha do Usuario, Favor revisar")
   oSENHA:setfocus()
 	 RETURN
ENDIF
vPASTA=ALLTRIM(vPASTA)

IF EMPTY(vPASTA)
   MsgInfo("Obrigatorio Informar a Pasta que será monitorada")
   oOwnerbutton1:setfocus()
 	 RETURN
ELSE
   IF Right(ALLTRIM(vPASTA),1) = "\"
      vPASTA = StrTran( vPASTA, "\",RAt("\",vPASTA),1 )
   ENDIF
ENDIF

IF STR(vRadiogroup1,1)="1"
   aFiles_temp := directory( alltrim(vPASTA) + "\*.dbf" )
   IF LEN(aFiles_temp) <= 0
      MsgInfo("A Pasta de monitoramento não contem arquivos para serem Sincronizados, Favor Revisar")
      oOwnerbutton1:setfocus()
    	 RETURN
   ENDIF
ELSE
   IF Right(ALLTRIM(vPASTA),1) # "\"
      vPASTA = vPASTA+"\"
   ENDIF
ENDIF

vUSUARIO=alltrim(vUSUARIO)
vSENHA=alltrim(vSENHA)

SELE DBF2SQL
dbgotop()
TRAVAREG("S")
Replace TIPO_SQL WITH ALLTRIM(vTIPO_SQL),;
HOST             WITH ALLTRIM(vHOST),;
PORTA            WITH vPORTA,;
DATABASE         WITH vDATABASE,;
USUARIO          WITH vUSUARIO,;
SENHA            WITH vSENHA,;
CHARSET          WITH vCHARSET,;
INI_AUTO         WITH (oINI_AUTO:GetValue()),;
PASTA            WITH vPASTA,;
DBFSQL           WITH IIF(STR(vRadiogroup1,1)="1","DBF2SQL","SQL2DBF")
DBCOMMIT()
LIBERAREG()

MsgInfo("Informações salvas com sucesso, Para usar essas configurações você tem que fechar e abrir o sistema novamente")

oJanela:Close()
RETURN

***************************
Function Atualiza_porta(vP)
***************************
IF vP="MYSQL"
   vPORTA="3306"
ELSEIF vP="POSTGRESQL"
   vPORTA="5432"
ELSEIF vP="FIREBIRD"
   vPORTA="3050"
ELSEIF vP="ORACLE"
   vPORTA="1521"
ENDIF
oPORTA:SetText( vPORTA )
oPORTA:Refresh()
Return(.T.)

#define SQL_DBMS_NAME                       17
#define SQL_DBMS_VER                        18

**************
FUNCTION SOBRE
**************
Local form_sobre3

Local oGroup1, oOwnerbutton1, oLabel1, oLabel3, oLabel4, oLabel5
Local oLabel6, oLink1, oLine1, oLabel7, oOwnerbutton2, oLabel2, oLabel8
Local oLabel9, oLabel10, oLink2, oGroup2, oEditbox1, oEditbox2, oEditbox3

Local vEditbox1 := "Data da Ultima Atualização.: " + Data_Hora_ARQ(NomeExecutavel())
Local vEditbox2 := "Versão Do Compilador.: " + version() + " + "+ HWG_Version()
IF SR_CheckCnn() = .F.     // VEREFICA SE ESTA ATIVA A CONEXÃO
   Private vEditbox3 := "Não Conectado ao Banco de dados"
else
   Private vEditbox3 := "Banco de Dados: " +SR_GetConnectionInfo(, SQL_DBMS_NAME) +" - " +SR_GetConnectionInfo(, SQL_DBMS_VER)
endif

  PREPARE FONT oFontBtn NAME "Arial" WIDTH 0 HEIGHT -12
  INIT DIALOG form_sobre3 CLIPPER NOEXIT TITLE "Informações Sobre o Sistema" ;
  AT 0,0 SIZE 684,620 ;
  ICON HIcon():AddResource(1004);
  STYLE DS_CENTER + WS_VISIBLE + WS_CAPTION + WS_SYSMENU

   @ 23,212 LINE oLine1 OF oGroup1  LENGTH 639

   @ 481,22 BITMAP oOwnerbutton1  ;
        SHOW 1003 FROM RESOURCE  ;
        OF oGroup1  TRANSPARENT SIZE 173,182

   @ 20,32 SAY oLabel1 CAPTION "Sistema Desenvolvido Pela.:" OF oGroup1  SIZE 273,25    ;
   FONT HFont():Add( '',0,-19,700,,,)

   @ 20,63 SAY oLabel3 CAPTION "Sygecom Informática Ltda." OF oGroup1  SIZE 211,24  ;
   COLOR 16711680   ;
   FONT HFont():Add( '',0,-16,700,,,)

   @ 20,93 SAY oLabel4 CAPTION "Rua.: Artur Garcia, 271  - Bairro.: Bela Vista" OF oGroup1  SIZE 334,24  ;
   COLOR 16711680   ;
   FONT HFont():Add( '',0,-16,700,,,)

   @ 20,123 SAY oLabel5 CAPTION "Alvorada - RS /  Cep.: 94810-090" OF oGroup1  SIZE 255,24  ;
   COLOR 16711680   ;
   FONT HFont():Add( '',0,-16,700,,,)

   @ 19,153 SAY oLabel6 CAPTION "Telefones.: (xx51) 3442 - 2345  /  (xx51) 3442 - 3975" OF oGroup1  SIZE 386,24  ;
   COLOR 16711680   ;
   FONT HFont():Add( '',0,-16,700,,,)

   @ 21,183 SAY oLink1 CAPTION "Web Site.: www.sygecom.com.br" OF oGroup1  ;
   LINK 'www.sygecom.com.br'  SIZE 235,22 ;
   COLOR 16711680   ;
   FONT HFont():Add( '',0,-16,400,,,);
   TOOLTIP 'Clique Aqui para Visitar o Site da Sygecom Informática Ltda.'

   @ 10,5 GROUPBOX oGroup1 CAPTION "Informações Gerais do Sistema"  SIZE 665,460

   @ 15,495 GET oEditbox1 VAR vEditbox1 OF oGroup2  SIZE 652,22 ;
   STYLE WS_DISABLED +WS_BORDER     ;
   TOOLTIP 'Versão'

   @ 15,520 GET oEditbox2 VAR vEditbox2 OF oGroup2  SIZE 652,22 ;
   STYLE WS_DISABLED +WS_BORDER     ;
   FONT HFont():Add( '',0,-12,400,,,);
   TOOLTIP 'Versão Compilador'

   @ 15,547 GET oEditbox3 VAR vEditbox3 OF oGroup2  SIZE 652,22 ;
   FONT HFont():Add( '',0,-12,400,,,);
   STYLE WS_DISABLED +WS_BORDER     ;
   TOOLTIP 'Versão Banco de Dados'

   @ 10,475 GROUPBOX oGroup2 CAPTION "Informações Técnicas do Sistema"  SIZE 665,101

   @ 574,580 BUTTONEX "&Fechar" SIZE 100,38;
   BITMAP (HBitmap():AddResource(1005)):handle  ;
   ON CLICK {|| EndDialog() } ;
   STYLE SS_CENTER

   ACTIVATE DIALOG form_sobre3

RETURN Nil

********************************************************************************
***************INICIO DA MENSAGEM RUM NA TELA***********************************
********************************************************************************
FUNCTION MsgRun(cMsg)
MsgRun2(cMsg)
HW_Atualiza_Dialogo(cMsg)
Return

*********************
FUNCTION MsgRun2(cMsg)
*********************
PRIVATE oTimHabla
PRIVATE oButtonexCanc

if cMsg=Nil
   cMsg:="Aguarde em processamento...."
endif

INIT DIALOG oDlgHabla TITLE "Sincronização de Banco de dados" NOEXIT NOEXITESC;
AT GETDESKTOPWIDTH()-340,GETDESKTOPHEIGHT()-45 SIZE 340,60 ;
ICON HIcon():AddResource(1004) ;
STYLE WS_VISIBLE + WS_CAPTION;
COLOR Rgb(255, 255, 255)

//STYLE WS_VISIBLE + WS_CAPTION + WS_SYSMENU;

@ 15,20 SAY oTimHabla CAPTION cMsg SIZE 225,20;
FONT HFont():Add( "Arial", 0 ,-13,550,255 );
BACKCOLOR Rgb(255, 255, 255)

  @ 235,8 BUTTONEX oButtonexCanc CAPTION "&Cancelar"  SIZE 100,38 ;
  BITMAP (HBitmap():AddResource(1005)):handle  ;
  FONT HFont():Add( "Arial", 0 ,-13,550,255 );
  ON CLICK {|| criar_canc(),oDlgHabla:Close() };
  TOOLTIP 'Clique Aqui para Cancelar'

HWG_DOEVENTS()

ACTIVATE DIALOG oDlgHabla NOMODAL

Return Nil

*******************
Function criar_canc
*******************
Local arqh
Local arq1:="canc_dbf2sql.txt"
if !File(arq1)
   arqh=fcreate(arq1,0)
   if !arqh>0
      Return
   endif
   fclose(arqh)
endif
Return

****************
Function Fim_Run
****************
IF oDlgHabla#NIL
   oDlgHabla:CLOSE()
ENDIF
Return Nil

****************************************
FUNCTION HW_Atualiza_Dialogo(vMensagem)
****************************************
HWG_DOEVENTS()
oDlgHabla:ACONTROLS[1]:SETTEXT(vMensagem)
RETURN(.T.)

********************************************************************************
***********VEREFICA O NOME DO EXECUTAVEL E O CAMINHO DO MESMO*******************
*NomeExecutavel()    // verefica o nome
*NomeExecutavel(.t.) // verefica o caminho
********************************************************************************
Function NomeExecutavel(lPath)
LOCAL nPos, cRet
If Empty(lpath)
   nPos:= RAT("\", hb_argv(0))
   cRet:= substr(hb_argv(0), nPos+1)
else
   cRet:= hb_argv(0)
endif
Return cRet
********************
*Retorna o caminho do EXE
FUNCTION CAMINHO_EXE
Return(Substr(Nomeexecutavel(.t.),1,(len(Nomeexecutavel(.t.))- len(Nomeexecutavel()))-1 ))

********************************************************************************
***********FIM DA ROTINA DE VEREFICAÇÃO DE EXECUTAL*****************************
********************************************************************************

*******************
Function MyExitProc
*******************
DBCLOSEALL()
PostQuitMessage(0)
__Quit()
RETURN .T.

********************************************************
FUNCTION Use_Arq(cArquivo,cAlias,iShared,iLeitura,iTemp)
********************************************************
//--> cArquivo : Nome do Arquivo
//--> cAlias   : Nome do Apelido
//--> iShared  : .f. Exclusivo ou .t. Compartilhado
//--> iLeitura : .t. só Leitura ou .f. Leitura e Gravação
//--> iTemp    : .t. usa uma tabela temporaria ou .f. abre uma tabela normal
local lReturn  := .F.
Local cDriver  := "DBFCDX"
DEFAULT  iShared  TO  .F.
DEFAULT  iLeitura TO  .F.
DEFAULT  cAlias   TO cArquivo

if iTemp = .T.
   cDriver:="DBFCDX"
endif

do while .t.
   IF SELECT(cAlias)=0
      TRY
         DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
         DbUseArea(.t.,cDriver,cArquivo,cAlias,iShared,iLeitura,,)
      catch e
         Return .f.
      END
      IF NetErr()
         Return .f.
      else
         SELECT(cAlias)
         Return .t.
      endif
   ELSE
      SELECT(cAlias)
      Return .t.
   ENDIF
enddo
Return lReturn

****************************
FUNCTION DATA_HORA_ARQ(vArq)
****************************
SET CENTURY ON
SET DATE BRITISH
SET EPOCH TO 2000

aDir  := Directory( vArq )
aRet  := Transform(DtoC(aDir[1,3]),"@d")
aRet2 := aDir[1,4]
Return( aRet + " - " + aRet2 )

***************************
FUNCTION SINCRONIZA_DBF2SQL
***************************
Local aARRAY_TEMP := {}

AJUSTA_CONEXAO_SQLRDD()
//ESSE COMANDO ACIMA FAZ COM QUE A FUNÇÃO: MYCONNECTRAW() SUBISTITUA A FUNÇÃO: CONNECTRAW DENTRO DA CLASSE SR_PGS(SQLRDD)

Otime:interval := 0  // DA UM STOP NO TIMER

IF EMPTY(eHOST) .OR. EMPTY(eUSUARIO) .OR. EMPTY(eSENHA) .OR. EMPTY(eDATABASE)
   Return
ENDIF

IF SR_CheckCnn() = .F.     // VEREFICA SE ESTA ATIVA A CONEXÃO
   PRIVATE oDlgHabla:=NIL
   MsgRun("Conectando ao Banco de Dados...")

   SR_SetFastOpen(.T.)             // ABRE AS TABELAS EM MODO COMPARTILHADO
   SR_SetBaseLang( 2 )             // linguagem portugues
   SR_Msg(2)                       // portugues
   SETPGSOLDBEHAVIOR(.T.)          // CONSIDERAR CAMPOS NULL COMO VAZIO

   IF eTIPO_SQL="MYSQL"
      nCnn_Teste := SR_AddConnection(CONNECT_MYSQL   , "MySQL="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";DTB="+eDATABASE+";PRT="+ePORTA )
   ELSEIF eTIPO_SQL="POSTGRESQL"
      nCnn_Teste := SR_AddConnection(CONNECT_POSTGRES, "PGS="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";DTB="+eDATABASE+";PRT="+ePORTA )
   ELSEIF eTIPO_SQL="FIREBIRD"
      nCnn_Teste := SR_AddConnection(CONNECT_FIREBIRD, "FIREBIRD="+eHOST+":"+eDATABASE+";UID="+eUSUARIO+";pwd="+eSENHA+"+;charset="+eCHARSET)
   ELSEIF eTIPO_SQL="ORACLE"
      nCnn_Teste := SR_AddConnection(CONNECT_ORACLE, "OCI="+eHOST+";UID="+eUSUARIO+";PWD="+eSENHA+";TNS="+eDATABASE )
   ENDIF
   If nCnn_Teste < 0
      Fim_Run()
      _newalert("Não Conectou ao Banco On-Line")
      Return .f.
   ELSE
      Fim_Run()
   EndIf
   IF "9.1" $ (SR_GetConnection():cSystemVers) // se for uma versão 9.1
      EXECUTA_SQL("set standard_conforming_strings to 'off'") // SET nescessario para a gravação das imagens nas tabelas
   ENDIF
   SR_SetFastOpen(.T.)             // ABRE AS TABELAS EM MODO COMPARTILHADO
   SR_SetBaseLang( 2 )             // linguagem portugues
   SR_Msg(2)                       // portugues
   SETPGSOLDBEHAVIOR(.T.)          // CONSIDERAR CAMPOS NULL COMO VAZIO
ENDIF


IF IsDirectory(ePASTA)
   IF eDBFSQL="DBF2SQL"
      ferase("canc_dbf2sql.txt")
      IF !File("LISTDBF.DBF")
         private aField[3]
         aField[1] := {"NOME"    , "C", 50,  0}
         aField[2] := {"DATA"    , "D",  8,  0}
         aField[3] := {"HORA"    , "C",  8,  0}
         DBcreate("LISTDBF", aField,"DBFCDX")
      ENDIF

      IF Use_Arq("LISTDBF",,.F.,.F.,.F.)=.F.  // EXCLUSIVO
         _NewAlert("Já existe uma estação usando o sistema, Favor Revisar")
         MyExitProc()
      ENDIF
      aFiles := directory( ePASTA + "\*.dbf" )
      IF LEN(aFiles)  > 0
         FOR nI := 1 TO LEN(aFiles)
            SELE LISTDBF
            LOCATE FOR NOME=aFiles[nI,1]
            IF !FOUND()
               SELE LISTDBF
               AppRede()
               Replace NOME WITH aFiles[nI,1],;
               DATA         WITH aFiles[nI,3],;
               HORA         WITH aFiles[nI,4]
               DBCOMMIT()
               LIBERAREG()
               AADD(aARRAY_TEMP,{aFiles[nI,1],aFiles[nI,3],aFiles[nI,4]})
            ENDIF
         NEXT

         SELE LISTDBF
         DbGoTop()
         Do while !EOF()
            vNOME=ALLTRIM(NOME)
            vDATA=DATA
            vHORA=HORA

            IF AScan( aARRAY_TEMP, {|a| a[1] = vNOME } )=0
               vRET:= AScan( aFiles, {|a| a[1] = vNOME } )
               IF vRET > 0
                  IF vDATA < aFiles[vRET,3]
                     AADD(aARRAY_TEMP,{aFiles[vRET,1],aFiles[vRET,3],aFiles[vRET,4]})
                  ELSEIF vDATA = aFiles[vRET,3]
                     IF Secs(vHORA) < Secs(aFiles[vRET,4])
                        AADD(aARRAY_TEMP,{aFiles[vRET,1],aFiles[vRET,3],aFiles[vRET,4]})
                     ENDIF
                  ENDIF
               ENDIF
            ENDIF

            SELE LISTDBF
            DBSKIP()
         ENDDO

         IF LEN(aARRAY_TEMP)  > 0
            upload( ePASTA+"\", "", "DBFCDX", aARRAY_TEMP )
         ENDIF
      ELSE
         _newalert("Não foi possivel localizar os Arquivos de sincronização")
         oTime:interval := 0  // PARAR O TIMER
         Return
      ENDIF
   ELSE
      Private oDlgHabla:=nil
      MsgRun("Aguarde Sincronizando...","Aguarde")
      aDir0 := {}
      aDir0 := SR_ListTables()
      For x=1 to len(aDir0)
         IF Upper(LEFT(aDir0[x],2)) # "SR"
            cALIAS_TEMP:=aDir0[x]
            TRY
               DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
               dbUseArea( .T., "SQLRDD", aDir0[x] , aDir0[x], .T. )
               SELE &cALIAS_TEMP
            catch e
               &cALIAS_TEMP->(dbCloseArea())
               LOOP
            END

            COPY TO (ePASTA+aDir0[x]) VIA "DBFCDX" while BARRA((RECNO()),LASTREC(),aDir0[x])
            &cALIAS_TEMP->( dbCloseArea() )

            IF FILE("canc_dbf2sql.txt")
               FERASE("canc_dbf2sql.txt")
               EXIT
            ENDIF
         ENDIF
      NEXT
      FIM_RUN()
   ENDIF
ELSE
   _newalert("Não foi possivel localizar a pasta de sincronização")
   oTime:interval := 0  // PARAR O TIMER
   Return
ENDIF
oTime:interval := 1800000  // INICIA O TIMER NOVAMENTE PARA A CADA 30 MIN.
Return

****************************************************
FUNCTION UPLOAD( cBaseDir, cPrefix, cDriver, aFiles)
****************************************************
local aStruct, aFile, cFile

PRIVATE oDlgHabla:=NIL
MsgRun("Importando Informações...")

For each aFile in aFiles
   cFile := strtran(strtran(lower( alltrim( cPrefix + aFile[ F_NAME ] )),".dbf",""),"$","_")
   HW_Atualiza_Dialogo("Importando: " + cFile)

   IF FILE("canc_dbf2sql.txt")
      FOR nI := 1 TO LEN(aFiles)
         SELE LISTDBF
         LOCATE FOR NOME=aFiles[nI,1]
         IF FOUND()
            TRAVAREG("S")
            DELE
            DBCOMMIT()
            LIBERAREG()
         ENDIF
      NEXT
      SELE LISTDBF
      PACK
      ferase("canc_dbf2sql.txt")
      EXIT
   ENDIF

   Copia_Arquivo( cBaseDir + aFile[ F_NAME ] , "temp_sql\"+ aFile[ F_NAME ])
   IF FILE("temp_sql\"+ aFile[ F_NAME ])
      IF !SR_ExistTable(cFile)
         TRY
            DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
            dbUseArea( .T., cDriver, "temp_sql\"+ aFile[ F_NAME ], "ORIG",.T.,.T. )
         catch e
            ORIG->(dbCloseArea())
            LOOP
         END

         aStruct := ORIG->( dbStruct() )
         dbCreate( cFile, aStruct, "SQLRDD" )

         TRY
            DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
            dbUseArea( .T., "SQLRDD", cFile, "DEST", .T. )
         catch e
            ORIG->(dbCloseArea())
            DEST->(dbCloseArea())
            LOOP
         END

         SELE ORIG
         n:=1
         while .t.
            if empty( ordname(n) )
               exit
            endif
           DEST->(ordCondSet(orig->(ordfor(n)),,.t.,,,, nil, nil, nil, nil,, nil, .F., .F., .F., .F.))
           DEST->(dbGoTop())
           DEST->(ordCreate(,orig->(OrdName(n)), orig->(ordKey(n)), &("{||"+orig->(OrdKey(n))+"}") ))
           ++n
         enddo
         ORIG->( dbCloseArea() )
      ELSE
         TRY
            DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
            dbUseArea( .T., "SQLRDD", cFile, "DEST", .T. )
         catch e
            DEST->(dbCloseArea())
            LOOP
         END
         vCONTA_CAMPO1:=FCount()

         TRY
            DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
            dbUseArea( .T., cDriver, "temp_sql\"+ aFile[ F_NAME ], "ORIG",.T.,.T. )
         catch e
            DEST->(dbCloseArea())
            ORIG->(dbCloseArea())
            LOOP
         END
         vCONTA_CAMPO2:=FCount()

         IF vCONTA_CAMPO1 # vCONTA_CAMPO2
            aStruct := ORIG->( dbStruct() )
            DEST->( dbCloseArea() )
            dbCreate( cFile, aStruct, "SQLRDD" )

            TRY
               DBSELECTAREA(0) // SELECIONA A PROXIMA AREA LIVRE
               dbUseArea( .T., "SQLRDD", cFile, "DEST", .T. )
            catch e
               DEST->(dbCloseArea())
               ORIG->(dbCloseArea())
               LOOP
            END

            SELE ORIG
            n:=1
            while .t.
               if empty( ordname(n) )
                  exit
               endif
              DEST->(ordCondSet(orig->(ordfor(n)),,.t.,,,, nil, nil, nil, nil,, nil, .F., .F., .F., .F.))
              DEST->(dbGoTop())
              DEST->(ordCreate(,orig->(OrdName(n)), orig->(ordKey(n)), &("{||"+orig->(OrdKey(n))+"}") ))
              ++n
            enddo
         ENDIF
         ORIG->( dbCloseArea() )
      ENDIF

      IF SELECT("DEST")#0
         SELE DEST
         __DBZAP()
         Append from ("temp_sql\"+ aFile[ F_NAME ]) while BARRA((RECNO()),LASTREC(),cFile) VIA cDriver
         DEST->( dbCloseArea() )

         SELE LISTDBF
         LOCATE FOR NOME=aFile[F_NAME]
         IF FOUND()
            vRET:= AScan( aFiles, {|a| a[1] = aFile[F_NAME] } )
            TRAVAREG("S")
            REPLACE DATA WITH aFiles[vRET,2],;
            HORA         WITH aFiles[vRET,3]
            DBCOMMIT()
            LIBERAREG()
         ENDIF

         FERASE("temp_sql\"+ aFile[ F_NAME ])
         IF FILE(SUBSTR("temp_sql\"+ aFile[ F_NAME ], 1, LEN("temp_sql\"+ aFile[ F_NAME ])-4)+".fpt")
            FERASE(SUBSTR("temp_sql\"+ aFile[ F_NAME ], 1, LEN("temp_sql\"+ aFile[ F_NAME ])-4)+".fpt")
         ENDIF
         IF FILE(SUBSTR("temp_sql\"+ aFile[ F_NAME ], 1, LEN("temp_sql\"+ aFile[ F_NAME ])-4)+".cdx")
            FERASE(SUBSTR("temp_sql\"+ aFile[ F_NAME ], 1, LEN("temp_sql\"+ aFile[ F_NAME ])-4)+".cdx")
         ENDIF
      ENDIF
   ENDIF
Next
FIM_RUN()
Return

*****************************
FUNCTION BARRA(VNQ,VNT,cFile)
*****************************
HW_Atualiza_Dialogo(cFile+" - Progresso: " + Str((VNQ/VNT)*100,4) +" %")
RETURN .T.

*************************************
FUNCTION COPIA_ARQUIVO(cORIGEM,cDEST)
*************************************
Ferase(cDEST)
Ferase(SUBSTR(cDEST, 1, LEN(cDEST)-4)+".fpt")
__CopyFile( cORIGEM ,cDEST)
IF FILE(SUBSTR(cORIGEM, 1, LEN(cORIGEM)-4)+".fpt")
   __CopyFile( SUBSTR(cORIGEM, 1, LEN(cORIGEM)-4)+".fpt" , SUBSTR(cDEST, 1, LEN(cDEST)-4)+".fpt" )
ENDIF
IF FILE(SUBSTR(cORIGEM, 1, LEN(cORIGEM)-4)+".cdx")
   __CopyFile( SUBSTR(cORIGEM, 1, LEN(cORIGEM)-4)+".cdx" , SUBSTR(cDEST, 1, LEN(cDEST)-4)+".cdx" )
ENDIF
Return

******************
Function LiberaREG
******************
DBUNLOCK()
Return

****************
Function AppRede
****************
Local vCONTA := 0
DO While .T.
   vCONTA= vCONTA + 1
   IF NetAppend(1,.f.)
      TravaReg("S")
      Return(.T.)
   ELSE
      MilliSec( 1000 )    // espera um segundo antes de tentar novamente
   ENDIF
   IF vCONTA > 10
      IF MsgYesNo("Não Foi possivel Adicionar o Registro, Deseja Tentar Novamente ?")
         vCONTA=0
         loop
      Else
         exit
         Return(.F.)
      Endif
   ENDIF
Enddo
Return(.F.)

**************************
Function TravaReg(xEterno)
**************************
DO While .T.
   vTentativas=0
   DO While .T.
      IF Rlock()
         Return .T.
      ElSE // TENTA DE NOVO
         IF xEterno="N"  // É OBRIGADO A TRAVAR
            Return .F.
         ENDIF
         MilliSec( 1000 )    // espera um segundo antes de voltar

         If vTentativas=10
            IF xEterno="S"  // É OBRIGADO A TRAVAR
               vTentativas=0
               LOOP
            ELSE

               EXIT
            ENDIF
         else
            vTentativas=vTentativas+1
            Loop
         endif
      EndIf
   EndDo

   IF MsgYesNo("Não Foi possivel Travar o Registro, Deseja Tentar Novamente ?")
      loop
   Else
      exit
      Return .F.
   Endif
ENDDO

Return .F.

*****************
Function GERAFILE
*****************
Public cFILE := GETENV("temp")+ "\sy_temp\TEMP"+ ALLTRIM( STR( HB_RandomInt(99999) ))
RETURN cFILE

********************************************
FUNCTION _NEWALERT(cmensagem,ctitulo,nTEMPO)
********************************************
PRIVATE oAlert, oEdtMensagem
IF nTEMPO=NIL
   nTEMPO=50
ENDIF

INIT DIALOG oAlert  TITLE ctitulo ;
AT 0,0 SIZE 400,100 ;
STYLE DS_CENTER+WS_CAPTION+WS_POPUP ;
ON GETFOCUS {||mensagem(cMensagem,nTEMPO),oAlert:close()};
ON INIT     {|O| FormInit(oAlert)};
COLOR RGB(255,255,255)

ACTIVATE DIALOG oAlert NOMODAL
oAlert:close()

RETURN Nil
**************************
STATIC FUNCTION VISUALIZAR
**************************
PARA nAcao
LOCAL nInicio, nFim, nStep, nLoop1
nInicio := IIF(nAcao = 1, 10,255)
nFim    := IIF(nAcao = 1, 255,0)
nStep   := IIF(nAcao = 1, 10,-10)
FOR nloop1 = nInicio TO nFim STEP nStep
    MilliSec(50)
    SetLayeredWindowAttributes(oAlert:handle, nloop1) //0,nloop1, 2)
NEXT
RETURN Nil

************************
STATIC FUNCTION MENSAGEM
************************
PARA cmensagem, nTEMPO
oAlert:show() //thisform.Visible=.t.
SetLayeredWindowAttributes(oAlert:handle, 10) //0, 10, 2)

@ 5,30 SAY oEdtMensagem CAPTION cmensagem SIZE oalert:nwidth,oalert:nheight;
      BACKCOLOR Rgb(255, 255, 255);
      FONT HFont():Add( 'Verdana',0,-13,400,,,)  ;
      COLOR RGB(32,32,32)    ;
      STYLE ES_CENTER
  visualizar(1)
  MilliSec(nTEMPO)
  visualizar(0)
  SetLayeredWindowAttributes(oAlert:handle, 0) //, 0, 2)
  oAlert:hide()
RETURN NIL

STATIC FUNCTION FormInit
private oldstyle,newstyle
oAlert:hide()
oldstyle = HWG_GetWindowexSTYLE(oAlert:hANDLE)
NEWSTYLE = Hwg_BitOR( OLDstyle,WS_EX_LAYERED+WS_EX_TRANSPARENT)
HWG_SETWINDOWEXSTYLE(oAlert:hANDLE, NEWstyle)
moveWINDOW(oalert:handle,,)
SetLayeredWindowAttributes(oAlert:handle, 0) //, 0, 2)
SETTOPMOST(oAlert:Handle)
RETURN NIL

STATIC Function SetLayeredWindowAttributes
parameters hwnd,ntransp
Private nResult
nResult := DllCall("user32.dll" ,  DC_CALL_STD , "SetLayeredWindowAttributes" , hwnd,0 , ntransp,LWA_ALPHA )
RETURN NIL

#pragma begindump
#include "windows.h"
//#ifdef __BORLANDC__
#if defined( __XCC__ ) || defined(  __BORLANDC__ )
 #include "winable.h"  // tem que revisar para poder compilar com MSVC
#endif
#include "hbapi.h"

HB_FUNC( TRAVATEC )
{
   BlockInput( hb_parl(1) );
}
#pragma enddump

function EXECUTA_SQL(;
  cQuery  ,;   // Query
  cPathDbf,;   // Caminho  se PathDbf não for nil Armazena o retorno em DBF
  cAlias  ,;   // Apelido
  aVetor  ,;   // Vetor    set PathDbf for nil Retorno em Vetor
  lErro    )   // Mostra Erro caso ocorra

  local oSql
  local nErr:=.f.
  if lErro=Nil
     lErro=.t.
  endif

  oSql  := SR_GetConnection()                                   // Obtem o objeto da conexão ativa

  if cPATHDBF= nil
    if aVetor= nil;  aVetor:={};  endif

    nErr:= oSql:exec(cQuery,lErro,.t.,@aVetor,,,,.t.)          // Executa a query no banco e armazena em VETOR
  else

    nErr:= oSql:exec(cQuery,lErro,.t.,,(cPathDBF),cAlias,,.t.) // Executa a query no banco e armazena em DBF
  endif
return(nErr== 0)

******************************
FUNCTION AJUSTA_CONEXAO_SQLRDD
******************************
#ifdef __COMPILER_MSVC2010__
   return(.t.)
#else
   OVERRIDE METHOD CONNECTRAW IN CLASS SR_PGS WITH SYG_CONNECTRAW
#endif
//OVERRIDE METHOD CONNECTRAW IN CLASS SR_PGS WITH SYG_CONNECTRAW
//ESSE COMANDO ACIMA FAZ COM QUE A FUNÇÃO: MYCONNECTRAW() SUBISTITUA A FUNÇÃO: CONNECTRAW DENTRO DA CLASSE SR_PGS(SQLRDD)
RETURN NIL


STATIC FUNCTION SYG_CONNECTRAW( cDSN, cUser, cPassword, nVersion, cOwner, nSizeMaxBuff, lTrace,;
            cConnect, nPrefetch, cTargetDB, nSelMeth, nEmptyMode, nDateMode, lCounter, lAutoCommit )
/*
ESSA FUNÇÃO É USADA PARA FAZER A CONEXÃO COM O BANCO DE DADOS NO POSTGRESQL COM O SQLRDD
*/
   local hEnv := 0, hDbc := 0
   local nret, cVersion := "", cSystemVers := "", cBuff := ""
   Local aRet := {}
   LOCAl Self := HB_QSelf()

   (cDSN)
   (cUser)
   (cPassword)
   (nVersion)
   (cOwner)
   (nSizeMaxBuff)
   (lTrace)
   (nPrefetch)
   (nSelMeth)
   (nEmptyMode)
   (nDateMode)
   (lCounter)
   (lAutoCommit)

   //DEFAULT ::cPort := 5432
   IF EMPTY(::cPort)
      ::cPort := 5432
   ENDIF
   cConnect := "host=" + ::cHost + " user=" + ::cUser + " password=" + ::cPassword + " dbname=" + ::cDTB + " port=" + str(::cPort,6)

*   IF !Empty( ::sslcert )
*      cConnect += " sslmode=prefer sslcert="+::sslcert +" sslkey="+::sslkey +" sslrootcert="+ ::sslrootcert +" sslcrl="+ ::sslcrl
*   ENDIF

   hDbc := PGSConnect( cConnect )
   nRet := PGSStatus( hDbc )

   if nRet != SQL_SUCCESS .and. nRet != SQL_SUCCESS_WITH_INFO
      ::nRetCode = nRet
      SR_MsgLogFile( "Connection Error: " + alltrim(str(PGSStatus2( hDbc ))) + " (see pgs.ch)" )
      Return Self
   else
      ::cConnect = cConnect
      ::hStmt    = NIL
      ::hDbc     = hDbc
      cTargetDB  = "PostgreSQL Native"
      ::exec( "select version()",.t.,.t.,@aRet )
      If len (aRet) > 0
         cSystemVers := aRet[1,1]
      Else
         cSystemVers= "??"
      EndIf
   EndIf

   ::cSystemName := cTargetDB
   ::cSystemVers := cSystemVers
   ::nSystemID   := SYSTEMID_POSTGR
   ::cTargetDB   := Upper( cTargetDB )

   // na linha abaixo acresenta as versões suportadas pelo SQLRDD
   If ! ("7.3" $ cSystemVers .or. "7.4" $ cSystemVers .or. "8.0" $ cSystemVers .or. "8.1" $ cSystemVers .or. "8.2" $ cSystemVers .or. "8.3" $ cSystemVers .or. "8.4" $ cSystemVers .or. "9.0" $ cSystemVers .or. "9.1" $ cSystemVers .or. "9.2" $ cSystemVers)
      ::End()
      ::nRetCode  := SQL_ERROR
      ::nSystemID := NIL
      SR_MsgLogFile( "Unsupported Postgres version: " + cSystemVers )
   EndIf

   ::exec( "select pg_backend_pid()", .T., .T., @aRet )

   If len( aRet ) > 0
      ::uSid := val(str(aRet[1,1],8,0))
   EndIf

return Self

function IMPRIME_DANF
return(.t.)
