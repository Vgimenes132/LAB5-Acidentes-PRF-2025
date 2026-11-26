-- 05_testes_integridade.sql
-- Projeto: Acidentes nas rodovias federais (PRF 2025), LAB BD V, Fatec Bauru
-- Autor: Vitor Gimenes Magalhães (CST em Banco de Dados, LAB de Desenvolvimento de BD V, Profa. Mariana Rodrigues Santesso)
-- Testes de funcionamento e de integridade do banco, depois da carga (03) e das views (04).
-- Executar como script (F5) com o usuário ACIDENTES e SET SERVEROUTPUT ON.
-- Nenhum teste altera dados: os comandos inválidos da parte 5 são desfeitos com ROLLBACK.

SET SERVEROUTPUT ON;


-- 1. Quantidade de linhas por tabela
-- Esperado: DIM_DATA 366, DIM_HORARIO 1441, DIM_LOCALIDADE 1884, DIM_UNIDADE_PRF 417,
-- DIM_CAUSA 70, DIM_TIPO_ACIDENTE 18, DIM_METEOROLOGIA 9, DIM_CONDICAO_VIA 65,
-- DIM_TRACADO 231, FATO_ACIDENTE 72529 (as dimensões incluem o registro 0).
SELECT 'DIM_DATA' AS tabela, COUNT(*) AS qt FROM dim_data          UNION ALL
SELECT 'DIM_HORARIO',        COUNT(*)       FROM dim_horario       UNION ALL
SELECT 'DIM_LOCALIDADE',     COUNT(*)       FROM dim_localidade    UNION ALL
SELECT 'DIM_UNIDADE_PRF',    COUNT(*)       FROM dim_unidade_prf   UNION ALL
SELECT 'DIM_CAUSA',          COUNT(*)       FROM dim_causa         UNION ALL
SELECT 'DIM_TIPO_ACIDENTE',  COUNT(*)       FROM dim_tipo_acidente UNION ALL
SELECT 'DIM_METEOROLOGIA',   COUNT(*)       FROM dim_meteorologia  UNION ALL
SELECT 'DIM_CONDICAO_VIA',   COUNT(*)       FROM dim_condicao_via  UNION ALL
SELECT 'DIM_TRACADO',        COUNT(*)       FROM dim_tracado       UNION ALL
SELECT 'FATO_ACIDENTE',      COUNT(*)       FROM fato_acidente;


-- 2. Totais da fato comparados com a staging
-- Esperado: diferença 0 em todas as colunas.
SELECT s.linhas   - f.linhas   AS dif_linhas,
       s.pessoas  - f.pessoas  AS dif_pessoas,
       s.mortos   - f.mortos   AS dif_mortos,
       s.feridos  - f.feridos  AS dif_feridos,
       s.veiculos - f.veiculos AS dif_veiculos
  FROM (SELECT COUNT(*) AS linhas,
               SUM(TO_NUMBER(pessoas))  AS pessoas,
               SUM(TO_NUMBER(mortos))   AS mortos,
               SUM(TO_NUMBER(feridos))  AS feridos,
               SUM(TO_NUMBER(veiculos)) AS veiculos
          FROM stg_acidente) s
 CROSS JOIN
       (SELECT COUNT(*) AS linhas,
               SUM(qt_pessoas) AS pessoas,
               SUM(qt_mortos)  AS mortos,
               SUM(qt_feridos_leves + qt_feridos_graves) AS feridos,
               SUM(qt_veiculos) AS veiculos
          FROM fato_acidente) f;


-- 3. Restrições declaradas
-- Esperado: 10 chaves primárias (P), 9 estrangeiras (R) e 9 únicas (U) no modelo estrela.
-- O tipo C inclui as regras CHECK e as colunas NOT NULL.
SELECT constraint_type, COUNT(*) AS qt
  FROM user_constraints
 WHERE table_name IN ('FATO_ACIDENTE', 'DIM_DATA', 'DIM_HORARIO', 'DIM_LOCALIDADE',
                      'DIM_UNIDADE_PRF', 'DIM_CAUSA', 'DIM_TIPO_ACIDENTE',
                      'DIM_METEOROLOGIA', 'DIM_CONDICAO_VIA', 'DIM_TRACADO')
 GROUP BY constraint_type
 ORDER BY constraint_type;

-- Esperado: nenhuma linha (todas habilitadas e validadas sobre os dados carregados).
SELECT table_name, constraint_name, status, validated
  FROM user_constraints
 WHERE (table_name LIKE 'DIM\_%' ESCAPE '\' OR table_name = 'FATO_ACIDENTE')
   AND (status <> 'ENABLED' OR validated <> 'VALIDATED');


-- 4. Consistência dos dados carregados
-- 4.1 Linhas da fato sem correspondente em alguma dimensão. Esperado: 0.
--     As chaves estrangeiras já impedem isso; a consulta comprova sobre os dados.
SELECT COUNT(*) AS qt_orfas
  FROM fato_acidente f
 WHERE NOT EXISTS (SELECT 1 FROM dim_data          d WHERE d.sk_data          = f.sk_data)
    OR NOT EXISTS (SELECT 1 FROM dim_horario       d WHERE d.sk_horario       = f.sk_horario)
    OR NOT EXISTS (SELECT 1 FROM dim_localidade    d WHERE d.sk_localidade    = f.sk_localidade)
    OR NOT EXISTS (SELECT 1 FROM dim_unidade_prf   d WHERE d.sk_unidade_prf   = f.sk_unidade_prf)
    OR NOT EXISTS (SELECT 1 FROM dim_causa         d WHERE d.sk_causa         = f.sk_causa)
    OR NOT EXISTS (SELECT 1 FROM dim_tipo_acidente d WHERE d.sk_tipo_acidente = f.sk_tipo_acidente)
    OR NOT EXISTS (SELECT 1 FROM dim_meteorologia  d WHERE d.sk_meteorologia  = f.sk_meteorologia)
    OR NOT EXISTS (SELECT 1 FROM dim_condicao_via  d WHERE d.sk_condicao_via  = f.sk_condicao_via)
    OR NOT EXISTS (SELECT 1 FROM dim_tracado       d WHERE d.sk_tracado       = f.sk_tracado);

-- 4.2 A view VW_ACIDENTE devolve uma linha por ocorrência. Esperado: 72529 | 72529.
SELECT COUNT(*) AS qt_linhas, COUNT(DISTINCT id_ocorrencia) AS qt_ids FROM vw_acidente;

-- 4.3 Traçado: número de itens igual ao número de indicadores 'S'. Esperado: 0.
SELECT COUNT(*) AS qt_divergente
  FROM dim_tracado
 WHERE sk_tracado > 0
   AND qt_itens <> REGEXP_COUNT(fl_aclive || fl_curva || fl_declive || fl_desvio_temporario ||
                                fl_em_obras || fl_intersecao_vias || fl_ponte || fl_reta ||
                                fl_retorno_regulamentado || fl_rotatoria || fl_tunel || fl_viaduto, 'S');

-- 4.4 Calendário completo, sem dias faltando. Esperado: 365 | 01/01/2025 | 31/12/2025 | 0.
SELECT COUNT(*) AS qt_dias, MIN(dt_data) AS inicio, MAX(dt_data) AS fim,
       (MAX(dt_data) - MIN(dt_data) + 1) - COUNT(*) AS dias_faltando
  FROM dim_data
 WHERE sk_data > 0;

-- 4.5 Toda localidade pertence a uma UF válida e tem região. Esperado: 0.
SELECT COUNT(*) AS qt_invalida
  FROM dim_localidade
 WHERE sk_localidade > 0
   AND (pkg_carga_acidente.fn_nome_uf(sg_uf) IS NULL OR nm_regiao = 'Não informado');


-- 5. Testes negativos
-- Cada comando abaixo viola uma regra do modelo e deve ser recusado pelo banco.
-- O bloco executa o comando, confere o código de erro e desfaz qualquer alteração.
-- Esperado: 8 testes OK e 0 falhas.
DECLARE
    v_ok    PLS_INTEGER := 0;
    v_falha PLS_INTEGER := 0;
    v_id    fato_acidente.id_ocorrencia%TYPE;
    v_causa dim_causa.sk_causa%TYPE;

    PROCEDURE testar (p_nome VARCHAR2, p_sql VARCHAR2, p_erro PLS_INTEGER) IS
    BEGIN
        SAVEPOINT sp_teste;
        EXECUTE IMMEDIATE p_sql;
        ROLLBACK TO sp_teste;
        v_falha := v_falha + 1;
        DBMS_OUTPUT.PUT_LINE('FALHA  ' || p_nome || ' (o banco aceitou o comando)');
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK TO sp_teste;
            IF SQLCODE = p_erro THEN
                v_ok := v_ok + 1;
                DBMS_OUTPUT.PUT_LINE('OK     ' || p_nome || ' (ORA' || SQLCODE || ')');
            ELSE
                v_falha := v_falha + 1;
                DBMS_OUTPUT.PUT_LINE('FALHA  ' || p_nome || ': ' || SQLERRM);
            END IF;
    END testar;
BEGIN
    SELECT MIN(id_ocorrencia) INTO v_id FROM fato_acidente;
    SELECT MIN(sk_causa) INTO v_causa FROM fato_acidente WHERE sk_causa > 0;

    testar('Fato com causa inexistente',
           'INSERT INTO fato_acidente (id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
                sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado)
            VALUES (-1, 20250101, 1, 0, 0, 999999, 0, 0, 0, 0)', -2291);

    testar('Fato com data fora do calendário',
           'INSERT INTO fato_acidente (id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
                sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado)
            VALUES (-1, 20240101, 1, 0, 0, 0, 0, 0, 0, 0)', -2291);

    testar('Ocorrência repetida (mesmo id)',
           'INSERT INTO fato_acidente (id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
                sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado)
            VALUES (' || v_id || ', 20250101, 1, 0, 0, 0, 0, 0, 0, 0)', -1);

    testar('Quantidade negativa de mortos',
           'INSERT INTO fato_acidente (id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
                sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado, qt_mortos)
            VALUES (-1, 20250101, 1, 0, 0, 0, 0, 0, 0, 0, -1)', -2290);

    testar('Fato sem data',
           'INSERT INTO fato_acidente (id_ocorrencia, sk_data, sk_horario, sk_localidade, sk_unidade_prf,
                sk_causa, sk_tipo_acidente, sk_meteorologia, sk_condicao_via, sk_tracado)
            VALUES (-1, NULL, 1, 0, 0, 0, 0, 0, 0, 0)', -1400);

    testar('Causa duplicada na dimensão',
           'INSERT INTO dim_causa (ds_causa) SELECT ds_causa FROM dim_causa WHERE sk_causa = ' || v_causa, -1);

    testar('Exclusão de causa usada por acidentes',
           'DELETE FROM dim_causa WHERE sk_causa = ' || v_causa, -2292);

    testar('Indicador de traçado fora de S/N',
           'UPDATE dim_tracado SET fl_curva = ''X'' WHERE sk_tracado = 1', -2290);

    DBMS_OUTPUT.PUT_LINE('---');
    DBMS_OUTPUT.PUT_LINE('Testes OK: ' || v_ok || ' | Falhas: ' || v_falha);
END;
/


-- 6. Consultas de uso (o banco respondendo perguntas reais)
-- 6.1 Gravidade por período do dia.
--     Esperado: Madrugada 14,3 | Manhã 5,9 | Tarde 6,4 | Noite 10,3 mortes a cada 100 acidentes.
SELECT ds_faixa_horaria,
       COUNT(*)                                  AS qt_acidentes,
       SUM(qt_mortos)                            AS qt_mortos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 1) AS mortos_100_acidentes
  FROM vw_acidente
 GROUP BY ds_faixa_horaria, nr_ordem_faixa
 ORDER BY nr_ordem_faixa;

-- 6.2 Os cinco trechos de 10 km com mais acidentes.
--     Esperado no topo: BR-101 / SC, km 200 a 210, com 575 acidentes.
SELECT ds_trecho, qt_acidentes, qt_mortos, qt_feridos
  FROM vw_ind_trecho_br
 WHERE nr_ranking_acidentes <= 5
 ORDER BY nr_ranking_acidentes;

-- 6.3 Acidentes em curva por região, usando o indicador da DIM_TRACADO
--     (filtro simples, sem contar o mesmo acidente duas vezes).
--     Esperado: Sudeste 5449 | Sul 4164 | Nordeste 2155 | Centro-Oeste 967 | Norte 405
--     (total 13140, o mesmo da VW_IND_TRACADO).
SELECT l.nm_regiao,
       COUNT(*)                                  AS qt_acidentes_curva,
       SUM(f.qt_mortos)                          AS qt_mortos,
       ROUND(100 * SUM(f.qt_mortos) / COUNT(*), 1) AS mortos_100_acidentes
  FROM fato_acidente  f
  JOIN dim_tracado    r ON r.sk_tracado    = f.sk_tracado
  JOIN dim_localidade l ON l.sk_localidade = f.sk_localidade
 WHERE r.fl_curva = 'S'
 GROUP BY l.nm_regiao
 ORDER BY qt_acidentes_curva DESC;
