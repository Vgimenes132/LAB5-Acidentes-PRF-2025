-- 01_staging.sql
-- Projeto: Acidentes nas rodovias federais (PRF 2025), LAB BD V, Fatec Bauru
-- Autor: Vitor Gimenes Magalhães (CST em Banco de Dados, LAB de Desenvolvimento de BD V, Profa. Mariana Rodrigues Santesso)
-- Área de staging: recebe o CSV da PRF sem nenhuma conversão.
--
-- Conteúdo:
--   Parte 0  Usuário do projeto (executar uma vez, como SYSTEM)
--   Parte 1  STG_ACIDENTE, cópia fiel do arquivo (todas as colunas em VARCHAR2)
--   Parte 2  STG_ACIDENTE_ERRO, que recebe os problemas apontados pela carga (script 03)
--   Parte 3  Importação do CSV pelo SQL Developer
--   Parte 4  Conferência da importação
--   Parte 5  Exportação do CSV a partir do banco
--
-- A STG_ACIDENTE não é alterada depois da importação. Toda limpeza acontece no
-- caminho da staging para as dimensões e a fato, o que permite refazer o
-- tratamento a qualquer momento a partir do dado original.


-- Parte 0. Usuário do projeto
-- Conectar como SYSTEM no serviço FREEPDB1 (o banco plugável onde se criam os
-- usuários comuns no Oracle Free). Se o usuário já existir, pular esta parte.

-- CREATE USER acidentes IDENTIFIED BY "TroqueEstaSenha"
--   DEFAULT TABLESPACE users
--   QUOTA UNLIMITED ON users;
--
-- GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
--       CREATE SEQUENCE, CREATE PROCEDURE TO acidentes;

-- Daqui em diante, conectar como ACIDENTES (serviço FREEPDB1).


-- Parte 1. Tabela de staging
-- Os nomes das colunas são os mesmos do cabeçalho do CSV, inclusive
-- "condicao_metereologica", grafado assim na fonte. Isso permite que o assistente
-- de importação associe as colunas automaticamente; o nome correto é usado no
-- modelo estrela. Os tamanhos têm folga em relação aos maiores valores do arquivo
-- de 2025, para aceitar arquivos de outros anos. Não há chaves nem restrições:
-- a validação é feita pela package de carga.

CREATE TABLE stg_acidente (
    id                      VARCHAR2(20  CHAR),   -- maior valor atual: 6 dígitos
    data_inversa            VARCHAR2(20  CHAR),   -- AAAA-MM-DD
    dia_semana              VARCHAR2(20  CHAR),
    horario                 VARCHAR2(20  CHAR),   -- HH24:MI:SS
    uf                      VARCHAR2(5   CHAR),
    br                      VARCHAR2(10  CHAR),
    km                      VARCHAR2(20  CHAR),   -- vírgula decimal
    municipio               VARCHAR2(100 CHAR),   -- maior valor atual: 32
    causa_acidente          VARCHAR2(200 CHAR),   -- maior valor atual: 77
    tipo_acidente           VARCHAR2(100 CHAR),
    classificacao_acidente  VARCHAR2(50  CHAR),
    fase_dia                VARCHAR2(30  CHAR),
    sentido_via             VARCHAR2(30  CHAR),
    condicao_metereologica  VARCHAR2(50  CHAR),
    tipo_pista              VARCHAR2(30  CHAR),
    tracado_via             VARCHAR2(200 CHAR),   -- vários valores separados por ";", maior atual: 82
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


-- Parte 2. Tabela de rejeitos
-- Preenchida pela package do script 03. Cada problema gera uma linha, portanto
-- uma ocorrência pode aparecer mais de uma vez.

CREATE TABLE stg_acidente_erro (
    id_erro         NUMBER GENERATED ALWAYS AS IDENTITY
                    CONSTRAINT pk_stg_acidente_erro PRIMARY KEY,
    id_ocorrencia   VARCHAR2(20  CHAR),               -- valor original do "id"
    coluna          VARCHAR2(30  CHAR),
    valor_original  VARCHAR2(200 CHAR),
    motivo          VARCHAR2(400 CHAR) NOT NULL,
    fl_bloqueante   CHAR(1) DEFAULT 'N' NOT NULL      -- S: a linha não entrou na fato
                    CONSTRAINT ck_stg_erro_bloq CHECK (fl_bloqueante IN ('S','N')),
    dt_registro     DATE DEFAULT SYSDATE NOT NULL
);

COMMENT ON TABLE stg_acidente_erro IS
  'Problemas encontrados na carga da staging para o modelo estrela. fl_bloqueante = S: linha rejeitada; N: apenas aviso.';


-- Parte 3. Importação do CSV (SQL Developer)
--  1. No painel Conexões, expandir ACIDENTES > Tabelas.
--  2. Clicar com o botão direito em STG_ACIDENTE > Importar Dados.
--  3. Na tela de visualização:
--       Arquivo:               datatran2025.csv (descompactado de dados/original)
--       Cabeçalho:             marcado
--       Formato:               csv (delimitado)
--       Codificação:           ISO-8859-1 (com outra codificação os acentos se corrompem)
--       Delimitador:           ;
--       Delimitador de texto:  " à esquerda e à direita
--     Conferir na prévia se "Colisão", "Céu Claro" e "sábado" aparecem corretamente.
--  4. Método de importação: Inserir.
--  5. Mapeamento: as colunas devem ser associadas pelo nome automaticamente. Uma
--     coluna sem destino indica delimitador errado.
--  6. Finalizar e executar COMMIT (F11) se o autocommit estiver desligado.


-- Parte 4. Conferência da importação
-- Os valores esperados foram calculados diretamente do CSV original. Se algum
-- número divergir, limpar a tabela (TRUNCATE) e importar novamente antes de seguir.

-- 4.1 Quantidade de linhas. Esperado: 72529.
SELECT COUNT(*) AS qt_linhas FROM stg_acidente;

-- 4.2 Totais de controle.
--     Esperado: pessoas 188346 | mortos 6043 | feridos 83550 | veiculos 144922.
SELECT SUM(TO_NUMBER(pessoas))  AS pessoas,
       SUM(TO_NUMBER(mortos))   AS mortos,
       SUM(TO_NUMBER(feridos))  AS feridos,
       SUM(TO_NUMBER(veiculos)) AS veiculos
  FROM stg_acidente;

-- 4.3 Acentuação. Esperado: 46375.
--     Resultado 0 indica importação com a codificação errada.
SELECT COUNT(*) AS qt_ceu_claro
  FROM stg_acidente
 WHERE condicao_metereologica = 'Céu Claro';

-- 4.4 Colunas vazias. Esperado: 0 em todas.
--     O CSV não tem campos vazios; ausências vêm escritas como "NA" e são tratadas depois.
SELECT SUM(CASE WHEN id           IS NULL THEN 1 ELSE 0 END) AS id_nulo,
       SUM(CASE WHEN data_inversa IS NULL THEN 1 ELSE 0 END) AS data_nula,
       SUM(CASE WHEN municipio    IS NULL THEN 1 ELSE 0 END) AS municipio_nulo,
       SUM(CASE WHEN tracado_via  IS NULL THEN 1 ELSE 0 END) AS tracado_nulo,
       SUM(CASE WHEN uop          IS NULL THEN 1 ELSE 0 END) AS uop_nulo
  FROM stg_acidente;

-- 4.5 Identificadores que não são inteiros. Esperado: nenhuma linha.
--     O arquivo de 2026 tinha um id gravado como '8e+05'; o de 2025 não tem,
--     mas a verificação fica para arquivos futuros.
SELECT id, data_inversa, horario, uf, municipio
  FROM stg_acidente
 WHERE NOT REGEXP_LIKE(id, '^[0-9]+$');


-- Parte 5. Exportação do CSV a partir do banco
--  1. Executar: SELECT * FROM stg_acidente;
--  2. Clicar com o botão direito no resultado > Exportar.
--  3. Formato csv, delimitador ";", cabeçalho marcado. Codificação ISO-8859-1
--     reproduz o arquivo original; UTF-8 abre melhor no Excel e no Power BI.
-- A base tratada é exportada da mesma forma a partir da VW_ACIDENTE (script 04).
