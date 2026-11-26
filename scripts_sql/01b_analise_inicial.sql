-- 01b_analise_inicial.sql
-- Projeto: Acidentes nas rodovias federais (PRF 2025), LAB BD V, Fatec Bauru
-- Autor: Vitor Gimenes Magalhães (CST em Banco de Dados, LAB de Desenvolvimento de BD V, Profa. Mariana Rodrigues Santesso)
-- Diagnóstico do dado bruto na staging, antes de qualquer tratamento
-- (item "Análise inicial dos dados" da Etapa 2).
-- Executar depois do 01_staging.sql, como script (F5), com o usuário do projeto.
--
-- Conteúdo:
--   Parte 1  Visão geral
--   Parte 2  Dados faltantes (nulos e marcadores de ausência)
--   Parte 3  Dados duplicados
--   Parte 4  Erros de formato e de conteúdo
--   Parte 5  Inconsistências entre colunas
--   Parte 6  Problemas estruturais (codificação, decimal, campo multivalorado)
--
-- Somente leitura: nenhuma linha é alterada. Os valores esperados foram
-- conferidos sobre a staging de 2025 (72.529 linhas). A STG_ACIDENTE_ERRO,
-- preenchida pelo script 03, registra linha a linha o que aqui aparece em totais.
--
-- A máscara numérica usada nas coordenadas aceita até 20 casas decimais, porque
-- alguns valores da fonte trazem resíduo de ponto flutuante (ex.: -9,128114010000001).


-- Parte 1. Visão geral
-- Esperado: 72529 linhas | 72529 ids distintos | 01/01/2025 a 31/12/2025.
SELECT COUNT(*)                 AS qt_linhas,
       COUNT(DISTINCT id)       AS qt_ids_distintos,
       MIN(TO_DATE(data_inversa DEFAULT NULL ON CONVERSION ERROR, 'FXYYYY-MM-DD')) AS dt_minima,
       MAX(TO_DATE(data_inversa DEFAULT NULL ON CONVERSION ERROR, 'FXYYYY-MM-DD')) AS dt_maxima
  FROM stg_acidente;


-- Parte 2. Dados faltantes
-- Conta, por coluna, os valores nulos ou com marcador de ausência da fonte
-- (NA, N/A, NULL, Ignorado, Não Informado). Só as colunas afetadas são listadas.
-- Esperado: classificacao_acidente 1 | sentido_via 167 | condicao_metereologica 1000 |
--           regional 2 | delegacia 22 | uop 38.
SELECT coluna, qt_ausente
  FROM (
    SELECT  1 AS nr_ordem, 'id'                      AS coluna,
           SUM(CASE WHEN id IS NULL OR UPPER(TRIM(id)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  2 AS nr_ordem, 'data_inversa'            AS coluna,
           SUM(CASE WHEN data_inversa IS NULL OR UPPER(TRIM(data_inversa)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  3 AS nr_ordem, 'dia_semana'              AS coluna,
           SUM(CASE WHEN dia_semana IS NULL OR UPPER(TRIM(dia_semana)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  4 AS nr_ordem, 'horario'                 AS coluna,
           SUM(CASE WHEN horario IS NULL OR UPPER(TRIM(horario)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  5 AS nr_ordem, 'uf'                      AS coluna,
           SUM(CASE WHEN uf IS NULL OR UPPER(TRIM(uf)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  6 AS nr_ordem, 'br'                      AS coluna,
           SUM(CASE WHEN br IS NULL OR UPPER(TRIM(br)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  7 AS nr_ordem, 'km'                      AS coluna,
           SUM(CASE WHEN km IS NULL OR UPPER(TRIM(km)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  8 AS nr_ordem, 'municipio'               AS coluna,
           SUM(CASE WHEN municipio IS NULL OR UPPER(TRIM(municipio)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT  9 AS nr_ordem, 'causa_acidente'          AS coluna,
           SUM(CASE WHEN causa_acidente IS NULL OR UPPER(TRIM(causa_acidente)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 10 AS nr_ordem, 'tipo_acidente'           AS coluna,
           SUM(CASE WHEN tipo_acidente IS NULL OR UPPER(TRIM(tipo_acidente)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 11 AS nr_ordem, 'classificacao_acidente'  AS coluna,
           SUM(CASE WHEN classificacao_acidente IS NULL OR UPPER(TRIM(classificacao_acidente)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 12 AS nr_ordem, 'fase_dia'                AS coluna,
           SUM(CASE WHEN fase_dia IS NULL OR UPPER(TRIM(fase_dia)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 13 AS nr_ordem, 'sentido_via'             AS coluna,
           SUM(CASE WHEN sentido_via IS NULL OR UPPER(TRIM(sentido_via)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 14 AS nr_ordem, 'condicao_metereologica'  AS coluna,
           SUM(CASE WHEN condicao_metereologica IS NULL OR UPPER(TRIM(condicao_metereologica)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 15 AS nr_ordem, 'tipo_pista'              AS coluna,
           SUM(CASE WHEN tipo_pista IS NULL OR UPPER(TRIM(tipo_pista)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 16 AS nr_ordem, 'tracado_via'             AS coluna,
           SUM(CASE WHEN tracado_via IS NULL OR UPPER(TRIM(tracado_via)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 17 AS nr_ordem, 'uso_solo'                AS coluna,
           SUM(CASE WHEN uso_solo IS NULL OR UPPER(TRIM(uso_solo)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 18 AS nr_ordem, 'pessoas'                 AS coluna,
           SUM(CASE WHEN pessoas IS NULL OR UPPER(TRIM(pessoas)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 19 AS nr_ordem, 'mortos'                  AS coluna,
           SUM(CASE WHEN mortos IS NULL OR UPPER(TRIM(mortos)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 20 AS nr_ordem, 'feridos_leves'           AS coluna,
           SUM(CASE WHEN feridos_leves IS NULL OR UPPER(TRIM(feridos_leves)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 21 AS nr_ordem, 'feridos_graves'          AS coluna,
           SUM(CASE WHEN feridos_graves IS NULL OR UPPER(TRIM(feridos_graves)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 22 AS nr_ordem, 'ilesos'                  AS coluna,
           SUM(CASE WHEN ilesos IS NULL OR UPPER(TRIM(ilesos)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 23 AS nr_ordem, 'ignorados'               AS coluna,
           SUM(CASE WHEN ignorados IS NULL OR UPPER(TRIM(ignorados)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 24 AS nr_ordem, 'feridos'                 AS coluna,
           SUM(CASE WHEN feridos IS NULL OR UPPER(TRIM(feridos)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 25 AS nr_ordem, 'veiculos'                AS coluna,
           SUM(CASE WHEN veiculos IS NULL OR UPPER(TRIM(veiculos)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 26 AS nr_ordem, 'latitude'                AS coluna,
           SUM(CASE WHEN latitude IS NULL OR UPPER(TRIM(latitude)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 27 AS nr_ordem, 'longitude'               AS coluna,
           SUM(CASE WHEN longitude IS NULL OR UPPER(TRIM(longitude)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 28 AS nr_ordem, 'regional'                AS coluna,
           SUM(CASE WHEN regional IS NULL OR UPPER(TRIM(regional)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 29 AS nr_ordem, 'delegacia'               AS coluna,
           SUM(CASE WHEN delegacia IS NULL OR UPPER(TRIM(delegacia)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
    UNION ALL
    SELECT 30 AS nr_ordem, 'uop'                     AS coluna,
           SUM(CASE WHEN uop IS NULL OR UPPER(TRIM(uop)) IN ('NA','N/A','NULL','IGNORADO','NÃO INFORMADO','NAO INFORMADO') THEN 1 ELSE 0 END) AS qt_ausente
      FROM stg_acidente
)
 WHERE qt_ausente > 0
 ORDER BY nr_ordem;

-- 2.1 BR igual a 0 não corresponde a uma rodovia: indica que o número não foi informado.
--     Esperado: 167 linhas, todas com km 0 e sentido 'Não Informado'.
SELECT COUNT(*)                                             AS qt_br_zero,
       SUM(CASE WHEN TRIM(km) = '0' THEN 1 ELSE 0 END)      AS qt_km_zero,
       SUM(CASE WHEN UPPER(TRIM(sentido_via)) = 'NÃO INFORMADO' THEN 1 ELSE 0 END) AS qt_sentido_ni
  FROM stg_acidente
 WHERE TRIM(br) = '0';


-- Parte 3. Dados duplicados

-- 3.1 Mesmo id em mais de uma linha. Esperado: nenhuma linha.
SELECT id, COUNT(*) AS qt
  FROM stg_acidente
 GROUP BY id
HAVING COUNT(*) > 1;

-- 3.2 Linhas idênticas em todas as colunas, exceto o id (a mesma ocorrência
--     registrada duas vezes com ids diferentes). Esperado: 0.
SELECT COUNT(*) AS qt_grupos_repetidos, NVL(SUM(qt), 0) AS qt_linhas_envolvidas
  FROM (SELECT COUNT(*) AS qt
          FROM stg_acidente
         GROUP BY data_inversa, dia_semana, horario, uf, br,
                  km, municipio, causa_acidente, tipo_acidente, classificacao_acidente,
                  fase_dia, sentido_via, condicao_metereologica, tipo_pista, tracado_via,
                  uso_solo, pessoas, mortos, feridos_leves, feridos_graves,
                  ilesos, ignorados, feridos, veiculos, latitude,
                  longitude, regional, delegacia, uop
        HAVING COUNT(*) > 1);


-- Parte 4. Erros de formato e de conteúdo

-- 4.1 Formatos inválidos. Esperado: 0 em todas as colunas.
SELECT SUM(CASE WHEN NOT REGEXP_LIKE(TRIM(id), '^[0-9]+$') OR id IS NULL
                THEN 1 ELSE 0 END)                                    AS id_invalido,
       SUM(CASE WHEN VALIDATE_CONVERSION(TRIM(data_inversa) AS DATE, 'FXYYYY-MM-DD') = 0
                  OR data_inversa IS NULL THEN 1 ELSE 0 END)          AS data_invalida,
       SUM(CASE WHEN NOT REGEXP_LIKE(TRIM(horario),
                         '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$')
                  OR horario IS NULL THEN 1 ELSE 0 END)               AS horario_invalido,
       SUM(CASE WHEN UPPER(TRIM(uf)) NOT IN ('AC','AL','AP','AM','BA','CE','DF','ES','GO',
                                             'MA','MT','MS','MG','PA','PB','PR','PE','PI',
                                             'RJ','RN','RS','RO','RR','SC','SP','SE','TO')
                  OR uf IS NULL THEN 1 ELSE 0 END)                    AS uf_invalida,
       SUM(CASE WHEN NOT REGEXP_LIKE(TRIM(pessoas)  || ';' || TRIM(mortos)        || ';' ||
                                     TRIM(feridos_leves) || ';' || TRIM(feridos_graves) || ';' ||
                                     TRIM(ilesos)   || ';' || TRIM(ignorados)     || ';' ||
                                     TRIM(feridos)  || ';' || TRIM(veiculos),
                                     '^[0-9]+(;[0-9]+){7}$')
                THEN 1 ELSE 0 END)                                    AS quantidade_invalida
  FROM stg_acidente;

-- 4.2 Classificação ausente ou diferente da obtida pelos contadores
--     (com mortos: Com Vítimas Fatais; com feridos: Com Vítimas Feridas; senão Sem Vítimas).
--     Esperado: 1 linha (id 652519, classificação ausente, 1 morto).
SELECT id, classificacao_acidente, mortos, feridos_leves, feridos_graves
  FROM stg_acidente
 WHERE NVL(TRIM(classificacao_acidente), '#') <>
       CASE WHEN TO_NUMBER(mortos) > 0 THEN 'Com Vítimas Fatais'
            WHEN TO_NUMBER(feridos_leves) + TO_NUMBER(feridos_graves) > 0
                 THEN 'Com Vítimas Feridas'
            ELSE 'Sem Vítimas' END;

-- 4.3 Coordenadas. Esperado: 0 | 0 | 52 | 19 | 41.
--     fora_brasil: fora do retângulo latitude -34 a 6, longitude -74 a -28
--     inteira:     latitude ou longitude sem casas decimais (localização imprecisa)
--     ruido_*:     mais de 10 casas decimais (resíduo de ponto flutuante)
SELECT SUM(CASE WHEN lat IS NULL OR lon IS NULL THEN 1 ELSE 0 END)          AS nao_numerica,
       SUM(CASE WHEN NOT (lat BETWEEN -34 AND 6 AND lon BETWEEN -74 AND -28)
                THEN 1 ELSE 0 END)                                         AS fora_brasil,
       SUM(CASE WHEN lat = TRUNC(lat) OR lon = TRUNC(lon) THEN 1 ELSE 0 END) AS inteira,
       SUM(CASE WHEN LENGTH(REGEXP_SUBSTR(latitude,  '[0-9]+$')) > 10
                 AND INSTR(latitude, ',') > 0 THEN 1 ELSE 0 END)           AS ruido_latitude,
       SUM(CASE WHEN LENGTH(REGEXP_SUBSTR(longitude, '[0-9]+$')) > 10
                 AND INSTR(longitude, ',') > 0 THEN 1 ELSE 0 END)          AS ruido_longitude
  FROM (SELECT latitude, longitude,
               TO_NUMBER(TRIM(latitude)  DEFAULT NULL ON CONVERSION ERROR,
                         '99999D99999999999999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS lat,
               TO_NUMBER(TRIM(longitude) DEFAULT NULL ON CONVERSION ERROR,
                         '99999D99999999999999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS lon
          FROM stg_acidente);


-- Parte 5. Inconsistências entre colunas

-- 5.1 Contadores. Esperado: 3823 | 0 | 0.
--     pessoas_menor:  "pessoas" menor que mortos + feridos + ilesos + ignorados
--     feridos_difere: "feridos" diferente de leves + graves
--     dia_difere:     dia da semana diferente do correspondente à data
SELECT SUM(CASE WHEN TO_NUMBER(pessoas) <
                     TO_NUMBER(mortos) + TO_NUMBER(feridos_leves) + TO_NUMBER(feridos_graves)
                   + TO_NUMBER(ilesos) + TO_NUMBER(ignorados)
                THEN 1 ELSE 0 END)                                         AS pessoas_menor,
       SUM(CASE WHEN TO_NUMBER(feridos) <> TO_NUMBER(feridos_leves) + TO_NUMBER(feridos_graves)
                THEN 1 ELSE 0 END)                                         AS feridos_difere,
       SUM(CASE WHEN LOWER(TRIM(dia_semana)) <>
                     CASE TRUNC(TO_DATE(data_inversa, 'YYYY-MM-DD'))
                        - TRUNC(TO_DATE(data_inversa, 'YYYY-MM-DD'), 'IW') + 1
                          WHEN 1 THEN 'segunda-feira' WHEN 2 THEN 'terça-feira'
                          WHEN 3 THEN 'quarta-feira'  WHEN 4 THEN 'quinta-feira'
                          WHEN 5 THEN 'sexta-feira'   WHEN 6 THEN 'sábado'
                          ELSE 'domingo' END
                THEN 1 ELSE 0 END)                                         AS dia_difere
  FROM stg_acidente;

-- 5.2 O mesmo conjunto de traçado escrito em ordens diferentes.
--     Esperado: 605 textos distintos, que correspondem a 230 combinações (ver script 03).
SELECT COUNT(DISTINCT tracado_via) AS qt_textos_tracado
  FROM stg_acidente;

-- Exemplo do mesmo par em duas grafias. Esperado: Aclive;Reta 1388 | Reta;Aclive 1963.
SELECT tracado_via, COUNT(*) AS qt
  FROM stg_acidente
 WHERE tracado_via IN ('Aclive;Reta', 'Reta;Aclive')
 GROUP BY tracado_via;

-- 5.3 Municípios com o mesmo nome em UFs diferentes. Esperado: 35.
--     Por isso a chave natural da DIM_LOCALIDADE é município + UF.
SELECT COUNT(*) AS qt_municipios_homonimos
  FROM (SELECT municipio
          FROM stg_acidente
         GROUP BY municipio
        HAVING COUNT(DISTINCT uf) > 1);

-- 5.4 Espaços repetidos ou nas extremidades do nome do município. Esperado: 12.
SELECT COUNT(*) AS qt_municipio_espacos
  FROM stg_acidente
 WHERE municipio <> TRIM(REGEXP_REPLACE(municipio, '\s+', ' '));

-- 5.5 Categorias com significado sobreposto ou pouco claro: 'Sol' e 'Céu Claro';
--     uso_solo 'Sim' e 'Não', que no dicionário da PRF significam Urbano e Rural.
SELECT 'condicao_metereologica' AS coluna, condicao_metereologica AS valor, COUNT(*) AS qt
  FROM stg_acidente GROUP BY condicao_metereologica
UNION ALL
SELECT 'uso_solo', uso_solo, COUNT(*)
  FROM stg_acidente GROUP BY uso_solo
 ORDER BY 1, 3 DESC;


-- Parte 6. Problemas estruturais

-- 6.1 Codificação. Esperado: 46375.
--     Resultado 0 indica que o CSV foi importado como UTF-8 em vez de ISO-8859-1.
SELECT COUNT(*) AS qt_ceu_claro
  FROM stg_acidente
 WHERE condicao_metereologica = 'Céu Claro';

-- 6.2 Vírgula como separador decimal, o que impede a conversão direta para NUMBER.
--     Esperado: km 26675 | latitude 72492 | longitude 72485.
SELECT SUM(CASE WHEN INSTR(km, ',')        > 0 THEN 1 ELSE 0 END) AS km_com_virgula,
       SUM(CASE WHEN INSTR(latitude, ',')  > 0 THEN 1 ELSE 0 END) AS latitude_com_virgula,
       SUM(CASE WHEN INSTR(longitude, ',') > 0 THEN 1 ELSE 0 END) AS longitude_com_virgula
  FROM stg_acidente;

-- 6.3 Campo multivalorado (vários valores na mesma célula, separados por ';').
--     Esperado: no máximo 6 itens | 18741 linhas com mais de um item.
SELECT MAX(REGEXP_COUNT(tracado_via, '[^;]+'))                      AS max_itens_tracado,
       SUM(CASE WHEN INSTR(tracado_via, ';') > 0 THEN 1 ELSE 0 END) AS linhas_multivaloradas
  FROM stg_acidente;
