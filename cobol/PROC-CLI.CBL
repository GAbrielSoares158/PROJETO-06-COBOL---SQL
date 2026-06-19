      *----------------------------------------------------------------*
      * PROGRAMA: PROC-CLI.CBL                                         *
      * DESCRICAO: PROCESSAMENTO DO ARQUIVO DE CLIENTES                *
      *            LE CLIENTES.TXT E ATUALIZA TABELA DB2               *
      *----------------------------------------------------------------*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROC-CLI.
       AUTHOR. GABRIEL SOARES REIS.

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQUIVO-CLIENTES ASSIGN TO 'input_sorted/CLIENTES.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ARQUIVO-LOG     ASSIGN TO 'output/LOG-CLI.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.
           SELECT ARQUIVO-ERROS   ASSIGN TO 'output/ERROS.TXT'
               ORGANIZATION IS LINE SEQUENTIAL.

       DATA DIVISION.
       FILE SECTION.

       FD ARQUIVO-CLIENTES.
       01 FS-CLIENTE              PIC X(44).

       FD ARQUIVO-LOG.
       01 FS-LOG                  PIC X(120).

       FD ARQUIVO-ERROS.
       01 FS-ERRO                 PIC X(120).

       WORKING-STORAGE SECTION.

       COPY 'copybooks/CLIENTE.CPY'.
       COPY 'copybooks/DBCOMM.CPY'.

       01 WS-FLAGS.
          05 WS-FIM-CLIENTES      PIC X(01) VALUE 'N'.
          05 WS-STATUS-ARQ        PIC 9(02) VALUE 0.

       01 WS-CONTADORES.
          05 WS-LIDOS             PIC 9(05) VALUE 0.
          05 WS-PROCESSADOS       PIC 9(05) VALUE 0.
          05 WS-ERROS             PIC 9(05) VALUE 0.
          05 WS-COMMITS           PIC 9(05) VALUE 0.
          05 WS-CTR-COMMIT        PIC 9(03) VALUE 0.

       01 WS-LINHA-LOG            PIC X(120).
       01 WS-LINHA-ERRO           PIC X(120).

       01 WS-DB-HOST              PIC X(64) VALUE 'localhost'.
       01 WS-DB-USER              PIC X(64) VALUE 'root'.
       01 WS-DB-PASS              PIC X(64) VALUE 'senha'.
       01 WS-DB-NAME              PIC X(64) VALUE 'banco_proj6'.

       01 WS-DESC-ERRO            PIC X(100).

       PROCEDURE DIVISION.

       0000-PRINCIPAL.
           PERFORM 1000-INICIALIZAR
           PERFORM 2000-PROCESSAR-CLIENTES
           PERFORM 3000-FINALIZAR
           STOP RUN.

      *----------------------------------------------------------------*
       1000-INICIALIZAR.
           OPEN INPUT  ARQUIVO-CLIENTES
           OPEN OUTPUT ARQUIVO-LOG
           OPEN OUTPUT ARQUIVO-ERROS

           CALL 'db_connect' USING WS-DB-AREA
                                   WS-DB-HOST
                                   WS-DB-USER
                                   WS-DB-PASS
                                   WS-DB-NAME
           IF WS-DB-SQLCODE NOT = 0
               MOVE 'ERRO CONEXAO BD: ' TO WS-LINHA-LOG
               STRING 'ERRO CONEXAO BD: ' DELIMITED SIZE
                      WS-DB-MSG          DELIMITED SIZE
                   INTO WS-LINHA-LOG
               WRITE FS-LOG FROM WS-LINHA-LOG
               STOP RUN
           END-IF

           CALL 'db_autocommit_off' USING WS-DB-AREA

           WRITE FS-LOG FROM
               '===================================================='
           WRITE FS-LOG FROM
               '     LOG DE PROCESSAMENTO - CLIENTES                '
           WRITE FS-LOG FROM
               '===================================================='
           MOVE 'INICIO PROCESSAMENTO CLIENTES' TO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG.

      *----------------------------------------------------------------*
       2000-PROCESSAR-CLIENTES.
           READ ARQUIVO-CLIENTES INTO FS-CLIENTE
               AT END MOVE 'S' TO WS-FIM-CLIENTES
           END-READ

           PERFORM UNTIL WS-FIM-CLIENTES = 'S'
               ADD 1 TO WS-LIDOS
               PERFORM 2100-TRATAR-REGISTRO
               READ ARQUIVO-CLIENTES INTO FS-CLIENTE
                   AT END MOVE 'S' TO WS-FIM-CLIENTES
               END-READ
           END-PERFORM.

      *----------------------------------------------------------------*
       2100-TRATAR-REGISTRO.
           MOVE FS-CLIENTE(1:5)   TO WS-CLI-ID
           MOVE FS-CLIENTE(6:30)  TO WS-CLI-NOME
           MOVE FS-CLIENTE(36:9)  TO WS-CLI-SALDO

           IF WS-CLI-NOME = SPACES
               ADD 1 TO WS-ERROS
               MOVE WS-CLI-ID TO WS-DB-CLI-ID
               MOVE 'NOME OBRIGATORIO' TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO CLI ' DELIMITED SIZE
                      WS-CLI-ID   DELIMITED SIZE
                      ' - NOME OBRIGATORIO' DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               MOVE SPACES TO WS-LINHA-LOG
               STRING 'ERRO CLI ' DELIMITED SIZE
                      WS-CLI-ID   DELIMITED SIZE
                      ' NOME AUSENTE' DELIMITED SIZE
                   INTO WS-LINHA-LOG
               WRITE FS-LOG FROM WS-LINHA-LOG
               GO TO 2100-FIM
           END-IF

           MOVE WS-CLI-ID    TO WS-DB-CLI-ID
           MOVE WS-CLI-NOME  TO WS-DB-CLI-NOME
           MOVE WS-CLI-SALDO TO WS-DB-CLI-SALDO

           CALL 'db_busca_cliente' USING WS-DB-AREA WS-CLIENTE-DB

           IF WS-DB-SQLCODE = 100
               CALL 'db_insert_cliente' USING WS-DB-AREA WS-CLIENTE-DB
               MOVE 'INSERT' TO WS-DB-MSG(1:6)
           ELSE
               CALL 'db_update_cliente' USING WS-DB-AREA WS-CLIENTE-DB
               MOVE 'UPDATE' TO WS-DB-MSG(1:6)
           END-IF

           IF WS-DB-SQLCODE NOT = 0
               ADD 1 TO WS-ERROS
               MOVE WS-DB-MSG TO WS-DESC-ERRO
               CALL 'db_insert_erro' USING WS-DB-AREA
                                          WS-CLIENTE-DB
                                          WS-DESC-ERRO
               STRING 'ERRO SQL CLI ' DELIMITED SIZE
                      WS-CLI-ID       DELIMITED SIZE
                      ': '            DELIMITED SIZE
                      WS-DB-MSG       DELIMITED SIZE
                   INTO WS-LINHA-ERRO
               WRITE FS-ERRO FROM WS-LINHA-ERRO
               CALL 'db_rollback' USING WS-DB-AREA
               GO TO 2100-FIM
           END-IF

           ADD 1 TO WS-PROCESSADOS
           ADD 1 TO WS-CTR-COMMIT

           STRING 'OK CLI ' DELIMITED SIZE
                  WS-CLI-ID DELIMITED SIZE
                  ' '       DELIMITED SIZE
                  WS-CLI-NOME DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           IF WS-CTR-COMMIT >= 100
               CALL 'db_commit' USING WS-DB-AREA
               ADD 1 TO WS-COMMITS
               MOVE 0 TO WS-CTR-COMMIT
           END-IF.

       2100-FIM.
           CONTINUE.

      *----------------------------------------------------------------*
       3000-FINALIZAR.
           IF WS-CTR-COMMIT > 0
               CALL 'db_commit' USING WS-DB-AREA
               ADD 1 TO WS-COMMITS
           END-IF

           CALL 'db_disconnect' USING WS-DB-AREA

           MOVE SPACES TO WS-LINHA-LOG
           STRING '================================' DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           MOVE SPACES TO WS-LINHA-LOG
           STRING 'TOTAL LIDOS     : ' DELIMITED SIZE
                  WS-LIDOS             DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           MOVE SPACES TO WS-LINHA-LOG
           STRING 'TOTAL PROCESSADOS: ' DELIMITED SIZE
                  WS-PROCESSADOS        DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           MOVE SPACES TO WS-LINHA-LOG
           STRING 'TOTAL COM ERRO  : ' DELIMITED SIZE
                  WS-ERROS              DELIMITED SIZE
               INTO WS-LINHA-LOG
           WRITE FS-LOG FROM WS-LINHA-LOG

           CLOSE ARQUIVO-CLIENTES
           CLOSE ARQUIVO-LOG
           CLOSE ARQUIVO-ERROS.
