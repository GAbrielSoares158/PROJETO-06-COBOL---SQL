# Projeto 6 - Sistema de Contas Bancárias (COBOL + MySQL)

## Pré-requisitos (WSL/Ubuntu)

```bash
sudo apt update
sudo apt install gnucobol libmysqlclient-dev mysql-client
```

Se o MySQL estiver rodando no Windows (não no WSL), instale só o client:
```bash
sudo apt install mysql-client libmysqlclient-dev
```

---

## Configuração

### 1. Criar o banco de dados

```bash
mysql -u root -p < jcl/setup.sql
```

### 2. Ajustar credenciais

Edite os dois programas COBOL e coloque sua senha do MySQL:

- `cobol/PROC-CLI.CBL` → linha `WS-DB-PASS`
- `cobol/PROC-TRX.CBL` → linha `WS-DB-PASS`

Se o MySQL está no Windows (host diferente do WSL), troque `localhost`
pelo IP que aparece em `cat /etc/resolv.conf` (campo `nameserver`).

---

## Execução

```bash
chmod +x run.sh
./run.sh
```

O script faz tudo na seguinte ordem:
1. Cria as pastas `output/` e `input_sorted/`
2. **Ordena** os arquivos de entrada (por CLI_ID e TRX_ID) e salva em `input_sorted/`
3. Compila a biblioteca C (`libdbbridge.so`)
4. Compila os programas COBOL
5. Executa `PROC-CLI` → processa clientes
6. Executa `PROC-TRX` → processa transações

---

## Estrutura de arquivos

```
projeto6/
├── c_bridge/
│   └── db_bridge.c        # Camada C - ponte COBOL <-> MySQL
├── cobol/
│   ├── PROC-CLI.CBL       # Processa CLIENTES.TXT
│   └── PROC-TRX.CBL       # Processa TRANSACOES.TXT
├── copybooks/
│   ├── CLIENTE.CPY        # Layout do registro de cliente
│   ├── TRANSACAO.CPY      # Layout do registro de transação
│   └── DBCOMM.CPY         # Área de comunicação COBOL <-> C
├── input/
│   ├── CLIENTES.TXT       # Arquivo de entrada original - clientes
│   └── TRANSACOES.TXT     # Arquivo de entrada original - transações
├── input_sorted/          # Gerado na execução (arquivos ordenados)
│   ├── CLIENTES.TXT       # Clientes ordenados por CLI_ID
│   └── TRANSACOES.TXT     # Transações ordenadas por TRX_ID
├── jcl/
│   └── setup.sql          # Criação das tabelas MySQL
├── output/                # Gerado na execução
│   ├── LOG-CLI.TXT        # Log do processamento de clientes
│   ├── LOG-TRX.TXT        # Log do processamento de transações
│   ├── RELATORIO.TXT      # Relatório detalhado com totais
│   └── ERROS.TXT          # Registro de erros
└── run.sh                 # Script de build e execução (= JCL)
```

---

## Layout dos arquivos de entrada

**CLIENTES.TXT** (44 colunas por linha):
```
Pos 01-05  CLI_ID     (numérico 5 dígitos)
Pos 06-35  CLI_NOME   (alfanumérico 30 chars)
Pos 36-44  CLI_SALDO  (numérico 9 dígitos)
```

**TRANSACOES.TXT** (20 colunas por linha):
```
Pos 01-05  CLI_ID     (numérico 5 dígitos)
Pos 06-10  TRX_ID     (numérico 5 dígitos)
Pos 11-11  TRX_TIPO   (C=crédito, D=débito)
Pos 12-20  TRX_VALOR  (numérico 9 dígitos)
```

---

## Regras de negócio implementadas

- Cliente sem nome → erro registrado, registro ignorado
- Cliente novo → INSERT na tabela CLIENTES
- Cliente existente → UPDATE de nome e saldo
- Débito sem saldo → erro registrado, rollback
- Tipo inválido (não C nem D) → erro registrado
- Valor zerado → erro registrado
- Cliente inexistente em transação → erro registrado
- COMMIT a cada 100 registros
- ROLLBACK em caso de erro SQL
- Todos os erros gravados em ERROS.TXT e na tabela ERROS_PROCESSAMENTO
