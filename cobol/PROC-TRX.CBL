      *----------------------------------------------------------------*
      * PROGRAMA: PROC-TRX.CBL                                         *
      * DESCRICAO: PROCESSAMENTO DO ARQUIVO DE TRANSACOES              *
      *            LE TRANSACOES.TXT, VALIDA E ATUALIZA SALDO NO DB2   *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROC-TRX.
       AUTHOR. GABRIEL SOARES REIS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQUIVO-TRANSACOES ASSIGN TO 'input_sorted/TRANSACOES.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ARQUIVO-LOG        ASSIGN TO 'output/LOG-TRX.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ARQUIVO-ERROS      ASSIGN TO 'output/ERROS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ARQUIVO-RELATORIO  ASSIGN TO 'output/RELATORIO.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.

       FD ARQUIVO-TRANSACOES.
       01 FS-TRANSACAO            PIC X(20).

       FD ARQUIVO-LOG.
       01 FS-LOG                  PIC X(120).

       FD ARQUIVO-ERROS.
       01 FS-ERRO                 PIC X(120).

       FD ARQUIVO-RELATORIO.
       01 FS-RELATORIO            PIC X(120).

       WORKING-STORAGE SECTION.

       COPY 'copybooks/TRANSACAO.CPY'.
       COPY 'copybooks/DBCOMM.CPY'.

       01 WS-FLAGS.
          05 WS-FIM-TRANSACOES    PIC X(01) VALUE 'N'.

       01 WS-CONTADORES.
          05 WS-LIDOS             PIC 9(05) VALUE 0.
          05 WS-PROCESSADOS       PIC 9(05) VALUE 0.
          05 WS-ERROS             PIC 9(05) VALUE 0.
          05 WS-CREDITOS          PIC 9(05) VALUE 0.
          05 WS-DEBITOS           PIC 9(05) VALUE 0.
          05 WS-CTR-COMMIT        PIC 9(03) VALUE 0.

       01 WS-NOVO-SALDO           PIC 9(09) VALUE 0.
       01 WS-LINHA-LOG            PIC X(120).
       01 WS-LINHA-ERRO           PIC X(120).
       01 WS-LINHA-REL            PIC X(120).
       01 WS-DESC-ERRO            PIC X(100).

       01 WS-DB-HOST              PIC X(64) VALUE 'localhost'.
       01 WS-DB-USER              PIC X(64) VALUE 'root'.
       01 WS-DB-PASS              PIC X(64) VALUE 'senha'.
       01 WS-DB-NAME              PIC X(64) VALUE 'banco_proj6'.

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
           PERFORM 1000-INICIALIZAR
           PERFORM 2000-PROCESSAR-TRANSACOES
           PERFORM 3000-FINALIZAR
           STOP RUN.

      *----------------------------------------------------------------*
       1000-INICIALIZAR.
           OPEN INPUT  ARQUIVO-TRANSACOES
           OPEN OUTPUT ARQUIVO-LOG
           OPEN EXTEND ARQUIVO-ERROS
           OPEN OUTPUT ARQUIVO-RELATORIO

           CALL 'db_connect' USING WS-DB-AREA
                                   WS-DB-HOST
                                   WS-DB-USER
                                   WS-DB-PASS
                                   WS-DB-NAME
           IF WS-DB-SQLCODE NOT = 0
               STRING 'ERRO CONEXAO BD: ' DELIMITED SIZE
                      WS-DB-MSG           DELIMITED SIZE
                   INTO WS-LINHA-LOG
               WRITE FS-LOG FROM WS-LINHA-LOG
               STOP RUN
           END-IF

           CALL 'db_autocommit_off' USING WS-DB-AREA

           WRITE FS-LOG FROM
               '===================================================='
           WRITE FS-LOG FROM
               '     LOG DE PROCESSAMENTO - TRANSACOES              '
           WRITE FS-LOG FROM
               '===================================================='
           WRITE FS-LOG FROM
               'INICIO PROCESSAMENTO TRANSACOES'

           WRITE FS-RELATORIO FROM
               '===================================================='
           WRITE FS-RELATORIO FROM
               '        RELATORIO DE PROCESSAMENTO - TRANSACOES     '
           WRITE FS-RELATORIO FROM
               '===================================================='
           WRITE FS-RELATORIO FROM
               ' CLIENTE     TIPO   VALOR      STATUS               '
           WRITE FS-RELATORIO FROM
               '----------------------------------------------------'.

      *----------------------------------------------------------------*
       2000-PROCESSAR-TRANSACOES.
           READ ARQUIVO-TRANSACOES INTO FS-TRANSACAO
               AT END MOVE 'S' TO WS-FIM-TRANSACOES
           END-READ

           PERFORM UNTIL WS-FIM-TRANSACOES = 'S'
               ADD 1 TO WS-LIDOS
               PERFORM 2100-TRATAR-REGISTRO
               READ ARQUIVO-TRANSACOES INTO FS-TRANSACAO
                   AT END MOVE 'S' TO WS-FIM-TRANSACOES
               END-READ
           END-PERFORM.

      *----------------------------------------------------------------*
       2100-TRATAR-REGISTRO.
           MOVE FS-TRANSACAO(1:5)  TO WS-TRX-CLI-ID
           MOVE FS-TRANSACAO(6:5)  TO WS-TRX-ID
           MOVE FS-TRANSACAO(11:1) TO WS-TRX-TIPO
           MOVE FS-TRANSACAO(12:9) TO WS-TRX-VALOR

           IF WS-TRX-VALOR = 0
               ADD 1 TO WS-ERROS
               MOVE WS-TRX-CLI-ID TO WS-DB-CLI-ID
               MOVE 'VALOR DA TRANSACAO E ZERO' TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO TRX ' DELIMITED SIZE
                      WS-TRX-ID   DELIMITED SIZE
                      ' - VALOR ZERADO' DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               PERFORM 2200-RELATORIO-ERRO
               GO TO 2100-FIM
           END-IF

           IF WS-TRX-TIPO NOT = 'C' AND WS-TRX-TIPO NOT = 'D'
               ADD 1 TO WS-ERROS
               MOVE WS-TRX-CLI-ID TO WS-DB-CLI-ID
               MOVE 'TIPO DE TRANSACAO INVALIDO' TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO TRX ' DELIMITED SIZE
                      WS-TRX-ID   DELIMITED SIZE
                      ' - TIPO INVALIDO: ' DELIMITED SIZE
                      WS-TRX-TIPO          DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               PERFORM 2200-RELATORIO-ERRO
               GO TO 2100-FIM
           END-IF

           MOVE WS-TRX-CLI-ID TO WS-DB-CLI-ID
           CALL 'db_busca_cliente' USING WS-DB-AREA WS-CLIENTE-DB

           IF WS-DB-SQLCODE = 100
               ADD 1 TO WS-ERROS
               MOVE 'CLIENTE INEXISTENTE' TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO TRX ' DELIMITED SIZE
                      WS-TRX-ID   DELIMITED SIZE
                      ' - CLIENTE NAO ENCONTRADO' DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               PERFORM 2200-RELATORIO-ERRO
               CALL 'db_rollback' USING WS-DB-AREA
               GO TO 2100-FIM
           END-IF

           IF WS-TRX-TIPO = 'D'
               IF WS-DB-CLI-SALDO < WS-TRX-VALOR
                   ADD 1 TO WS-ERROS
                   MOVE 'SALDO INSUFICIENTE PARA DEBITO'
                       TO WS-DESC-ERRO
                   CALL 'db_insert_erro' USING WS-DB-AREA
                                              WS-CLIENTE-DB
                                              WS-DESC-ERRO
                   STRING 'ERRO TRX ' DELIMITED SIZE
                          WS-TRX-ID   DELIMITED SIZE
                          ' - SALDO INSUFICIENTE' DELIMITED SIZE
                       INTO WS-LINHA-ERRO
                   WRITE FS-ERRO FROM WS-LINHA-ERRO
                   PERFORM 2200-RELATORIO-ERRO
                   CALL 'db_rollback' USING WS-DB-AREA
                   GO TO 2100-FIM
               END-IF
               SUBTRACT WS-TRX-VALOR FROM WS-DB-CLI-SALDO
                   GIVING WS-NOVO-SALDO
               ADD 1 TO WS-DEBITOS
           ELSE
               ADD WS-DB-CLI-SALDO WS-TRX-VALOR GIVING WS-NOVO-SALDO
               ADD 1 TO WS-CREDITOS
           END-IF

           MOVE WS-NOVO-SALDO TO WS-DB-CLI-SALDO

           MOVE WS-TRX-ID      TO WS-DB-TRX-ID
           MOVE WS-TRX-CLI-ID  TO WS-DB-TRX-CLI
           MOVE WS-TRX-TIPO    TO WS-DB-TRX-TIPO
           MOVE WS-TRX-VALOR   TO WS-DB-TRX-VALOR

           CALL 'db_insert_transacao' USING WS-DB-AREA WS-TRANSACAO-DB

           IF WS-DB-SQLCODE NOT = 0
               ADD 1 TO WS-ERROS
               MOVE WS-DB-MSG TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO SQL TRX ' DELIMITED SIZE
                      WS-TRX-ID       DELIMITED SIZE
                      ': '            DELIMITED SIZE
                      WS-DB-MSG       DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               CALL 'db_rollback' USING WS-DB-AREA
               GO TO 2100-FIM
           END-IF

           CALL 'db_update_saldo' USING WS-DB-AREA WS-CLIENTE-DB

           IF WS-DB-SQLCODE NOT = 0
               ADD 1 TO WS-ERROS
               MOVE WS-DB-MSG TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               CALL 'db_rollback' USING WS-DB-AREA
               GO TO 2100-FIM
           END-IF

           ADD 1 TO WS-PROCESSADOS
           ADD 1 TO WS-CTR-COMMIT

           STRING 'OK TRX '   DELIMITED SIZE
                  WS-TRX-ID   DELIMITED SIZE
                  ' CLI '     DELIMITED SIZE
                  WS-TRX-CLI-ID DELIMITED SIZE
                  ' TIPO '    DELIMITED SIZE
                  WS-TRX-TIPO DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           PERFORM 2300-RELATORIO-OK

           IF WS-CTR-COMMIT >= 100
               CALL 'db_commit' USING WS-DB-AREA
               MOVE 0 TO WS-CTR-COMMIT
           END-IF.

       2100-FIM.
           CONTINUE.

      *----------------------------------------------------------------*
       2200-RELATORIO-ERRO.
           MOVE SPACES TO WS-LINHA-REL
           STRING WS-TRX-CLI-ID DELIMITED SIZE
                  '     '       DELIMITED SIZE
                  WS-TRX-TIPO   DELIMITED SIZE
                  '      '      DELIMITED SIZE
                  WS-TRX-VALOR  DELIMITED SIZE
                  '   ERRO: '   DELIMITED SIZE
                  WS-DESC-ERRO  DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL.

      *----------------------------------------------------------------*
       2300-RELATORIO-OK.
           MOVE SPACES TO WS-LINHA-REL
           STRING WS-TRX-CLI-ID DELIMITED SIZE
                  '     '       DELIMITED SIZE
                  WS-TRX-TIPO   DELIMITED SIZE
                  '      '      DELIMITED SIZE
                  WS-TRX-VALOR  DELIMITED SIZE
                  '   OK - SALDO NOVO: ' DELIMITED SIZE
                  WS-NOVO-SALDO           DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL.

      *----------------------------------------------------------------*
       3000-FINALIZAR.
           IF WS-CTR-COMMIT > 0
               CALL 'db_commit' USING WS-DB-AREA
           END-IF

           CALL 'db_disconnect' USING WS-DB-AREA

           WRITE FS-RELATORIO FROM
               '===================================================='
           MOVE SPACES TO WS-LINHA-REL
           STRING 'TOTAL LIDOS      : ' DELIMITED SIZE
                  WS-LIDOS              DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL

           MOVE SPACES TO WS-LINHA-REL
           STRING 'TOTAL PROCESSADOS: ' DELIMITED SIZE
                  WS-PROCESSADOS        DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL

           MOVE SPACES TO WS-LINHA-REL
           STRING 'TOTAL CREDITOS   : ' DELIMITED SIZE
                  WS-CREDITOS           DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL

           MOVE SPACES TO WS-LINHA-REL
           STRING 'TOTAL DEBITOS    : ' DELIMITED SIZE
                  WS-DEBITOS            DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL

           MOVE SPACES TO WS-LINHA-REL
           STRING 'TOTAL COM ERRO   : ' DELIMITED SIZE
                  WS-ERROS              DELIMITED SIZE
               INTO WS-LINHA-REL
           WRITE FS-RELATORIO FROM WS-LINHA-REL

           WRITE FS-RELATORIO FROM
               '===================================================='

           CLOSE ARQUIVO-TRANSACOES
           CLOSE ARQUIVO-LOG
           CLOSE ARQUIVO-ERROS
           CLOSE ARQUIVO-RELATORIO.
