;=============================================================================
; Include:         mysql.pbi
;
; Author:          HeX0R / infratec
; Date:            March 13, 2015
; Version:         1.0.4
; Target Compiler: PureBasic 5.11+
; Target OS:       Windows / Linux / [MacOS]
;
;
; default PB-Database procedures you can use:
;
; AffectedDatabaseRows
; CheckDatabaseNull
; CloseDatabase
; DatabaseColumnIndex
; DatabaseColumnName
; DatabaseColumns
; DatabaseColumnSize
; DatabaseColumnType
; DatabaseID
; DatabaseQuery
; DatabaseUpdate
; FinishDatabaseQuery
; GetDatabaseDouble
; GetDatabaseFloat
; GetDatabaseLong
; GetDatabaseQuad
; GetDatabaseString
; IsDatabase
; NextDatabaseRow
; OpenDatabase         <- See help of postgresql, this uses the same structure
;
; When you are interested in an error message,
; use MySQL_GetError(#DataBase) instead of DatabaseError()
;
;
; Remarks
;
; Regarding threadsafety:
; I am using only one unsecured linked list which stores the Databases.
; This means you have to take care on your own, when sending querys from
; different threads.
; Adding the compilers threadsafe-option won't help you much here.
;
; Blobs:
; I wasn't in need of blobs, thats why it isn't [yet?!] implemented.
;
; Unicode:
; I would recommend to compile your apps in unicode mode.
; There are quite some characters in UTF-8, which Ascii can not handle.
;
; ----------------------------------------------------------------------------
; "THE BEER-WARE LICENSE":
; <hex0r@coderbu.de> wrote this file. as long as you retain this notice you
; can do whatever you want with this stuff. If we meet some day, and you think
; this stuff is worth it, you can buy me a beer in return
; (see address on http://hex0rs.coderbu.de).
; Or just go out and drink a few on your own/with your friends ;)
;=============================================================================


#PB_Database_MySQL             = $10   ;<- used for OpenDatabase as plugin.

#MySQL_CLIENT_COMPRESS         = 32    ;<- client_flag for compress
#MySQL_CLIENT_MULTI_STATEMENTS = 65536

;-Init some Structures
Structure _MYSQL_HELPER_ ;used to iterate through the fields
   StructureUnion
      row.i[0]
      CompilerIf #PB_Compiler_OS = #PB_OS_Windows
         len.l[0]
      CompilerElse
         len.i[0]
      CompilerEndIf
   EndStructureUnion
EndStructure

Structure _MYSQL_DBs_
   DataBaseNum.i            ;<- the PB-Identifier (#DataBase)
   DataBaseID.i             ;<- the API-Handle
   *mysqlResult             ;<- stores the result of a query
   *mysqlRow._MYSQL_HELPER_ ;<- stores the fields of one row
   *mysqlLen._MYSQL_HELPER_ ;<- stores the length of each field
   FieldCount.i             ;<- stores the fields which have been returned after a query
EndStructure


Structure _MYSQL_FIELD_
   *name                       ; Name of column
   *org_name                   ; Original column name, if an alias
   *table                      ; Table of column if column was a field
   *org_table                  ; Org table name, if table was an alias
   *db                         ; Database for table
   *catalog                    ; Catalog for table
   *def                        ; Default value (set by mysql_list_fields)
   length.l                    ; Width of column (create length)
   max_length.l                ; Max width for selected set
   name_length.i               ;
   org_name_length.i           ;
   table_length.i              ;
   org_table_length.i          ;
   db_length.i                 ;
   catalog_length.i            ;
   def_length.i                ;
   flags.i                     ; Div flags
   decimals.i                  ; Number of decimals in field
   charsetnr.i                 ; Character set
   type.i                      ; Type of field. See mysql_com.h for types
   *extension                  ;
EndStructure


;-Init some Prototypes
; There are more defined as needed.
; This is just for future reference
CompilerSelect #PB_Compiler_OS
   CompilerCase #PB_OS_Windows
      Prototype.i MySQL_Init(dbHwnd)
      Prototype.i MySQL_ERRNO(dbHwnd)
      Prototype.i MySQL_ERROR(dbHwnd)
      Prototype.i MySQL_Real_Connect(dbHwnd, host.p-utf8, user.p-utf8, password.p-utf8, DataBase.p-utf8, Port, *unix_socket, client_flag)
      Prototype.i MySQL_Real_Query(dbHwnd, Query.p-utf8, Length)
      Prototype.i MySQL_Real_Escape_String(dbHwnd, *to, from.p-utf8, Length)
      Prototype.i MySQL_Set_Character_Set(dbHwnd, csname.p-utf8)
      Prototype.i MySQL_Store_Result(dbHwnd)
      Prototype.i MySQL_Field_Count(dbHwnd)
      Prototype.i MySQL_Use_Result(dbHwnd)
      Prototype.i MySQL_Affected_Rows(dbHwnd)
      Prototype.i MySQL_Fetch_Row(*result)
      Prototype.i MySQL_Fetch_Lengths(*result)
      Prototype.i MySQL_Free_Result(*result)
      Prototype.i MySQL_Fetch_Fields(*result)
      Prototype.i MySQL_Num_Fields(*result)
      Prototype.i MySQL_Close(dbHwnd)
      Prototype.i MySQL_Fetch_Field_Direct(*result, fieldnr.i)
      Prototype.i MySQL_Data_Seek(*result, offset.q)
   CompilerCase #PB_OS_Linux
      PrototypeC.i MySQL_Init(dbHwnd)
      PrototypeC.i MySQL_ERRNO(dbHwnd)
      PrototypeC.i MySQL_ERROR(dbHwnd)
      PrototypeC.i MySQL_Real_Connect(dbHwnd, host.p-utf8, user.p-utf8, password.p-utf8, DataBase.p-utf8, Port, *unix_socket, client_flag)
      PrototypeC.i MySQL_Real_Query(dbHwnd, Query.p-utf8, Length)
      PrototypeC.i MySQL_Real_Escape_String(dbHwnd, *to, from.p-utf8, Length)
      PrototypeC.i MySQL_Set_Character_Set(dbHwnd, csname.p-utf8)
      PrototypeC.i MySQL_Store_Result(dbHwnd)
      PrototypeC.i MySQL_Field_Count(dbHwnd)
      PrototypeC.i MySQL_Use_Result(dbHwnd)
      PrototypeC.i MySQL_Affected_Rows(dbHwnd)
      PrototypeC.i MySQL_Fetch_Row(*result)
      PrototypeC.i MySQL_Fetch_Lengths(*result)
      PrototypeC.i MySQL_Free_Result(*result)
      PrototypeC.i MySQL_Fetch_Fields(*result)
      PrototypeC.i MySQL_Num_Fields(*result)
      PrototypeC.i MySQL_Close(dbHwnd)
      PrototypeC.i MySQL_Fetch_Field_Direct(*result, fieldnr.i)
      PrototypeC.i MySQL_Data_Seek(*result, offset.q)
   CompilerCase #PB_OS_MacOS
      ;???
      
CompilerEndSelect

;-Init some Globals
Global MySQL_Init              .MySQL_Init
Global MySQL_ERRNO             .MySQL_ERRNO
Global MySQL_ERROR             .MySQL_ERROR
Global MySQL_Real_Connect      .MySQL_Real_Connect
Global MySQL_Real_Query        .MySQL_Real_Query
Global MySQL_Real_Escape_String.MySQL_Real_Escape_String
Global MySQL_Store_Result      .MySQL_Store_Result
Global MySQL_Field_Count       .MySQL_Field_Count
Global MySQL_Use_Result        .MySQL_Use_Result
Global MySQL_Fetch_Row         .MySQL_Fetch_Row
Global MySQL_Fetch_Lengths     .MySQL_Fetch_Lengths
Global MySQL_Free_Result       .MySQL_Free_Result
Global MySQL_Affected_Rows     .MySQL_Affected_Rows
Global MySQL_Close             .MySQL_Close
Global MySQL_Num_Fields        .MySQL_Num_Fields
Global MySQL_Set_Character_Set .MySQL_Set_Character_Set
Global MySQL_Fetch_Fields      .MySQL_Fetch_Fields
Global MySQL_Fetch_Field_Direct.MySQL_Fetch_Field_Direct
Global MySQL_Data_Seek         .MySQL_Data_Seek
Global MySQL_Lib
Global NewList MySQL_DBs._MYSQL_DBs_() ;<- will store the Database IDs and result values.
;                                            a map would be more efficient i guess, but who really opens more then 2 or 3 databases?

Global MySQL_LastErrorFlag.i


; You need to call UseMySQLDataBase() first!
; Instead of UseSQLiteDatabase() and UsePostgreSQLDatabase()
; you should check the return value!
Procedure UseMySQLDataBase(Path_To_MySQL_Lib.s = "")
   
   CompilerSelect #PB_Compiler_OS
      CompilerCase #PB_OS_Windows
         If Path_To_MySQL_Lib = ""
            Path_To_MySQL_Lib = "libmysql.dll"
         EndIf
         MySQL_Lib = OpenLibrary(#PB_Any, Path_To_MySQL_Lib)
      CompilerCase #PB_OS_Linux
         If Path_To_MySQL_Lib = ""
            Path_To_MySQL_Lib = "libmysqlclient.so.18"
         EndIf
         MySQL_Lib = OpenLibrary(#PB_Any, Path_To_MySQL_Lib)
         If MySQL_Lib = 0
            MySQL_Lib = OpenLibrary(#PB_Any, "libmysqlclient.so.16")
         EndIf
      CompilerCase #PB_OS_MacOS
         ;???
   CompilerEndSelect
   
   If MySQL_Lib
      MySQL_Init               = GetFunction(MySQL_Lib, "mysql_init")
      MySQL_ERRNO              = GetFunction(MySQL_Lib, "mysql_errno")
      MySQL_ERROR              = GetFunction(MySQL_Lib, "mysql_error")
      MySQL_Real_Connect       = GetFunction(MySQL_Lib, "mysql_real_connect")
      MySQL_Real_Query         = GetFunction(MySQL_Lib, "mysql_real_query")
      MySQL_Real_Escape_String = GetFunction(MySQL_Lib, "mysql_real_escape_string")
      MySQL_Store_Result       = GetFunction(MySQL_Lib, "mysql_store_result")
      MySQL_Field_Count        = GetFunction(MySQL_Lib, "mysql_field_count")
      MySQL_Use_Result         = GetFunction(MySQL_Lib, "mysql_use_result")
      MySQL_Fetch_Row          = GetFunction(MySQL_Lib, "mysql_fetch_row")
      MySQL_Fetch_Lengths      = GetFunction(MySQL_Lib, "mysql_fetch_lengths")
      MySQL_Free_Result        = GetFunction(MySQL_Lib, "mysql_free_result")
      MySQL_Num_Fields         = GetFunction(MySQL_Lib, "mysql_num_fields")
      MySQL_Affected_Rows      = GetFunction(MySQL_Lib, "mysql_affected_rows")
      MySQL_Close              = GetFunction(MySQL_Lib, "mysql_close")
      MySQL_Set_Character_Set  = GetFunction(MySQL_Lib, "mysql_set_character_set")
      MySQL_Fetch_Field_Direct = GetFunction(MySQL_Lib, "mysql_fetch_field_direct")
      MySQL_Data_Seek          = GetFunction(MySQL_Lib, "mysql_data_seek")
   EndIf
   
   ProcedureReturn MySQL_Lib
EndProcedure

; Internal function to check, if this database is a mysql database
Procedure MySQL_FindDataBase(DataBase)
   Protected Found = #False
   
   ForEach MySQL_DBs()
      If MySQL_DBs()\DataBaseNum = DataBase
         Found = #True
         Break
      EndIf
   Next
   
   ProcedureReturn Found
EndProcedure

; Open database
; uses same structure as the #PB_Database_PostgreSQL-Plugin (but no hostaddr is used).
Procedure MySQL_OpenDatabase(DataBase, Name$, User$, Password$, Plugin)
   Protected i, a$, ParameterName.s, ParameterValue.s, host.s, hostaddr.i, port.i, dbname.s, handle, flags.i
   
   If Plugin <> #PB_Database_MySQL
      ;o.k. nothing for us, so let PB handle it.
      ProcedureReturn OpenDatabase(DataBase, Name$, User$, Password$, Plugin)
   EndIf
   If MySQL_Init = 0
      ;user forgot to call UseMySQLDataBase() (or the library isn't available)
      ProcedureReturn 0
   EndIf
   If DataBase <> #PB_Any
      ;we check, if there is already a database with this ID open
      If MySQL_FindDataBase(DataBase)
         ;yes, so we will close it.
         ;first check, if there is a query open.
         If MySQL_DBs()\mysqlResult
            MySQL_Free_Result(MySQL_DBs()\mysqlResult)
            MySQL_DBs()\FieldCount  = 0
            MySQL_DBs()\mysqlLen    = 0
            MySQL_DBs()\mysqlRow    = 0
            MySQL_DBs()\mysqlResult = 0
         EndIf
         MySQL_Close(MySQL_DBs()\DataBaseID)
         ;now delete it
         DeleteElement(MySQL_DBs())
      EndIf
   EndIf
   ;Check the parameters
   For i = 0 To CountString(Name$, " ")
      a$ = Trim(StringField(Name$, i + 1, " "))
      If a$
         ParameterName  = LCase(Trim(StringField(a$, 1, "=")))
         ParameterValue = Trim(StringField(a$, 2, "="))
         Select ParameterName
            Case "host"
               Host = ParameterValue
            Case "hostaddr"
               hostaddr = Val(ParameterValue)
            Case "port"
               port = Val(ParameterValue)
            Case "dbname"
               dbname = ParameterValue
            Case "flags"
               flags = Val(ParameterValue)
         EndSelect
      EndIf
   Next i
   If dbname = ""
      dbname = User$
   EndIf
   If host = ""
      host = "localhost"
   EndIf
   handle = MySQL_Init(#Null)
   If handle
      If MySQL_Real_Connect(handle, host, User$, Password$, dbname, port, #Null, flags) = 0
         ;something went wrong...
         handle = #Null
      Else
         ;yessss... now add this client, to be sure we will mark it as a mysql client
         AddElement(MySQL_DBs())
         MySQL_DBs()\DataBaseID = handle
         If DataBase = #PB_Any
            MySQL_DBs()\DataBaseNum = @MySQL_DBs()
            handle                  = @MySQL_DBs()
         Else
            MySQL_DBs()\DataBaseNum = DataBase
         EndIf
         ;now set the client charset to utf8
         MySQL_Set_Character_Set(MySQL_DBs()\DataBaseID, "utf8")
      EndIf
   EndIf
   
   ProcedureReturn handle
EndProcedure

Procedure MySQL_CloseDatabase(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn CloseDatabase(DataBase)
   EndIf
   ;check if there is a query open.
   If MySQL_DBs()\mysqlResult
      MySQL_Free_Result(MySQL_DBs()\mysqlResult)
   EndIf
   MySQL_Close(MySQL_DBs()\DataBaseID)
   DeleteElement(MySQL_DBs())
EndProcedure

Procedure MySQL_DatabaseQuery(DataBase, Query.s, Flags = 0)
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn DatabaseQuery(DataBase, Query, Flags)
   EndIf
   MySQL_LastErrorFlag = #True
   With MySQL_DBs()
      If \mysqlResult
         ;hmm user forgot to finish his databasequery. o.k. we will do it for him.
         MySQL_Free_Result(\mysqlResult)
         \FieldCount  = 0
         \mysqlLen    = 0
         \mysqlRow    = 0
         \mysqlResult = 0
      EndIf
      If MySQL_Real_Query(\DataBaseID, Query, StringByteLength(Query, #PB_UTF8)) = 0
         ;yes, strange but true... in this case a result of 0 means success.
         \mysqlResult = MySQL_Use_Result(\DataBaseID)
         ; for FirstDatabaseRow() we need store not use
         ;\mysqlResult = MySQL_Store_Result(\DataBaseID)
      EndIf
   EndWith
   
   ProcedureReturn MySQL_DBs()\mysqlResult
EndProcedure

Procedure MySQL_NextDatabaseRow(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn NextDatabaseRow(DataBase)
   EndIf
   MySQL_LastErrorFlag = #True
   With MySQL_DBs()
      If \mysqlResult
         \mysqlRow = MySQL_Fetch_Row(\mysqlResult)
         If \mysqlRow
            \mysqlLen   = MySQL_Fetch_Lengths(\mysqlResult)
            \FieldCount = MySQL_Num_Fields(\mysqlResult)
         EndIf
      EndIf
   EndWith
   
   ProcedureReturn MySQL_DBs()\mysqlRow
EndProcedure

Procedure MySQL_DatabaseUpdate(DataBase, Query.s)
   Protected Result
   
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn DatabaseUpdate(DataBase, Query)
   EndIf
   MySQL_LastErrorFlag = #True
   If MySQL_Real_Query(MySQL_DBs()\DataBaseID, Query, StringByteLength(Query, #PB_UTF8)) = 0
      ;yes, strange but true... in this case a result of 0 means success.
      Result = #True
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_FinishDatabaseQuery(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn FinishDatabaseQuery(DataBase)
   EndIf
   MySQL_LastErrorFlag = #True
   With MySQL_DBs()
      If \mysqlResult
         MySQL_Free_Result(\mysqlResult)
         \FieldCount  = 0
         \mysqlLen    = 0
         \mysqlRow    = 0
         \mysqlResult = 0
      EndIf
   EndWith
EndProcedure

Procedure.s MySQL_GetDatabaseString(DataBase, Column)
   Protected Result.s
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn GetDatabaseString(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If Column < MySQL_DBs()\FieldCount And MySQL_DBs()\mysqlLen\len[Column] > 0
         Result = PeekS(MySQL_DBs()\mysqlRow\row[Column], MySQL_DBs()\mysqlLen\len[Column], #PB_UTF8)
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure.d MySQL_GetDatabaseDouble(DataBase, Column)
   Protected Result.d
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn GetDatabaseDouble(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If Column < MySQL_DBs()\FieldCount
         Result = ValD(PeekS(MySQL_DBs()\mysqlRow\row[Column], MySQL_DBs()\mysqlLen\len[Column], #PB_UTF8))
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure.f MySQL_GetDatabaseFloat(DataBase, Column)
   Protected Result.f
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn GetDatabaseFloat(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If Column < MySQL_DBs()\FieldCount
         Result = ValF(PeekS(MySQL_DBs()\mysqlRow\row[Column], MySQL_DBs()\mysqlLen\len[Column], #PB_UTF8))
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_GetDatabaseLong(DataBase, Column)
   Protected Result
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn GetDatabaseLong(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If Column < MySQL_DBs()\FieldCount
         Result = Val(PeekS(MySQL_DBs()\mysqlRow\row[Column], MySQL_DBs()\mysqlLen\len[Column], #PB_UTF8))
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure.q MySQL_GetDatabaseQuad(DataBase, Column)
   Protected Result.q
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn GetDatabaseQuad(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If Column < MySQL_DBs()\FieldCount
         Result = Val(PeekS(MySQL_DBs()\mysqlRow\row[Column], MySQL_DBs()\mysqlLen\len[Column], #PB_UTF8))
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_AffectedDatabaseRows(DataBase)
   
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn AffectedDatabaseRows(DataBase)
   EndIf
   MySQL_LastErrorFlag = #True
   
   ProcedureReturn MySQL_Affected_Rows(MySQL_DBs()\DataBaseID)
EndProcedure

Procedure MySQL_CheckDatabaseNull(DataBase, Column)
   Protected Result
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn CheckDatabaseNull(DataBase, Column)
   EndIf
   If MySQL_DBs()\mysqlResult
      If MySQL_DBs()\mysqlLen = 0 Or MySQL_DBs()\mysqlLen\len[Column] = 0
         Result = #True
      EndIf
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_DatabaseID(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseID(DataBase)
   EndIf
   
   ProcedureReturn MySQL_DBs()\DataBaseID
EndProcedure

Procedure MySQL_IsDatabase(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn IsDatabase(DataBase)
   EndIf
   
   ProcedureReturn #True
EndProcedure

; use this procedure to add escape characters, when putting strings in querys
Procedure.s MySQL_EscapeString(DataBase, String.s)
   Protected Text$, *Buffer, Length
   
   If MySQL_FindDataBase(DataBase)
      *Buffer = AllocateMemory(StringByteLength(String, #PB_UTF8) * 2 + 1)
      If *Buffer
         Length = MySQL_Real_Escape_String(MySQL_DBs()\DataBaseID, *Buffer, String, StringByteLength(String, #PB_UTF8))
         Text$  = PeekS(*Buffer, Length, #PB_UTF8)
         FreeMemory(*Buffer)
      EndIf
   EndIf
   
   ProcedureReturn Text$
EndProcedure

Procedure.s MySQL_GetError()
   Protected Errormsg.s, i, *Error
   
   If MySQL_LastErrorFlag = #False; Or MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseError()
   EndIf
   
   If MySQL_ERRNO(MySQL_DBs()\DataBaseID) > 0
      *Error   = MySQL_ERROR(MySQL_DBs()\DataBaseID)
      Errormsg = PeekS(*Error, -1, #PB_UTF8)
   EndIf
   
   ProcedureReturn Errormsg
EndProcedure

Procedure MySQL_DatabaseColumns(DataBase)
   Protected Result
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseColumns(DataBase)
   EndIf
   Result = MySQL_Field_Count(MySQL_DBs()\DataBaseID)
   
   ProcedureReturn Result
EndProcedure

Procedure.s MySQL_DatabaseColumnName(DataBase, Column)
   Protected *Result._MYSQL_FIELD_
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseColumnName(DataBase, Column)
   EndIf
   *Result = MySQL_Fetch_Field_Direct(MySQL_DBs()\mysqlResult, Column)
   If *Result
      ProcedureReturn PeekS(*Result\name, -1, #PB_UTF8)
   EndIf
   
   ProcedureReturn ""
EndProcedure

Procedure MySQL_DatabaseColumnSize(DataBase, Column)
   Protected *Result._MYSQL_FIELD_
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseColumnSize(DataBase, Column)
   EndIf
   *Result = MySQL_Fetch_Field_Direct(MySQL_DBs()\mysqlResult, Column)
   If *Result
      ProcedureReturn *Result\db_length
   EndIf
   
   ProcedureReturn 0
EndProcedure

Procedure MySQL_DatabaseColumnType(DataBase, Column)
   Protected *Result._MYSQL_FIELD_, Result
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseColumnType(DataBase, Column)
   EndIf
   *Result = MySQL_Fetch_Field_Direct(MySQL_DBs()\mysqlResult, Column)
   If *Result
      Select *Result\type
         Case 1, 2, 3
            Result = #PB_Database_Long
         Case 4
            Result = #PB_Database_Float
         Case 12
            Result = #PB_Database_Quad
         Case 253
            Result = #PB_Database_String
      EndSelect
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_DatabaseColumnIndex(DataBase, Columnname.s)
   Protected *Result._MYSQL_FIELD_, Result, Count
   
   If MySQL_FindDataBase(DataBase) = 0
      ProcedureReturn DatabaseColumnIndex(DataBase, Columnname)
   EndIf
   Count = MySQL_DatabaseColumns(DataBase) - 1
   For Result = 0 To Count
      *Result = MySQL_Fetch_Field_Direct(MySQL_DBs()\mysqlResult, Result)
      If *Result
         If LCase(PeekS(*Result\name, -1, #PB_UTF8)) = LCase(Columnname)
            Break
         EndIf
      Else
         Result = -1
         Break
      EndIf
   Next Result
   If Result > Count
      Result = -1
   EndIf
   
   ProcedureReturn Result
EndProcedure

Procedure MySQL_FirstDatabaseRow(DataBase)
   If MySQL_FindDataBase(DataBase) = 0
      MySQL_LastErrorFlag = #False
      ProcedureReturn FirstDatabaseRow(DataBase)
   EndIf
   MySQL_LastErrorFlag = #True
   With MySQL_DBs()
      If \mysqlResult
         MySQL_Data_Seek(\mysqlResult, 0)
         \mysqlRow = MySQL_Fetch_Row(\mysqlResult)
         If \mysqlRow
            \mysqlLen   = MySQL_Fetch_Lengths(\mysqlResult)
            \FieldCount = MySQL_Num_Fields(\mysqlResult)
         EndIf
      EndIf
   EndWith
   
   ProcedureReturn MySQL_DBs()\mysqlRow
EndProcedure

; some macros to overright the PB procedures
Macro AffectedDatabaseRows(a)
   MySQL_AffectedDataBaseRows(a)
EndMacro

Macro CheckDatabaseNull(a, b)
   MySQL_CheckDatabaseNull(a, b)
EndMacro

Macro CloseDatabase(a)
   MySQL_CloseDatabase(a)
EndMacro

Macro DatabaseError()
   MySQL_GetError()
EndMacro

Macro DatabaseID(a)
   MySQL_DatabaseID(a)
EndMacro

Macro DatabaseQuery(a, b, c = 0)
   MySQL_DatabaseQuery(a, b, c)
EndMacro

Macro DatabaseUpdate(a, b)
   MySQL_DatabaseUpdate(a, b)
EndMacro

Macro FinishDatabaseQuery(a)
   MySQL_FinishDatabaseQuery(a)
EndMacro

Macro GetDatabaseDouble(a, b)
   MySQL_GetDatabaseDouble(a, b)
EndMacro

Macro GetDatabaseFloat(a, b)
   MySQL_GetDatabaseFloat(a, b)
EndMacro

Macro GetDatabaseLong(a, b)
   MySQL_GetDatabaseLong(a, b)
EndMacro

Macro GetDatabaseQuad(a, b)
   MySQL_GetDatabaseQuad(a, b)
EndMacro

Macro GetDatabaseString(a, b)
   MySQL_GetDatabaseString(a, b)
EndMacro

Macro IsDatabase(a)
   MySQL_IsDatabase(a)
EndMacro

Macro NextDatabaseRow(a)
   MySQL_NextDatabaseRow(a)
EndMacro

Macro OpenDatabase(a, b, c, d, e = 0)
   MySQL_OpenDatabase(a, b, c, d, e)
EndMacro

; more Macros, which i wasn't in need of
; if you need them, feel free to implement them on your own..

Macro DatabaseColumnIndex(a, b)
   MySQL_DatabaseColumnIndex(a, b)
EndMacro
;
Macro DatabaseColumnName(a, b)
   MySQL_DatabaseColumnName(a, b)
EndMacro

Macro DatabaseColumnSize(a, b)
   MySQL_DatabaseColumnSize(a, b)
EndMacro

Macro DatabaseColumnType(a, b)
   MySQL_DatabaseColumnType(a, b)
EndMacro
;
Macro DatabaseColumns(a)
   MySQL_DatabaseColumns(a)
EndMacro

; implemented, but slows a bit down and PreviousDatabaseRow() is not easy possible.
;Macro FirstDatabaseRow(a)
;   MySQL_FirstDatabaseRow(a)
;EndMacro
;
; Macro GetDatabaseBlob(a, b, c, d)
;    MySQL_GetDatabaseBlob(a, b, c, d)
; EndMacro
;
;Macro PreviousDatabaseRow(a)
;   MySQL_PreviousDatabaseRow(a)
;EndMacro
;
; Macro SetDatabaseBlob(a, b, c, d)
;    MySQL_SetDatabaseBlob(a, b, c, d)
; EndMacro
; IDE Options = PureBasic 5.40 LTS (Windows - x86)
; CursorPosition = 778
; FirstLine = 733
; Folding = --------------------
; EnableXP