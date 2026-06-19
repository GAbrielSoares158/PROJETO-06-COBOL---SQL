-- ---------------------------------------------------------------
-- setup.sql
-- Criacao do banco e tabelas do Projeto 6
-- Executar: mysql -u root -p < jcl/setup.sql
-- ---------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS banco_proj6;
USE banco_proj6;

DROP TABLE IF EXISTS ERROS_PROCESSAMENTO;
DROP TABLE IF EXISTS TRANSACOES;
DROP TABLE IF EXISTS CLIENTES;

CREATE TABLE CLIENTES (
    CLI_ID          INTEGER      NOT NULL,
    CLI_NOME        VARCHAR(30)  NOT NULL,
    CLI_SALDO       DECIMAL(9,0) NOT NULL,
    DT_ATUALIZACAO  DATE,
    PRIMARY KEY (CLI_ID)
);

CREATE TABLE TRANSACOES (
    TRX_ID              INTEGER      NOT NULL,
    CLI_ID              INTEGER      NOT NULL,
    TRX_TIPO            CHAR(1)      NOT NULL,
    TRX_VALOR           DECIMAL(9,0) NOT NULL,
    DT_PROCESSAMENTO    DATE,
    PRIMARY KEY (TRX_ID)
);

CREATE TABLE ERROS_PROCESSAMENTO (
    ID_ERRO         INTEGER      NOT NULL AUTO_INCREMENT,
    CLI_ID          INTEGER,
    DESCRICAO_ERRO  VARCHAR(100),
    DT_OCORRENCIA   TIMESTAMP,
    PRIMARY KEY (ID_ERRO)
);

-- Indices para otimizacao (desafio extra)
CREATE INDEX IDX_TRX_CLI ON TRANSACOES(CLI_ID);
CREATE INDEX IDX_ERR_CLI ON ERROS_PROCESSAMENTO(CLI_ID);

SELECT 'TABELAS CRIADAS COM SUCESSO' AS STATUS;
