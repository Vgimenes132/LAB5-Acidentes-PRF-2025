-- 03_pkg_carga_acidente.sql
-- Projeto: Acidentes nas rodovias federais (PRF 2025), LAB BD V, Fatec Bauru
-- Autor: Vitor Gimenes Magalhães (CST em Banco de Dados, LAB de Desenvolvimento de BD V, Profa. Mariana Rodrigues Santesso)
-- Limpeza dos dados e carga da staging para as dimensões e a fato.
-- Executar o arquivo inteiro como script (F5), depois dos scripts 01 e 02,
-- com a STG_ACIDENTE já conferida (72.529 linhas).
--
-- Conteúdo, na ordem exigida pelas dependências:
--   Parte 0  Teste da conversão numérica
--   Parte 1  Especificação da package (funções de limpeza e procedure de carga)
--   Parte 2  VW_STG_ACIDENTE_LIMPA, que reúne todas as regras de limpeza
--   Parte 3  Corpo da package (registro de erros, MERGE nas dimensões, fato)
--   Parte 4  Execução
--   Parte 5  Conferência após a carga
--
-- A carga pode ser repetida sem efeitos colaterais:
--   Dimensões: o MERGE insere apenas valores novos, sem apagar nem renumerar,
--              e as chaves ficam estáveis entre cargas.
--   Fato:      é recarregada por completo (DELETE + INSERT) a partir da staging,
--              que sempre contém o arquivo inteiro.
--   Tudo ocorre em uma única transação; qualquer falha desfaz a carga com
--   ROLLBACK. Por isso a fato é esvaziada com DELETE e não com TRUNCATE, que é
--   DDL e faria um COMMIT implícito no meio do processo.
--
-- Registro de problemas (STG_ACIDENTE_ERRO):
--   fl_bloqueante = 'S'  a linha não entra na fato (id, data, horário ou
--                        quantidades inválidos)
--   fl_bloqueante = 'N'  aviso: a linha entra, mas algum valor foi tratado ou
--                        diverge da fonte


-- Parte 0. Teste da conversão numérica
-- A fonte usa vírgula decimal. A conversão informa o separador explicitamente
-- (NLS_NUMERIC_CHARACTERS) e funciona com qualquer configuração regional da sessão.
-- Esperado: -15,5804836399 | -16 | 0 | 123,4 | (null).
-- O SQL Developer pode exibir os valores com ponto ou vírgula, conforme a configuração.
SELECT TO_NUMBER('-15,5804836399' DEFAULT NULL ON CONVERSION ERROR,
                 '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS t1,
       TO_NUMBER('-16'            DEFAULT NULL ON CONVERSION ERROR,
                 '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS t2,
       TO_NUMBER('0'              DEFAULT NULL ON CONVERSION ERROR,
                 '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS t3,
       TO_NUMBER('123,4'          DEFAULT NULL ON CONVERSION ERROR,
                 '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS t4,
       TO_NUMBER('abc'            DEFAULT NULL ON CONVERSION ERROR,
                 '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS t5
  FROM dual;


-- Parte 1. Especificação da package
-- As funções são públicas porque a view de limpeza (parte 2) e as views do
-- script 04 aplicam as mesmas regras; assim cada regra é escrita uma só vez.
CREATE OR REPLACE PACKAGE pkg_carga_acidente AS

    -- Remove espaços nas extremidades e espaços repetidos. Retorna NULL para os
    -- marcadores de ausência da fonte (NA, N/A, NULL, Ignorado, Não Informado),
    -- em maiúsculas ou minúsculas.
    FUNCTION fn_limpa_texto (p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- Normaliza o traçado: itens limpos, sem repetição, em ordem alfabética
    -- binária (independente do NLS_SORT da sessão) e separados por ';'.
    -- 'Reta;Aclive' e 'Aclive;Reta' resultam no mesmo 'Aclive;Reta'.
    FUNCTION fn_normaliza_tracado (p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- Nome do estado e região a partir da sigla; NULL para sigla desconhecida.
    FUNCTION fn_nome_uf (p_sigla IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
    FUNCTION fn_regiao  (p_sigla IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;

    -- Classificação obtida dos contadores, regra que confere com todas as linhas
    -- que têm classificação preenchida na fonte: com mortos, Com Vítimas Fatais;
    -- com feridos, Com Vítimas Feridas; nos demais casos, Sem Vítimas.
    FUNCTION fn_classificacao (p_mortos IN NUMBER, p_feridos IN NUMBER)
        RETURN VARCHAR2 DETERMINISTIC;

    -- Carga completa: registro de erros, dimensões, fato e COMMIT.
    PROCEDURE prc_carregar;

END pkg_carga_acidente;
/


-- Parte 2. View de limpeza
-- Lê a STG_ACIDENTE, sem alterá-la, e devolve cada coluna já tratada. As colunas
-- tx_* guardam o valor original, usado apenas no registro de erros.
--
-- Regras aplicadas:
--   id            somente dígitos; caso contrário NULL (bloqueante)
--   data          formato AAAA-MM-DD; caso contrário NULL (bloqueante)
--   horário       HH:MI ou HH:MI:SS, convertido em minuto do dia + 1;
--                 caso contrário NULL (bloqueante)
--   município     em maiúsculas, sem espaços extras
--   UF            apenas as 27 siglas válidas; caso contrário registro 0
--   unidade PRF   nível ausente vira 'Não informado' apenas naquele nível;
--                 sem os três níveis, registro 0
--   condição via  atributo ausente vira 'Não informado'; uso do solo
--                 Sim = Urbano, Não = Rural, outros valores 'N/I'
--   BR 0          gravada como NULL, assim como o km da mesma linha
--   coordenadas   vírgula decimal; fora do território brasileiro, NULL
--   quantidades   inteiros não negativos; caso contrário a linha é bloqueada
CREATE OR REPLACE VIEW vw_stg_acidente_limpa AS
WITH base AS (
    SELECT
        -- originais (para o log)
        s.id                                            AS id_original,
        s.data_inversa                                  AS tx_data,
        s.dia_semana                                    AS tx_dia_semana,
        s.horario                                       AS tx_horario,
        s.uf                                            AS tx_uf,
        s.km                                            AS tx_km,
        s.latitude                                      AS tx_latitude,
        s.longitude                                     AS tx_longitude,
        s.classificacao_acidente                        AS tx_classificacao,
        s.tracado_via                                   AS tx_tracado,
        'pessoas='  || s.pessoas        || ' mortos='  || s.mortos  ||
        ' leves='   || s.feridos_leves  || ' graves='  || s.feridos_graves ||
        ' ilesos='  || s.ilesos         || ' ignorados=' || s.ignorados ||
        ' veiculos='|| s.veiculos                       AS tx_quantidades,

        -- identificação e tempo
        CASE WHEN REGEXP_LIKE(TRIM(s.id), '^[0-9]+$')
             THEN TO_NUMBER(TRIM(s.id)) END             AS id_ocorrencia,
        TO_DATE(TRIM(s.data_inversa) DEFAULT NULL ON CONVERSION ERROR,
                'FXYYYY-MM-DD')                         AS dt_acidente,
        CASE WHEN REGEXP_LIKE(TRIM(s.horario),
                              '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$')
             THEN TO_NUMBER(SUBSTR(TRIM(s.horario), 1, 2)) * 60
                + TO_NUMBER(SUBSTR(TRIM(s.horario), 4, 2)) + 1
        END                                             AS sk_horario,

        -- localidade
        UPPER(pkg_carga_acidente.fn_limpa_texto(s.municipio)) AS nm_municipio,
        UPPER(pkg_carga_acidente.fn_limpa_texto(s.uf))        AS uf_limpa,

        -- unidade PRF (níveis crus, tratados no SELECT final)
        pkg_carga_acidente.fn_limpa_texto(s.regional)   AS regional_limpa,
        pkg_carga_acidente.fn_limpa_texto(s.delegacia)  AS delegacia_limpa,
        pkg_carga_acidente.fn_limpa_texto(s.uop)        AS uop_limpa,

        -- dimensões de atributo único
        pkg_carga_acidente.fn_limpa_texto(s.causa_acidente)         AS ds_causa,
        pkg_carga_acidente.fn_limpa_texto(s.tipo_acidente)          AS ds_tipo_acidente,
        pkg_carga_acidente.fn_limpa_texto(s.condicao_metereologica) AS ds_meteorologia,

        -- junk dimension
        NVL(pkg_carga_acidente.fn_limpa_texto(s.fase_dia),    'Não informado') AS ds_fase_dia,
        NVL(pkg_carga_acidente.fn_limpa_texto(s.sentido_via), 'Não informado') AS ds_sentido_via,
        NVL(pkg_carga_acidente.fn_limpa_texto(s.tipo_pista),  'Não informado') AS ds_tipo_pista,
        CASE pkg_carga_acidente.fn_limpa_texto(s.uso_solo)
             WHEN 'Sim' THEN 'Urbano'
             WHEN 'Não' THEN 'Rural'
             ELSE 'N/I'
        END                                             AS ds_uso_solo,

        -- traçado
        -- O "(SELECT ... FROM dual)" ativa o cache de subquery escalar do
        -- Oracle: com ~600 textos distintos para 72 mil linhas, a função
        -- roda ~600 vezes em vez de 72 mil.
        (SELECT pkg_carga_acidente.fn_normaliza_tracado(s.tracado_via)
           FROM dual)                                   AS ds_tracado,

        -- atributos numéricos da ocorrência (conversão bruta)
        TO_NUMBER(TRIM(s.br) DEFAULT NULL ON CONVERSION ERROR)  AS nr_br_conv,
        TO_NUMBER(TRIM(s.km) DEFAULT NULL ON CONVERSION ERROR,
                  '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS nr_km_conv,
        TO_NUMBER(TRIM(s.latitude) DEFAULT NULL ON CONVERSION ERROR,
                  '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS nr_lat_conv,
        TO_NUMBER(TRIM(s.longitude) DEFAULT NULL ON CONVERSION ERROR,
                  '99999D9999999999', 'NLS_NUMERIC_CHARACTERS='',.''') AS nr_lon_conv,

        -- medidas
        TO_NUMBER(TRIM(s.pessoas)        DEFAULT NULL ON CONVERSION ERROR) AS qt_pessoas,
        TO_NUMBER(TRIM(s.mortos)         DEFAULT NULL ON CONVERSION ERROR) AS qt_mortos,
        TO_NUMBER(TRIM(s.feridos_leves)  DEFAULT NULL ON CONVERSION ERROR) AS qt_feridos_leves,
        TO_NUMBER(TRIM(s.feridos_graves) DEFAULT NULL ON CONVERSION ERROR) AS qt_feridos_graves,
        TO_NUMBER(TRIM(s.ilesos)         DEFAULT NULL ON CONVERSION ERROR) AS qt_ilesos,
        TO_NUMBER(TRIM(s.ignorados)      DEFAULT NULL ON CONVERSION ERROR) AS qt_ignorados,
        TO_NUMBER(TRIM(s.veiculos)       DEFAULT NULL ON CONVERSION ERROR) AS qt_veiculos,
        TO_NUMBER(TRIM(s.feridos)        DEFAULT NULL ON CONVERSION ERROR) AS qt_feridos_fonte
    FROM stg_acidente s
)
SELECT
    b.id_original, b.tx_data, b.tx_dia_semana, b.tx_horario, b.tx_uf, b.tx_km,
    b.tx_latitude, b.tx_longitude, b.tx_classificacao, b.tx_tracado, b.tx_quantidades,

    b.id_ocorrencia,
    b.dt_acidente,
    CASE WHEN b.dt_acidente IS NOT NULL
         THEN TO_NUMBER(TO_CHAR(b.dt_acidente, 'YYYYMMDD')) END  AS sk_data,
    b.sk_horario,

    b.nm_municipio,
    b.uf_limpa,
    CASE WHEN pkg_carga_acidente.fn_nome_uf(b.uf_limpa) IS NOT NULL
         THEN b.uf_limpa END                                     AS sg_uf,

    CASE WHEN COALESCE(b.regional_limpa, b.delegacia_limpa, b.uop_limpa) IS NOT NULL
         THEN NVL(b.regional_limpa,  'Não informado') END       AS ds_regional,
    CASE WHEN COALESCE(b.regional_limpa, b.delegacia_limpa, b.uop_limpa) IS NOT NULL
         THEN NVL(b.delegacia_limpa, 'Não informado') END       AS ds_delegacia,
    CASE WHEN COALESCE(b.regional_limpa, b.delegacia_limpa, b.uop_limpa) IS NOT NULL
         THEN NVL(b.uop_limpa,       'Não informado') END       AS ds_uop,

    b.ds_causa, b.ds_tipo_acidente, b.ds_meteorologia,
    b.ds_fase_dia, b.ds_sentido_via, b.ds_tipo_pista, b.ds_uso_solo,
    b.ds_tracado,

    b.nr_br_conv,
    NULLIF(b.nr_br_conv, 0)                                      AS nr_br,
    b.nr_km_conv,
    CASE WHEN NULLIF(b.nr_br_conv, 0) IS NOT NULL
         THEN b.nr_km_conv END                                   AS nr_km,
    b.nr_lat_conv,
    b.nr_lon_conv,
    -- caixa do território brasileiro (com folga): lat -34..6, lon -74..-28
    CASE WHEN b.nr_lat_conv BETWEEN -34 AND 6 AND b.nr_lon_conv BETWEEN -74 AND -28
         THEN b.nr_lat_conv END                                  AS nr_latitude,
    CASE WHEN b.nr_lat_conv BETWEEN -34 AND 6 AND b.nr_lon_conv BETWEEN -74 AND -28
         THEN b.nr_lon_conv END                                  AS nr_longitude,

    b.qt_pessoas, b.qt_mortos, b.qt_feridos_leves, b.qt_feridos_graves,
    b.qt_ilesos, b.qt_ignorados, b.qt_veiculos, b.qt_feridos_fonte,
    CASE WHEN b.qt_pessoas        >= 0 AND b.qt_mortos         >= 0
          AND b.qt_feridos_leves  >= 0 AND b.qt_feridos_graves >= 0
          AND b.qt_ilesos         >= 0 AND b.qt_ignorados      >= 0
          AND b.qt_veiculos       >= 0
          AND b.qt_pessoas  = TRUNC(b.qt_pessoas)
          AND b.qt_mortos   = TRUNC(b.qt_mortos)
          AND b.qt_veiculos = TRUNC(b.qt_veiculos)
         THEN 'N' ELSE 'S' END                                   AS fl_qt_invalida
FROM base b;


-- Parte 3. Corpo da package
CREATE OR REPLACE PACKAGE BODY pkg_carga_acidente AS

    -- -
    -- Funções de limpeza (públicas)
    -- -
    FUNCTION fn_limpa_texto (p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        PRAGMA UDF;
        v_valor VARCHAR2(4000);
    BEGIN
        v_valor := TRIM(REGEXP_REPLACE(p_valor, '\s+', ' '));

        IF v_valor IS NULL
           OR UPPER(v_valor) IN ('NA', 'N/A', 'NULL', 'IGNORADO',
                                 'NÃO INFORMADO', 'NAO INFORMADO') THEN
            RETURN NULL;
        END IF;

        RETURN v_valor;
    END fn_limpa_texto;


    FUNCTION fn_normaliza_tracado (p_valor IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        v_resultado VARCHAR2(4000);
    BEGIN
        IF fn_limpa_texto(p_valor) IS NULL THEN
            RETURN NULL;
        END IF;

        SELECT LISTAGG(item, ';') WITHIN GROUP (ORDER BY NLSSORT(item, 'NLS_SORT=BINARY'))
          INTO v_resultado
          FROM (SELECT DISTINCT pkg_carga_acidente.fn_limpa_texto(
                           REGEXP_SUBSTR(p_valor, '[^;]+', 1, LEVEL)) AS item
                  FROM dual
               CONNECT BY LEVEL <= REGEXP_COUNT(p_valor, '[^;]+'))
         WHERE item IS NOT NULL;

        RETURN v_resultado;
    END fn_normaliza_tracado;


    FUNCTION fn_nome_uf (p_sigla IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        PRAGMA UDF;
    BEGIN
        RETURN CASE UPPER(TRIM(p_sigla))
            WHEN 'AC' THEN 'Acre'                WHEN 'AL' THEN 'Alagoas'
            WHEN 'AP' THEN 'Amapá'               WHEN 'AM' THEN 'Amazonas'
            WHEN 'BA' THEN 'Bahia'               WHEN 'CE' THEN 'Ceará'
            WHEN 'DF' THEN 'Distrito Federal'    WHEN 'ES' THEN 'Espírito Santo'
            WHEN 'GO' THEN 'Goiás'               WHEN 'MA' THEN 'Maranhão'
            WHEN 'MT' THEN 'Mato Grosso'         WHEN 'MS' THEN 'Mato Grosso do Sul'
            WHEN 'MG' THEN 'Minas Gerais'        WHEN 'PA' THEN 'Pará'
            WHEN 'PB' THEN 'Paraíba'             WHEN 'PR' THEN 'Paraná'
            WHEN 'PE' THEN 'Pernambuco'          WHEN 'PI' THEN 'Piauí'
            WHEN 'RJ' THEN 'Rio de Janeiro'      WHEN 'RN' THEN 'Rio Grande do Norte'
            WHEN 'RS' THEN 'Rio Grande do Sul'   WHEN 'RO' THEN 'Rondônia'
            WHEN 'RR' THEN 'Roraima'             WHEN 'SC' THEN 'Santa Catarina'
            WHEN 'SP' THEN 'São Paulo'           WHEN 'SE' THEN 'Sergipe'
            WHEN 'TO' THEN 'Tocantins'
        END;
    END fn_nome_uf;


    FUNCTION fn_regiao (p_sigla IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
        PRAGMA UDF;
    BEGIN
        RETURN CASE
            WHEN UPPER(TRIM(p_sigla)) IN ('AC','AM','AP','PA','RO','RR','TO')           THEN 'Norte'
            WHEN UPPER(TRIM(p_sigla)) IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste'
            WHEN UPPER(TRIM(p_sigla)) IN ('DF','GO','MS','MT')                          THEN 'Centro-Oeste'
            WHEN UPPER(TRIM(p_sigla)) IN ('ES','MG','RJ','SP')                          THEN 'Sudeste'
            WHEN UPPER(TRIM(p_sigla)) IN ('PR','RS','SC')                               THEN 'Sul'
        END;
    END fn_regiao;


    FUNCTION fn_classificacao (p_mortos IN NUMBER, p_feridos IN NUMBER)
        RETURN VARCHAR2 DETERMINISTIC IS
        PRAGMA UDF;
    BEGIN
        IF p_mortos IS NULL OR p_feridos IS NULL THEN
            RETURN NULL;
        ELSIF p_mortos > 0 THEN
            RETURN 'Com Vítimas Fatais';
        ELSIF p_feridos > 0 THEN
            RETURN 'Com Vítimas Feridas';
        ELSE
            RETURN 'Sem Vítimas';
        END IF;
    END fn_classificacao;


    -- -
    -- Passo 0: trava de encoding
    -- Se este script ou o 02 foram abertos com codificação errada no
    -- editor, os textos acentuados ('Não informado', 'sábado'...) ficam
    -- corrompidos e as comparações falham em silêncio. Aqui a carga para.
    -- UNISTR monta o texto correto por código Unicode, sem depender do
    -- encoding do arquivo.
    -- -
    PROCEDURE prc_verificar_encoding IS
        v_dia  dim_data.nm_dia_semana%TYPE;
        v_qt   NUMBER;
    BEGIN
        IF 'Não' <> UNISTR('N\00E3o') THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Esta package foi compilada com acentos corrompidos. No SQL Developer: '
                || 'Ferramentas > Preferências > Ambiente > Codificação = UTF-8, '
                || 'reabra o 03_pkg_carga_acidente.sql e rode de novo.');
        END IF;

        BEGIN
            SELECT nm_dia_semana INTO v_dia FROM dim_data WHERE sk_data = 20250104;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'DIM_DATA não tem 04/01/2025. Rode o 02_dimensoes_fato.sql.');
        END;

        IF v_dia <> UNISTR('s\00E1bado') THEN
            RAISE_APPLICATION_ERROR(-20003,
                'DIM_DATA foi gravada com acentos corrompidos (04/01/2025 = "' || v_dia
                || '"). Ajuste a codificação do editor para UTF-8 e rode o 02 de novo.');
        END IF;

        SELECT COUNT(*) INTO v_qt
          FROM stg_acidente
         WHERE condicao_metereologica = UNISTR('C\00E9u Claro');

        IF v_qt = 0 THEN
            RAISE_APPLICATION_ERROR(-20004,
                'STG_ACIDENTE sem "Céu Claro": o CSV foi importado com encoding errado '
                || '(use 1252 / ISO-8859-1) ou a staging está vazia.');
        END IF;
    END prc_verificar_encoding;


    -- -
    -- Passo 1: log de erros e avisos
    -- -
    PROCEDURE prc_registrar_erros IS
    BEGIN
        DELETE FROM stg_acidente_erro;

        -- ---------- BLOQUEANTES
        -- B1. id ausente ou não numérico
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(id_original, 1, 20), 'id', SUBSTR(id_original, 1, 200),
               'Id ausente ou não numérico', 'S'
          FROM vw_stg_acidente_limpa
         WHERE id_ocorrencia IS NULL;

        -- B2. id duplicado (todas as cópias são rejeitadas: não há como
        --     saber qual é a correta)
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(id_original, 1, 20), 'id', SUBSTR(id_original, 1, 200),
               'Id duplicado na staging (' || qt || ' linhas)', 'S'
          FROM (SELECT id_original,
                       COUNT(*) OVER (PARTITION BY id_ocorrencia) AS qt
                  FROM vw_stg_acidente_limpa
                 WHERE id_ocorrencia IS NOT NULL)
         WHERE qt > 1;

        -- B3. data ausente ou inválida
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(id_original, 1, 20), 'data_inversa', SUBSTR(tx_data, 1, 200),
               'Data ausente ou inválida (esperado AAAA-MM-DD)', 'S'
          FROM vw_stg_acidente_limpa
         WHERE dt_acidente IS NULL;

        -- B4. data válida, mas fora do período gerado na DIM_DATA
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(v.id_original, 1, 20), 'data_inversa', SUBSTR(v.tx_data, 1, 200),
               'Data fora do período da DIM_DATA (amplie o INSERT do 02)', 'S'
          FROM vw_stg_acidente_limpa v
         WHERE v.sk_data IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dim_data d WHERE d.sk_data = v.sk_data);

        -- B5. horário ausente ou inválido
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(id_original, 1, 20), 'horario', SUBSTR(tx_horario, 1, 200),
               'Horário ausente ou inválido (esperado HH:MI:SS)', 'S'
          FROM vw_stg_acidente_limpa
         WHERE sk_horario IS NULL;

        -- B6. alguma quantidade ausente, não numérica, negativa ou fracionada
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo, fl_bloqueante)
        SELECT SUBSTR(id_original, 1, 20), 'quantidades', SUBSTR(tx_quantidades, 1, 200),
               'Quantidade ausente, não numérica ou negativa', 'S'
          FROM vw_stg_acidente_limpa
         WHERE fl_qt_invalida = 'S';

        -- ---------- AVISOS (a linha entra na fato)
        -- A1. km preenchido, mas não numérico (gravado como NULL)
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'km', SUBSTR(tx_km, 1, 200),
               'km não numérico (gravado NULL)'
          FROM vw_stg_acidente_limpa
         WHERE pkg_carga_acidente.fn_limpa_texto(tx_km) IS NOT NULL
           AND nr_km_conv IS NULL;

        -- A2. coordenada não numérica
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'latitude/longitude',
               SUBSTR(tx_latitude || ' / ' || tx_longitude, 1, 200),
               'Coordenada não numérica (gravada NULL)'
          FROM vw_stg_acidente_limpa
         WHERE (pkg_carga_acidente.fn_limpa_texto(tx_latitude)  IS NOT NULL AND nr_lat_conv IS NULL)
            OR (pkg_carga_acidente.fn_limpa_texto(tx_longitude) IS NOT NULL AND nr_lon_conv IS NULL);

        -- A3. coordenada numérica, mas fora do Brasil
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'latitude/longitude',
               SUBSTR(tx_latitude || ' / ' || tx_longitude, 1, 200),
               'Coordenada fora do território brasileiro (gravada NULL)'
          FROM vw_stg_acidente_limpa
         WHERE nr_lat_conv IS NOT NULL AND nr_lon_conv IS NOT NULL
           AND nr_latitude IS NULL;

        -- A4. UF preenchida, mas desconhecida (localidade vai para o registro 0)
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'uf', SUBSTR(tx_uf, 1, 200),
               'UF desconhecida (localidade -> Não informado)'
          FROM vw_stg_acidente_limpa
         WHERE uf_limpa IS NOT NULL AND sg_uf IS NULL;

        -- A5. classificação da fonte diverge da regra.
        --     A coluna não é armazenada (é derivada na view), então a
        --     divergência fica registrada aqui. Em 2025: 1 linha ('NA').
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'classificacao_acidente',
               SUBSTR(tx_classificacao, 1, 200),
               'Classificação da fonte difere da regra (calculada: '
               || pkg_carga_acidente.fn_classificacao(qt_mortos,
                                                      qt_feridos_leves + qt_feridos_graves)
               || ')'
          FROM vw_stg_acidente_limpa
         WHERE fl_qt_invalida = 'N'
           AND NVL(TRIM(tx_classificacao), '#')
               <> pkg_carga_acidente.fn_classificacao(qt_mortos,
                                                      qt_feridos_leves + qt_feridos_graves);

        -- A6. coluna "feridos" da fonte difere de leves + graves.
        --     Justifica não armazenar a coluna: se isso aparecer, a fonte
        --     tem informação que a regra não reproduz.
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(id_original, 1, 20), 'feridos', TO_CHAR(qt_feridos_fonte),
               'feridos da fonte difere de leves + graves ('
               || (qt_feridos_leves + qt_feridos_graves) || ')'
          FROM vw_stg_acidente_limpa
         WHERE fl_qt_invalida = 'N'
           AND NVL(qt_feridos_fonte, -1) <> qt_feridos_leves + qt_feridos_graves;

        -- A7. dia da semana da fonte diverge da data
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT SUBSTR(v.id_original, 1, 20), 'dia_semana', SUBSTR(v.tx_dia_semana, 1, 200),
               'Dia da semana da fonte difere da data (' || d.nm_dia_semana || ')'
          FROM vw_stg_acidente_limpa v
          JOIN dim_data d ON d.sk_data = v.sk_data
         WHERE NVL(LOWER(TRIM(v.tx_dia_semana)), '#') <> d.nm_dia_semana;
    END prc_registrar_erros;


    -- -
    -- Passo 2: dimensões (MERGE só insere o que é novo)
    -- -
    PROCEDURE prc_carregar_dimensoes IS
    BEGIN
        MERGE INTO dim_localidade d
        USING (SELECT DISTINCT nm_municipio, sg_uf
                 FROM vw_stg_acidente_limpa
                WHERE nm_municipio IS NOT NULL
                  AND sg_uf        IS NOT NULL) s
           ON (d.nm_municipio = s.nm_municipio AND d.sg_uf = s.sg_uf)
         WHEN NOT MATCHED THEN
              INSERT (nm_municipio, sg_uf, nm_uf, nm_regiao)
              VALUES (s.nm_municipio, s.sg_uf,
                      pkg_carga_acidente.fn_nome_uf(s.sg_uf),
                      pkg_carga_acidente.fn_regiao(s.sg_uf));

        MERGE INTO dim_unidade_prf d
        USING (SELECT DISTINCT ds_regional, ds_delegacia, ds_uop
                 FROM vw_stg_acidente_limpa
                WHERE ds_regional IS NOT NULL) s
           ON (    d.ds_regional  = s.ds_regional
               AND d.ds_delegacia = s.ds_delegacia
               AND d.ds_uop       = s.ds_uop)
         WHEN NOT MATCHED THEN
              INSERT (ds_regional, ds_delegacia, ds_uop)
              VALUES (s.ds_regional, s.ds_delegacia, s.ds_uop);

        MERGE INTO dim_causa d
        USING (SELECT DISTINCT ds_causa FROM vw_stg_acidente_limpa
                WHERE ds_causa IS NOT NULL) s
           ON (d.ds_causa = s.ds_causa)
         WHEN NOT MATCHED THEN INSERT (ds_causa) VALUES (s.ds_causa);

        MERGE INTO dim_tipo_acidente d
        USING (SELECT DISTINCT ds_tipo_acidente FROM vw_stg_acidente_limpa
                WHERE ds_tipo_acidente IS NOT NULL) s
           ON (d.ds_tipo_acidente = s.ds_tipo_acidente)
         WHEN NOT MATCHED THEN INSERT (ds_tipo_acidente) VALUES (s.ds_tipo_acidente);

        MERGE INTO dim_meteorologia d
        USING (SELECT DISTINCT ds_meteorologia FROM vw_stg_acidente_limpa
                WHERE ds_meteorologia IS NOT NULL) s
           ON (d.ds_meteorologia = s.ds_meteorologia)
         WHEN NOT MATCHED THEN INSERT (ds_meteorologia) VALUES (s.ds_meteorologia);

        -- Junk: se todos os atributos vierem ausentes, a combinação coincide
        -- com o membro 0 e o MERGE simplesmente não insere nada.
        MERGE INTO dim_condicao_via d
        USING (SELECT DISTINCT ds_fase_dia, ds_sentido_via, ds_tipo_pista, ds_uso_solo
                 FROM vw_stg_acidente_limpa) s
           ON (    d.ds_fase_dia    = s.ds_fase_dia
               AND d.ds_sentido_via = s.ds_sentido_via
               AND d.ds_tipo_pista  = s.ds_tipo_pista
               AND d.ds_uso_solo    = s.ds_uso_solo)
         WHEN NOT MATCHED THEN
              INSERT (ds_fase_dia, ds_sentido_via, ds_tipo_pista, ds_uso_solo)
              VALUES (s.ds_fase_dia, s.ds_sentido_via, s.ds_tipo_pista, s.ds_uso_solo);

        -- Traçado: a flag é 'S' quando o item aparece na combinação.
        -- Os delimitadores ';' nas pontas evitam falso positivo por substring.
        MERGE INTO dim_tracado d
        USING (SELECT ds_tracado,
                      REGEXP_COUNT(ds_tracado, ';') + 1 AS qt_itens,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Aclive;')                > 0 THEN 'S' ELSE 'N' END AS fl_aclive,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Curva;')                 > 0 THEN 'S' ELSE 'N' END AS fl_curva,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Declive;')               > 0 THEN 'S' ELSE 'N' END AS fl_declive,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Desvio Temporário;')     > 0 THEN 'S' ELSE 'N' END AS fl_desvio_temporario,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Em Obras;')              > 0 THEN 'S' ELSE 'N' END AS fl_em_obras,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Interseção de Vias;')    > 0 THEN 'S' ELSE 'N' END AS fl_intersecao_vias,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Ponte;')                 > 0 THEN 'S' ELSE 'N' END AS fl_ponte,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Reta;')                  > 0 THEN 'S' ELSE 'N' END AS fl_reta,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Retorno Regulamentado;') > 0 THEN 'S' ELSE 'N' END AS fl_retorno_regulamentado,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Rotatória;')             > 0 THEN 'S' ELSE 'N' END AS fl_rotatoria,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Túnel;')                 > 0 THEN 'S' ELSE 'N' END AS fl_tunel,
                      CASE WHEN INSTR(';' || ds_tracado || ';', ';Viaduto;')               > 0 THEN 'S' ELSE 'N' END AS fl_viaduto
                 FROM (SELECT DISTINCT ds_tracado FROM vw_stg_acidente_limpa
                        WHERE ds_tracado IS NOT NULL)) s
           ON (d.ds_tracado = s.ds_tracado)
         WHEN NOT MATCHED THEN
              INSERT (ds_tracado, qt_itens, fl_aclive, fl_curva, fl_declive,
                      fl_desvio_temporario, fl_em_obras, fl_intersecao_vias, fl_ponte,
                      fl_reta, fl_retorno_regulamentado, fl_rotatoria, fl_tunel, fl_viaduto)
              VALUES (s.ds_tracado, s.qt_itens, s.fl_aclive, s.fl_curva, s.fl_declive,
                      s.fl_desvio_temporario, s.fl_em_obras, s.fl_intersecao_vias, s.fl_ponte,
                      s.fl_reta, s.fl_retorno_regulamentado, s.fl_rotatoria, s.fl_tunel, s.fl_viaduto);

        -- A8. aviso: combinação com item fora dos 12 conhecidos
        --     (nº de itens diferente do nº de flags 'S'). Sinal de que um
        --     arquivo novo trouxe um valor de traçado que exige nova flag.
        INSERT INTO stg_acidente_erro (id_ocorrencia, coluna, valor_original, motivo)
        SELECT NULL, 'tracado_via', SUBSTR(ds_tracado, 1, 200),
               'Combinação com item fora da lista de flags da DIM_TRACADO'
          FROM dim_tracado
         WHERE sk_tracado > 0
           AND qt_itens <> REGEXP_COUNT(
                   fl_aclive || fl_curva || fl_declive || fl_desvio_temporario ||
                   fl_em_obras || fl_intersecao_vias || fl_ponte || fl_reta ||
                   fl_retorno_regulamentado || fl_rotatoria || fl_tunel || fl_viaduto, 'S');
    END prc_carregar_dimensoes;


    -- -
    -- Passo 3: fato (recarga completa)
    -- -
    PROCEDURE prc_carregar_fato IS
    BEGIN
        DELETE FROM fato_acidente;

        INSERT INTO fato_acidente (
            id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
            sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado,
            nr_br, nr_km, nr_latitude, nr_longitude,
            qt_pessoas, qt_mortos, qt_feridos_leves, qt_feridos_graves,
            qt_ilesos, qt_ignorados, qt_veiculos)
        SELECT v.id_ocorrencia,
               v.sk_data,
               v.sk_horario,
               NVL(dl.sk_localidade,    0),
               NVL(du.sk_unidade_prf,   0),
               NVL(dc.sk_causa,         0),
               NVL(dt.sk_tipo_acidente, 0),
               NVL(dm.sk_meteorologia,  0),
               NVL(dv.sk_condicao_via,  0),
               NVL(dr.sk_tracado,       0),
               v.nr_br, v.nr_km, v.nr_latitude, v.nr_longitude,
               v.qt_pessoas, v.qt_mortos, v.qt_feridos_leves, v.qt_feridos_graves,
               v.qt_ilesos, v.qt_ignorados, v.qt_veiculos
          FROM vw_stg_acidente_limpa v
          LEFT JOIN dim_localidade    dl ON dl.nm_municipio     = v.nm_municipio
                                        AND dl.sg_uf            = v.sg_uf
          LEFT JOIN dim_unidade_prf   du ON du.ds_regional      = v.ds_regional
                                        AND du.ds_delegacia     = v.ds_delegacia
                                        AND du.ds_uop           = v.ds_uop
          LEFT JOIN dim_causa         dc ON dc.ds_causa         = v.ds_causa
          LEFT JOIN dim_tipo_acidente dt ON dt.ds_tipo_acidente = v.ds_tipo_acidente
          LEFT JOIN dim_meteorologia  dm ON dm.ds_meteorologia  = v.ds_meteorologia
          LEFT JOIN dim_condicao_via  dv ON dv.ds_fase_dia      = v.ds_fase_dia
                                        AND dv.ds_sentido_via   = v.ds_sentido_via
                                        AND dv.ds_tipo_pista    = v.ds_tipo_pista
                                        AND dv.ds_uso_solo      = v.ds_uso_solo
          LEFT JOIN dim_tracado       dr ON dr.ds_tracado       = v.ds_tracado
         WHERE v.id_ocorrencia IS NOT NULL
           AND NOT EXISTS (SELECT 1
                             FROM stg_acidente_erro e
                            WHERE e.fl_bloqueante = 'S'
                              AND e.id_ocorrencia = v.id_original);
    END prc_carregar_fato;


    -- -
    -- Resumo no DBMS_OUTPUT
    -- -
    PROCEDURE prc_resumo IS
        v_stg   NUMBER;
        v_fato  NUMBER;
        v_bloq  NUMBER;
        v_aviso NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_stg  FROM stg_acidente;
        SELECT COUNT(*) INTO v_fato FROM fato_acidente;
        SELECT COUNT(DISTINCT id_ocorrencia) INTO v_bloq
          FROM stg_acidente_erro WHERE fl_bloqueante = 'S';
        SELECT COUNT(*) INTO v_aviso
          FROM stg_acidente_erro WHERE fl_bloqueante = 'N';

        DBMS_OUTPUT.PUT_LINE('===== CARGA CONCLUÍDA =====');
        DBMS_OUTPUT.PUT_LINE('Linhas na staging ......... ' || v_stg);
        DBMS_OUTPUT.PUT_LINE('Linhas carregadas na fato . ' || v_fato);
        DBMS_OUTPUT.PUT_LINE('Ocorrências rejeitadas .... ' || v_bloq);
        DBMS_OUTPUT.PUT_LINE('Avisos registrados ........ ' || v_aviso);
        DBMS_OUTPUT.PUT_LINE('Detalhes: SELECT * FROM stg_acidente_erro;');
    END prc_resumo;


    -- -
    -- Orquestração (pública)
    -- -
    PROCEDURE prc_carregar IS
    BEGIN
        prc_verificar_encoding;
        prc_registrar_erros;
        prc_carregar_dimensoes;
        prc_carregar_fato;
        COMMIT;
        prc_resumo;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('ERRO: carga desfeita (ROLLBACK).');
            DBMS_OUTPUT.PUT_LINE(SQLERRM);
            RAISE;
    END prc_carregar;

END pkg_carga_acidente;
/

-- Se aparecer "Package Body compilado (com erros)", rode para ver o motivo:
-- SELECT line, position, text FROM user_errors
--  WHERE name IN ('PKG_CARGA_ACIDENTE', 'VW_STG_ACIDENTE_LIMPA') ORDER BY name, sequence;


-- Parte 4. Execução
SET SERVEROUTPUT ON;
EXEC pkg_carga_acidente.prc_carregar;


-- Parte 5. Conferência após a carga
-- Valores esperados calculados diretamente do CSV de 2025.

-- 5.1 Registro de erros. Esperado: 0 bloqueantes e 1 aviso
--     (classificação 'NA' do id 652519, calculada como Com Vítimas Fatais).
SELECT fl_bloqueante, coluna, motivo, COUNT(*) AS qt
  FROM stg_acidente_erro
 GROUP BY fl_bloqueante, coluna, motivo
 ORDER BY fl_bloqueante DESC, qt DESC;

-- 5.2 Fato. Esperado: 72529 linhas e os mesmos totais da staging
--     (pessoas 188346 | mortos 6043 | feridos leves + graves 83550 | veículos 144922).
SELECT COUNT(*)                                  AS qt_linhas,
       SUM(qt_pessoas)                           AS pessoas,
       SUM(qt_mortos)                            AS mortos,
       SUM(qt_feridos_leves + qt_feridos_graves) AS feridos,
       SUM(qt_veiculos)                          AS veiculos
  FROM fato_acidente;

-- 5.3 Dimensões (contando o membro 0), esperado:
--     LOCALIDADE 1884 | UNIDADE_PRF 417 | CAUSA 70 | TIPO_ACIDENTE 18
--     METEOROLOGIA 9  | CONDICAO_VIA 65 | TRACADO 231
SELECT 'DIM_LOCALIDADE'    AS tabela, COUNT(*) AS qt FROM dim_localidade    UNION ALL
SELECT 'DIM_UNIDADE_PRF',             COUNT(*)       FROM dim_unidade_prf   UNION ALL
SELECT 'DIM_CAUSA',                   COUNT(*)       FROM dim_causa         UNION ALL
SELECT 'DIM_TIPO_ACIDENTE',           COUNT(*)       FROM dim_tipo_acidente UNION ALL
SELECT 'DIM_METEOROLOGIA',            COUNT(*)       FROM dim_meteorologia  UNION ALL
SELECT 'DIM_CONDICAO_VIA',            COUNT(*)       FROM dim_condicao_via  UNION ALL
SELECT 'DIM_TRACADO',                 COUNT(*)       FROM dim_tracado;

-- 5.4 Uso do membro 0 (Não informado), esperado:
--     meteorologia 1000 ('Ignorado') | unidade PRF 2 | demais 0
SELECT SUM(CASE WHEN sk_meteorologia = 0 THEN 1 ELSE 0 END) AS meteo_0,
       SUM(CASE WHEN sk_unidade_prf  = 0 THEN 1 ELSE 0 END) AS unidade_0,
       SUM(CASE WHEN sk_localidade   = 0 THEN 1 ELSE 0 END) AS localidade_0,
       SUM(CASE WHEN sk_causa        = 0 THEN 1 ELSE 0 END) AS causa_0,
       SUM(CASE WHEN sk_tipo_acidente= 0 THEN 1 ELSE 0 END) AS tipo_0,
       SUM(CASE WHEN sk_tracado      = 0 THEN 1 ELSE 0 END) AS tracado_0,
       SUM(CASE WHEN nr_br IS NULL        THEN 1 ELSE 0 END) AS br_nula      -- esperado 167
  FROM fato_acidente;

-- 5.5 Amostra do traçado normalizado (deve estar em ordem alfabética)
SELECT ds_tracado, qt_itens, fl_curva, fl_reta, fl_aclive, fl_declive
  FROM dim_tracado
 WHERE qt_itens >= 3
 FETCH FIRST 10 ROWS ONLY;
