-- 01b_analise_inicial.sql
-- Autor: Vitor Gimenes Magalhães | LAB de Desenvolvimento de BD V, Fatec Bauru
-- Diagnóstico do dado bruto na staging (somente leitura).


-- Visão geral. Esperado: 72529 | 72529 | 01/01/2025 | 31/12/2025
SELECT COUNT(*)                 AS qt_linhas,
       COUNT(DISTINCT id)       AS qt_ids_distintos,
       MIN(TO_DATE(data_inversa DEFAULT NULL ON CONVERSION ERROR, 'FXYYYY-MM-DD')) AS dt_minima,
       MAX(TO_DATE(data_inversa DEFAULT NULL ON CONVERSION ERROR, 'FXYYYY-MM-DD')) AS dt_maxima
  FROM stg_acidente;


-- Faltantes por coluna (nulo, NA, N/A, NULL, Ignorado, Não Informado)
-- Esperado: classificacao 1 | sentido_via 167 | meteorologia 1000 | regional 2 | delegacia 22 | uop 38
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

-- BR 0 (não informada). Esperado: 167 | 167 | 167
SELECT COUNT(*)                                             AS qt_br_zero,
       SUM(CASE WHEN TRIM(km) = '0' THEN 1 ELSE 0 END)      AS qt_km_zero,
       SUM(CASE WHEN UPPER(TRIM(sentido_via)) = 'NÃO INFORMADO' THEN 1 ELSE 0 END) AS qt_sentido_ni
  FROM stg_acidente
 WHERE TRIM(br) = '0';


-- Id repetido. Esperado: nenhuma linha
SELECT id, COUNT(*) AS qt
  FROM stg_acidente
 GROUP BY id
HAVING COUNT(*) > 1;

-- Linhas idênticas com ids diferentes. Esperado: 0
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


-- Formatos inválidos. Esperado: 0 em todas
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

-- Classificação diferente da obtida pelos contadores. Esperado: id 652519 (NA, 1 morto)
SELECT id, classificacao_acidente, mortos, feridos_leves, feridos_graves
  FROM stg_acidente
 WHERE NVL(TRIM(classificacao_acidente), '#') <>
       CASE WHEN TO_NUMBER(mortos) > 0 THEN 'Com Vítimas Fatais'
            WHEN TO_NUMBER(feridos_leves) + TO_NUMBER(feridos_graves) > 0
                 THEN 'Com Vítimas Feridas'
            ELSE 'Sem Vítimas' END;

-- Coordenadas (Brasil: lat -34 a 6, lon -74 a -28). Esperado: 0 | 0 | 52 | 19 | 41
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


-- Inconsistências entre colunas. Esperado: 3823 | 0 | 0
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

-- Traçado escrito em ordens diferentes. Esperado: 605 textos (230 combinações reais)
SELECT COUNT(DISTINCT tracado_via) AS qt_textos_tracado
  FROM stg_acidente;

-- Esperado: Aclive;Reta 1388 | Reta;Aclive 1963
SELECT tracado_via, COUNT(*) AS qt
  FROM stg_acidente
 WHERE tracado_via IN ('Aclive;Reta', 'Reta;Aclive')
 GROUP BY tracado_via;

-- Municípios homônimos em UFs diferentes. Esperado: 35
SELECT COUNT(*) AS qt_municipios_homonimos
  FROM (SELECT municipio
          FROM stg_acidente
         GROUP BY municipio
        HAVING COUNT(DISTINCT uf) > 1);

-- Município com espaços extras. Esperado: 12
SELECT COUNT(*) AS qt_municipio_espacos
  FROM stg_acidente
 WHERE municipio <> TRIM(REGEXP_REPLACE(municipio, '\s+', ' '));

-- Categorias ambíguas ('Sol' x 'Céu Claro'; uso_solo Sim/Não = Urbano/Rural)
SELECT 'condicao_metereologica' AS coluna, condicao_metereologica AS valor, COUNT(*) AS qt
  FROM stg_acidente GROUP BY condicao_metereologica
UNION ALL
SELECT 'uso_solo', uso_solo, COUNT(*)
  FROM stg_acidente GROUP BY uso_solo
 ORDER BY 1, 3 DESC;


-- Codificação. Esperado: 46375
SELECT COUNT(*) AS qt_ceu_claro
  FROM stg_acidente
 WHERE condicao_metereologica = 'Céu Claro';

-- Vírgula decimal. Esperado: 26675 | 72492 | 72485
SELECT SUM(CASE WHEN INSTR(km, ',')        > 0 THEN 1 ELSE 0 END) AS km_com_virgula,
       SUM(CASE WHEN INSTR(latitude, ',')  > 0 THEN 1 ELSE 0 END) AS latitude_com_virgula,
       SUM(CASE WHEN INSTR(longitude, ',') > 0 THEN 1 ELSE 0 END) AS longitude_com_virgula
  FROM stg_acidente;

-- Traçado multivalorado. Esperado: 6 | 18741
SELECT MAX(REGEXP_COUNT(tracado_via, '[^;]+'))                      AS max_itens_tracado,
       SUM(CASE WHEN INSTR(tracado_via, ';') > 0 THEN 1 ELSE 0 END) AS linhas_multivaloradas
  FROM stg_acidente;
