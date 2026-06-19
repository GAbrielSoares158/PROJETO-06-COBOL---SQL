/*----------------------------------------------------------------*/
/* db_bridge.c                                                    */
/* Camada auxiliar C - ponte entre GnuCOBOL e MySQL               */
/* Compilar: gcc -shared -fPIC -o libdbbridge.so db_bridge.c      */
/*           $(mysql_config --cflags --libs)                       */
/*----------------------------------------------------------------*/

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <mysql/mysql.h>

static MYSQL *conn = NULL;

/* Estrutura espelhando WS-DB-AREA do COBOL (packed) */
typedef struct {
    short  sqlcode;
    char   msg[100];
    int    rows;
} DB_AREA;

typedef struct {
    int    cli_id;
    char   cli_nome[30];
    int    cli_saldo;
} DB_CLIENTE;

typedef struct {
    int    trx_id;
    int    trx_cli;
    char   trx_tipo[1];
    int    trx_valor;
} DB_TRANSACAO;

/*----------------------------------------------------------------*/
/* DB_CONNECT - abre conexao com o banco                          */
/*----------------------------------------------------------------*/
void db_connect_(DB_AREA *area,
                 char *host, char *user, char *pass, char *dbname)
{
    char h[64], u[64], p[64], d[64];
    int i;

    /* Copiar e remover espacos finais (COBOL preenche com espaco) */
    for (i = 0; i < 63 && host[i] != ' ' && host[i] != '\0'; i++)
        h[i] = host[i];
    h[i] = '\0';
    for (i = 0; i < 63 && user[i] != ' ' && user[i] != '\0'; i++)
        u[i] = user[i];
    u[i] = '\0';
    for (i = 0; i < 63 && pass[i] != ' ' && pass[i] != '\0'; i++)
        p[i] = pass[i];
    p[i] = '\0';
    for (i = 0; i < 63 && dbname[i] != ' ' && dbname[i] != '\0'; i++)
        d[i] = dbname[i];
    d[i] = '\0';

    conn = mysql_init(NULL);
    if (!conn) {
        area->sqlcode = -1;
        strncpy(area->msg, "ERRO: mysql_init falhou", 100);
        return;
    }
    if (!mysql_real_connect(conn, h, u, p, d, 0, NULL, 0)) {
        area->sqlcode = -2;
        strncpy(area->msg, mysql_error(conn), 100);
        mysql_close(conn);
        conn = NULL;
        return;
    }
    area->sqlcode = 0;
    strncpy(area->msg, "CONEXAO OK", 100);
}

/*----------------------------------------------------------------*/
/* DB_DISCONNECT - fecha conexao                                   */
/*----------------------------------------------------------------*/
void db_disconnect_(DB_AREA *area)
{
    if (conn) {
        mysql_close(conn);
        conn = NULL;
    }
    area->sqlcode = 0;
    strncpy(area->msg, "DESCONECTADO", 100);
}

/*----------------------------------------------------------------*/
/* DB_COMMIT                                                       */
/*----------------------------------------------------------------*/
void db_commit_(DB_AREA *area)
{
    if (mysql_commit(conn)) {
        area->sqlcode = -10;
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "COMMIT OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_ROLLBACK                                                     */
/*----------------------------------------------------------------*/
void db_rollback_(DB_AREA *area)
{
    if (mysql_rollback(conn)) {
        area->sqlcode = -11;
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "ROLLBACK OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_AUTOCOMMIT_OFF - desliga autocommit para controle manual    */
/*----------------------------------------------------------------*/
void db_autocommit_off_(DB_AREA *area)
{
    mysql_autocommit(conn, 0);
    area->sqlcode = 0;
    strncpy(area->msg, "AUTOCOMMIT OFF", 100);
}

/*----------------------------------------------------------------*/
/* DB_BUSCA_CLIENTE - SELECT por CLI_ID                           */
/* Retorna sqlcode=0 se encontrou, 100 se nao encontrou           */
/*----------------------------------------------------------------*/
void db_busca_cliente_(DB_AREA *area, DB_CLIENTE *cli)
{
    char sql[256];
    MYSQL_RES *res;
    MYSQL_ROW  row;
    int i;

    snprintf(sql, sizeof(sql),
        "SELECT CLI_ID, CLI_NOME, CLI_SALDO "
        "FROM CLIENTES WHERE CLI_ID = %d", cli->cli_id);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
        return;
    }
    res = mysql_store_result(conn);
    row = mysql_fetch_row(res);
    if (!row) {
        area->sqlcode = 100;
        strncpy(area->msg, "CLIENTE NAO ENCONTRADO", 100);
        mysql_free_result(res);
        return;
    }
    cli->cli_id    = atoi(row[0]);
    memset(cli->cli_nome, ' ', 30);
    for (i = 0; row[1][i] && i < 30; i++)
        cli->cli_nome[i] = row[1][i];
    cli->cli_saldo = atoi(row[2]);
    area->sqlcode  = 0;
    area->rows     = 1;
    strncpy(area->msg, "CLIENTE ENCONTRADO", 100);
    mysql_free_result(res);
}

/*----------------------------------------------------------------*/
/* DB_INSERT_CLIENTE                                               */
/*----------------------------------------------------------------*/
void db_insert_cliente_(DB_AREA *area, DB_CLIENTE *cli)
{
    char sql[512];
    char nome[31];
    int i;

    memset(nome, 0, sizeof(nome));
    for (i = 0; i < 30 && cli->cli_nome[i] != ' '
              && cli->cli_nome[i] != '\0'; i++)
        nome[i] = cli->cli_nome[i];

    snprintf(sql, sizeof(sql),
        "INSERT INTO CLIENTES (CLI_ID, CLI_NOME, CLI_SALDO, "
        "DT_ATUALIZACAO) VALUES (%d, '%s', %d, CURDATE())",
        cli->cli_id, nome, cli->cli_saldo);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "INSERT CLIENTE OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_UPDATE_CLIENTE - atualiza nome e saldo                      */
/*----------------------------------------------------------------*/
void db_update_cliente_(DB_AREA *area, DB_CLIENTE *cli)
{
    char sql[512];
    char nome[31];
    int i;

    memset(nome, 0, sizeof(nome));
    for (i = 0; i < 30 && cli->cli_nome[i] != ' '
              && cli->cli_nome[i] != '\0'; i++)
        nome[i] = cli->cli_nome[i];

    snprintf(sql, sizeof(sql),
        "UPDATE CLIENTES SET CLI_NOME = '%s', CLI_SALDO = %d, "
        "DT_ATUALIZACAO = CURDATE() WHERE CLI_ID = %d",
        nome, cli->cli_saldo, cli->cli_id);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "UPDATE CLIENTE OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_UPDATE_SALDO - atualiza apenas o saldo do cliente           */
/*----------------------------------------------------------------*/
void db_update_saldo_(DB_AREA *area, DB_CLIENTE *cli)
{
    char sql[256];

    snprintf(sql, sizeof(sql),
        "UPDATE CLIENTES SET CLI_SALDO = %d, "
        "DT_ATUALIZACAO = CURDATE() WHERE CLI_ID = %d",
        cli->cli_saldo, cli->cli_id);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "UPDATE SALDO OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_INSERT_TRANSACAO                                             */
/*----------------------------------------------------------------*/
void db_insert_transacao_(DB_AREA *area, DB_TRANSACAO *trx)
{
    char sql[512];
    char tipo[2];

    tipo[0] = trx->trx_tipo[0];
    tipo[1] = '\0';

    snprintf(sql, sizeof(sql),
        "INSERT INTO TRANSACOES (TRX_ID, CLI_ID, TRX_TIPO, "
        "TRX_VALOR, DT_PROCESSAMENTO) "
        "VALUES (%d, %d, '%s', %d, CURDATE())",
        trx->trx_id, trx->trx_cli, tipo, trx->trx_valor);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "INSERT TRANSACAO OK", 100);
    }
}

/*----------------------------------------------------------------*/
/* DB_INSERT_ERRO                                                  */
/*----------------------------------------------------------------*/
void db_insert_erro_(DB_AREA *area, DB_CLIENTE *cli, char *descricao)
{
    char sql[512];
    char desc[101];
    int i;

    memset(desc, 0, sizeof(desc));
    for (i = 0; i < 100 && descricao[i] != '\0'; i++)
        desc[i] = descricao[i];

    snprintf(sql, sizeof(sql),
        "INSERT INTO ERROS_PROCESSAMENTO "
        "(CLI_ID, DESCRICAO_ERRO, DT_OCORRENCIA) "
        "VALUES (%d, '%s', NOW())",
        cli->cli_id, desc);

    if (mysql_query(conn, sql)) {
        area->sqlcode = (short)mysql_errno(conn);
        strncpy(area->msg, mysql_error(conn), 100);
    } else {
        area->sqlcode = 0;
        strncpy(area->msg, "INSERT ERRO OK", 100);
    }
}
