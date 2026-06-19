      *----------------------------------------------------------------*
      * COPYBOOK: DBCOMM.CPY                                           *
      * DESCRICAO: AREA DE COMUNICACAO ENTRE COBOL E CAMADA C/DB      *
      *----------------------------------------------------------------*
       01 WS-DB-AREA.
          05 WS-DB-SQLCODE    PIC S9(04) COMP.
          05 WS-DB-MSG        PIC X(100).
          05 WS-DB-ROWS       PIC 9(05).

       01 WS-CLIENTE-DB.
          05 WS-DB-CLI-ID     PIC 9(05).
          05 WS-DB-CLI-NOME   PIC X(30).
          05 WS-DB-CLI-SALDO  PIC 9(09).

       01 WS-TRANSACAO-DB.
          05 WS-DB-TRX-ID     PIC 9(05).
          05 WS-DB-TRX-CLI    PIC 9(05).
          05 WS-DB-TRX-TIPO   PIC X(01).
          05 WS-DB-TRX-VALOR  PIC 9(09).
