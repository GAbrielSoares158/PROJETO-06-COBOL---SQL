#!/bin/bash
# ---------------------------------------------------------------
# run.sh - Script de execucao do Projeto 6 (equivalente ao JCL)
# Uso: ./run.sh
# ---------------------------------------------------------------

set -e

echo "============================================"
echo " PROJETO 6 - SISTEMA DE CONTAS BANCARIAS   "
echo "============================================"

# ----------------------------
# 1. Preparar diretorios
# ----------------------------
mkdir -p output input_sorted

# ----------------------------
# 2. Ordenar arquivos de entrada (Requisito 1)
# ----------------------------
echo "[1/5] Ordenando arquivos de entrada..."

# Ordenar por CLI_ID (colunas 1-5)
sort -k1.1,1.5 input/CLIENTES.TXT    > input_sorted/CLIENTES.TXT
# Ordenar por TRX_ID (colunas 6-10)
sort -k1.6,1.10 input/TRANSACOES.TXT > input_sorted/TRANSACOES.TXT

echo "      Arquivos ordenados em input_sorted/."

# ----------------------------
# 3. Compilar biblioteca C
# ----------------------------
echo "[2/5] Compilando camada C (db_bridge)..."

gcc -shared -fPIC -o libdbbridge.so c_bridge/db_bridge.c \
    $(mysql_config --cflags --libs)

echo "      libdbbridge.so gerada com sucesso."

# ----------------------------
# 4. Compilar programas COBOL
# ----------------------------
echo "[3/5] Compilando PROC-CLI.CBL..."

cobc -x -free -o PROC-CLI cobol/PROC-CLI.CBL \
    -L. -ldbbridge \
    $(mysql_config --libs)

echo "[4/5] Compilando PROC-TRX.CBL..."

cobc -x -free -o PROC-TRX cobol/PROC-TRX.CBL \
    -L. -ldbbridge \
    $(mysql_config --libs)

echo "      Compilacao concluida."

# ----------------------------
# 5. Executar programas
# ----------------------------
echo "[5/5] Executando processamento..."

export LD_LIBRARY_PATH=.:$LD_LIBRARY_PATH
export COB_LIBRARY_PATH=.

echo ""
echo "--- PASSO 1: Processando clientes ---"
./PROC-CLI
echo "    Concluido. Ver output/LOG-CLI.TXT"

echo ""
echo "--- PASSO 2: Processando transacoes ---"
./PROC-TRX
echo "    Concluido. Ver output/RELATORIO.TXT"

echo ""
echo "============================================"
echo " PROCESSAMENTO FINALIZADO                  "
echo "============================================"
echo ""
echo "Arquivos gerados em output/:"
ls -lh output/
echo ""
echo "--- LOG CLIENTES ---"
cat output/LOG-CLI.TXT
echo ""
echo "--- RELATORIO TRANSACOES ---"
cat output/RELATORIO.TXT
echo ""
echo "--- ERROS ---"
if [ -s output/ERROS.TXT ]; then
    cat output/ERROS.TXT
else
    echo "    Nenhum erro registrado."
fi
