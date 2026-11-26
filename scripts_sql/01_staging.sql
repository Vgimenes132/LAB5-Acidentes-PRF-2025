-- 01_staging.sql
-- Autor: Vitor Gimenes Magalhães | LAB de Desenvolvimento de BD V, Fatec Bauru
-- Staging do CSV da PRF: cópia fiel do arquivo, sem conversões. Não é alterada após a importação.


-- Usuário do projeto (uma vez, como SYSTEM no FREEPDB1)
-- CREATE USER acidentes IDENTIFIED BY "TroqueEstaSenha"
--   DEFAULT TABLESPACE users
--   QUOTA UNLIMITED ON users;
--
-- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
--       CREATE SEQUENCE, CREATE PROCEDURE TO acidentes;


-- Staging: colunas com os nomes do cabeçalho do CSV (inclusive a grafia "metereologica")
CREATE TABLE stg_acidente (
    id                      VARCHAR2(20  CHAR),
    data_inversa            VARCHAR2(20  CHAR),   -- AAAA-MM-DD
    dia_semana              VARCHAR2(20  CHAR),
    horario                 VARCHAR2(20  CHAR),   -- HH24:MI:SS
    uf                      VARCHAR2(5   CHAR),
    br                      VARCHAR2(10  CHAR),
    km                      VARCHAR2(20  CHAR),   -- vírgula decimal
    municipio               VARCHAR2(100 CHAR),
    causa_acidente          VARCHAR2(200 CHAR),
    tipo_acidente           VARCHAR2(100 CHAR),
    classificacao_acidente  VARCHAR2(50  CHAR),
    fase_dia                VARCHAR2(30  CHAR),
    sentido_via             VARCHAR2(30  CHAR),
    condicao_metereologica  VARCHAR2(50  CHAR),
    tipo_pista              VARCHAR2(30  CHAR),
    tracado_via             VARCHAR2(200 CHAR),   -- itens separados por ";"
    uso_solo                VARCHAR2(10  CHAR),
    pessoas                 VARCHAR2(10  CHAR),
    mortos                  VARCHAR2(10  CHAR),
    feridos_leves           VARCHAR2(10  CHAR),
    feridos_graves          VARCHAR2(10  CHAR),
    ilesos                  VARCHAR2(10  CHAR),
    ignorados               VARCHAR2(10  CHAR),
    feridos                 VARCHAR2(10  CHAR),
    veiculos                VARCHAR2(10  CHAR),
    latitude                VARCHAR2(30  CHAR),   -- vírgula decimal
    longitude               VARCHAR2(30  CHAR),   -- vírgula decimal
    regional                VARCHAR2(20  CHAR),
    delegacia               VARCHAR2(20  CHAR),
    uop                     VARCHAR2(30  CHAR)
);

COMMENT ON TABLE stg_acidente IS
  'Staging: cópia fiel do arquivo datatran2025.csv da PRF. Não alterar após a importação.';


-- Rejeitos da carga (preenchida pelo script 03, uma linha por problema)
CREATE TABLE stg_acidente_erro (
    id_erro         NUMBER GENERATED ALWAYS AS IDENTITY
                    CONSTRAINT pk_stg_acidente_erro PRIMARY KEY,
    id_ocorrencia   VARCHAR2(20  CHAR),
    coluna          VARCHAR2(30  CHAR),
    valor_original  VARCHAR2(200 CHAR),
    motivo          VARCHAR2(400 CHAR) NOT NULL,
    fl_bloqueante   CHAR(1) DEFAULT 'N' NOT NULL      -- S: a linha não entrou na fato
                    CONSTRAINT ck_stg_erro_bloq CHECK (fl_bloqueante IN ('S','N')),
    dt_registro     DATE DEFAULT SYSDATE NOT NULL
);

COMMENT ON TABLE stg_acidente_erro IS
  'Problemas encontrados na carga da staging para o modelo estrela. fl_bloqueante = S: linha rejeitada; N: apenas aviso.';


-- Importação: SQL Developer > Importar Dados, codificação ISO-8859-1, delimitador ";"


-- Conferência da importação
-- Esperado: 72529
SELECT COUNT(*) AS qt_linhas FROM stg_acidente;

-- Esperado: pessoas 188346 | mortos 6043 | feridos 83550 | veiculos 144922
SELECT SUM(TO_NUMBER(pessoas))  AS pessoas,
       SUM(TO_NUMBER(mortos))   AS mortos,
       SUM(TO_NUMBER(feridos))  AS feridos,
       SUM(TO_NUMBER(veiculos)) AS veiculos
  FROM stg_acidente;

-- Acentuação. Esperado: 46375 (0 = codificação errada)
SELECT COUNT(*) AS qt_ceu_claro
  FROM stg_acidente
 WHERE condicao_metereologica = 'Céu Claro';

-- Colunas vazias. Esperado: 0 em todas (ausências vêm como "NA")
SELECT SUM(CASE WHEN id           IS NULL THEN 1 ELSE 0 END) AS id_nulo,
       SUM(CASE WHEN data_inversa IS NULL THEN 1 ELSE 0 END) AS data_nula,
       SUM(CASE WHEN municipio    IS NULL THEN 1 ELSE 0 END) AS municipio_nulo,
       SUM(CASE WHEN tracado_via  IS NULL THEN 1 ELSE 0 END) AS tracado_nulo,
       SUM(CASE WHEN uop          IS NULL THEN 1 ELSE 0 END) AS uop_nulo
  FROM stg_acidente;

-- Ids não inteiros. Esperado: nenhuma linha
SELECT id, data_inversa, horario, uf, municipio
  FROM stg_acidente
 WHERE NOT REGEXP_LIKE(id, '^[0-9]+$');
