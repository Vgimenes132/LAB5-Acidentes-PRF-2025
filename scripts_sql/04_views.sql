-- 04_views.sql
-- Projeto: Acidentes nas rodovias federais (PRF 2025), LAB BD V, Fatec Bauru
-- Autor: Vitor Gimenes Magalhães (CST em Banco de Dados, LAB de Desenvolvimento de BD V, Profa. Mariana Rodrigues Santesso)
-- Views de consulta: base tratada, indicadores para gráficos e resumo de qualidade.
-- Executar o arquivo inteiro como script (F5), depois do 03_pkg_carga_acidente.sql.
--
-- VW_ACIDENTE         uma linha por ocorrência, com as descrições das dimensões e
--                     as medidas derivadas. É a base tratada e a origem do CSV publicado.
-- VW_IND_*            indicadores agregados para gráficos. Todas leem da VW_ACIDENTE,
--                     de modo que feridos, classificação e indicadores de qualidade
--                     são calculados em um único ponto.
-- VW_QUALIDADE_DADOS  resumo dos problemas tratados na carga.
--
-- Indicadores:
--   qt_acidentes             número de ocorrências
--   nr_mortos_100_acidentes  mortos a cada 100 acidentes (letalidade)
--   pc_acidentes_fatais      % de ocorrências com ao menos um morto
--   pc_participacao          % sobre o total de acidentes


-- Parte 1. VW_ACIDENTE (base tratada)
CREATE OR REPLACE VIEW vw_acidente AS
SELECT
    f.id_ocorrencia,

    -- quando
    d.dt_data                               AS dt_acidente,
    d.nr_ano,
    d.nr_trimestre,
    d.nr_mes,
    d.nm_mes,
    d.ds_ano_mes,
    d.nr_dia_semana,
    d.nm_dia_semana,
    d.fl_fim_semana,
    h.hr_formatada                          AS hr_acidente,
    h.nr_hora,
    h.ds_faixa_horaria,
    h.nr_ordem_faixa,

    -- onde
    l.nm_regiao,
    l.sg_uf,
    l.nm_uf,
    l.nm_municipio,
    CASE WHEN f.nr_br IS NULL THEN 'Não informada'
         ELSE 'BR-' || LPAD(f.nr_br, 3, '0') END AS ds_br,
    f.nr_br,
    f.nr_km,
    f.nr_latitude,
    f.nr_longitude,

    -- quem atendeu
    u.ds_regional,
    u.ds_delegacia,
    u.ds_uop,

    -- como
    c.ds_causa,
    t.ds_tipo_acidente,
    m.ds_meteorologia,
    v.ds_fase_dia,
    v.ds_sentido_via,
    v.ds_tipo_pista,
    v.ds_uso_solo,
    r.ds_tracado,
    r.fl_aclive, r.fl_curva, r.fl_declive, r.fl_desvio_temporario, r.fl_em_obras,
    r.fl_intersecao_vias, r.fl_ponte, r.fl_reta, r.fl_retorno_regulamentado,
    r.fl_rotatoria, r.fl_tunel, r.fl_viaduto,

    -- medidas armazenadas
    1                                       AS qt_acidentes,
    f.qt_pessoas,
    f.qt_mortos,
    f.qt_feridos_leves,
    f.qt_feridos_graves,
    f.qt_ilesos,
    f.qt_ignorados,
    f.qt_veiculos,

    -- medidas DERIVADAS (não armazenadas na fato)
    f.qt_feridos_leves + f.qt_feridos_graves               AS qt_feridos,
    f.qt_mortos + f.qt_feridos_leves + f.qt_feridos_graves AS qt_vitimas,
    pkg_carga_acidente.fn_classificacao(
        f.qt_mortos, f.qt_feridos_leves + f.qt_feridos_graves) AS ds_classificacao,

    -- flags de qualidade DERIVADAS
    CASE WHEN f.qt_pessoas < f.qt_mortos + f.qt_feridos_leves + f.qt_feridos_graves
                           + f.qt_ilesos + f.qt_ignorados
         THEN 'S' ELSE 'N' END              AS fl_inconsistencia_pessoas,
    CASE WHEN f.nr_latitude  = TRUNC(f.nr_latitude)
           OR f.nr_longitude = TRUNC(f.nr_longitude)
         THEN 'S' ELSE 'N' END              AS fl_coordenada_imprecisa,
    CASE WHEN f.nr_latitude IS NULL OR f.nr_longitude IS NULL
         THEN 'S' ELSE 'N' END              AS fl_coordenada_ausente
FROM fato_acidente       f
JOIN dim_data            d ON d.sk_data          = f.sk_data
JOIN dim_horario         h ON h.sk_horario       = f.sk_horario
JOIN dim_localidade      l ON l.sk_localidade    = f.sk_localidade
JOIN dim_unidade_prf     u ON u.sk_unidade_prf   = f.sk_unidade_prf
JOIN dim_causa           c ON c.sk_causa         = f.sk_causa
JOIN dim_tipo_acidente   t ON t.sk_tipo_acidente = f.sk_tipo_acidente
JOIN dim_meteorologia    m ON m.sk_meteorologia  = f.sk_meteorologia
JOIN dim_condicao_via    v ON v.sk_condicao_via  = f.sk_condicao_via
JOIN dim_tracado         r ON r.sk_tracado       = f.sk_tracado;

COMMENT ON TABLE vw_acidente IS
  'Versão tratada e achatada: 1 linha por ocorrência, com medidas e flags derivadas. Fonte do CSV tratado.';


-- Parte 2. Indicadores para gráficos

-- 2.1 Evolução mensal (gráfico de linha/coluna)
CREATE OR REPLACE VIEW vw_ind_mensal AS
SELECT nr_ano,
       nr_mes,
       ds_ano_mes,
       nm_mes,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       SUM(qt_feridos)                                             AS qt_feridos,
       SUM(qt_veiculos)                                            AS qt_veiculos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes,
       ROUND(100 * SUM(CASE WHEN qt_mortos > 0 THEN 1 ELSE 0 END)
                 / COUNT(*), 2)                                    AS pc_acidentes_fatais
  FROM vw_acidente
 GROUP BY nr_ano, nr_mes, ds_ano_mes, nm_mes;

-- 2.2 Por UF e região (mapa / barras)
CREATE OR REPLACE VIEW vw_ind_uf AS
SELECT nm_regiao,
       sg_uf,
       nm_uf,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       SUM(qt_feridos)                                             AS qt_feridos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 2)           AS pc_participacao,
       RANK() OVER (ORDER BY COUNT(*) DESC)                        AS nr_ranking
  FROM vw_acidente
 GROUP BY nm_regiao, sg_uf, nm_uf;

-- 2.3 Ranking de causas (barras horizontais / Pareto)
CREATE OR REPLACE VIEW vw_ind_causa AS
SELECT ds_causa,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 2)           AS pc_participacao,
       -- acumulado para curva de Pareto (causas em ordem decrescente)
       ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC, ds_causa
                                       ROWS UNBOUNDED PRECEDING)
                 / SUM(COUNT(*)) OVER (), 2)                       AS pc_acumulado,
       RANK() OVER (ORDER BY COUNT(*) DESC)                        AS nr_ranking
  FROM vw_acidente
 GROUP BY ds_causa;

-- 2.4 Tipo de acidente (barras)
CREATE OR REPLACE VIEW vw_ind_tipo_acidente AS
SELECT ds_tipo_acidente,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes,
       ROUND(100 * RATIO_TO_REPORT(COUNT(*)) OVER (), 2)           AS pc_participacao,
       RANK() OVER (ORDER BY COUNT(*) DESC)                        AS nr_ranking
  FROM vw_acidente
 GROUP BY ds_tipo_acidente;

-- 2.5 Dia da semana x hora (mapa de calor: 7 x 24 = 168 células)
CREATE OR REPLACE VIEW vw_ind_semana_hora AS
SELECT nr_dia_semana,
       nm_dia_semana,
       nr_hora,
       ds_faixa_horaria,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos
  FROM vw_acidente
 GROUP BY nr_dia_semana, nm_dia_semana, nr_hora, ds_faixa_horaria;

-- 2.6 Condições: meteorologia x fase do dia (barras agrupadas)
CREATE OR REPLACE VIEW vw_ind_condicoes AS
SELECT ds_meteorologia,
       ds_fase_dia,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes
  FROM vw_acidente
 GROUP BY ds_meteorologia, ds_fase_dia;

-- 2.7 Traçado da via
-- ATENÇÃO: um acidente em "Curva;Declive" conta nas DUAS linhas.
-- Cada linha responde "quantos acidentes tinham este item"; a soma das
-- linhas é MAIOR que o total de acidentes. Não somar esta view.
CREATE OR REPLACE VIEW vw_ind_tracado AS
SELECT ds_item_tracado,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       ROUND(100 * SUM(qt_mortos) / COUNT(*), 2)                   AS nr_mortos_100_acidentes,
       ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM fato_acidente), 2)
                                                                   AS pc_acidentes_com_item
  FROM vw_acidente
UNPIVOT (fl_item FOR ds_item_tracado IN (
            fl_aclive                AS 'Aclive',
            fl_curva                 AS 'Curva',
            fl_declive               AS 'Declive',
            fl_desvio_temporario     AS 'Desvio Temporário',
            fl_em_obras              AS 'Em Obras',
            fl_intersecao_vias       AS 'Interseção de Vias',
            fl_ponte                 AS 'Ponte',
            fl_reta                  AS 'Reta',
            fl_retorno_regulamentado AS 'Retorno Regulamentado',
            fl_rotatoria             AS 'Rotatória',
            fl_tunel                 AS 'Túnel',
            fl_viaduto               AS 'Viaduto'))
 WHERE fl_item = 'S'
 GROUP BY ds_item_tracado;

-- 2.8 Trechos críticos: BR + UF + faixa de 10 km
-- Exclui ocorrências sem BR informada.
CREATE OR REPLACE VIEW vw_ind_trecho_br AS
SELECT ds_br,
       sg_uf,
       FLOOR(nr_km / 10) * 10                                      AS nr_km_inicio,
       FLOOR(nr_km / 10) * 10 + 10                                 AS nr_km_fim,
       ds_br || ' / ' || sg_uf || ' - km ' || (FLOOR(nr_km / 10) * 10)
             || ' a ' || (FLOOR(nr_km / 10) * 10 + 10)             AS ds_trecho,
       COUNT(*)                                                    AS qt_acidentes,
       SUM(qt_mortos)                                              AS qt_mortos,
       SUM(qt_feridos)                                             AS qt_feridos,
       RANK() OVER (ORDER BY COUNT(*) DESC)                        AS nr_ranking_acidentes,
       RANK() OVER (ORDER BY SUM(qt_mortos) DESC)                  AS nr_ranking_mortos
  FROM vw_acidente
 WHERE nr_br IS NOT NULL
   AND nr_km IS NOT NULL
 GROUP BY ds_br, sg_uf, FLOOR(nr_km / 10);


-- Parte 3. Qualidade dos dados
-- Resumo do que foi tratado, no formato indicador e quantidade.
CREATE OR REPLACE VIEW vw_qualidade_dados AS
SELECT 1 AS nr_ordem, 'Linhas na staging (arquivo original)' AS ds_indicador,
       (SELECT COUNT(*) FROM stg_acidente) AS qt FROM dual
UNION ALL
SELECT 2, 'Ocorrências carregadas na fato',
       (SELECT COUNT(*) FROM fato_acidente) FROM dual
UNION ALL
SELECT 3, 'Ocorrências rejeitadas (erro bloqueante)',
       (SELECT COUNT(DISTINCT id_ocorrencia) FROM stg_acidente_erro
         WHERE fl_bloqueante = 'S') FROM dual
UNION ALL
SELECT 4, 'Avisos registrados na carga',
       (SELECT COUNT(*) FROM stg_acidente_erro WHERE fl_bloqueante = 'N') FROM dual
UNION ALL
SELECT 5, 'Pessoas menor que a soma dos envolvidos',
       (SELECT COUNT(*) FROM vw_acidente WHERE fl_inconsistencia_pessoas = 'S') FROM dual
UNION ALL
SELECT 6, 'Coordenada imprecisa (valor inteiro)',
       (SELECT COUNT(*) FROM vw_acidente WHERE fl_coordenada_imprecisa = 'S') FROM dual
UNION ALL
SELECT 7, 'Coordenada ausente ou fora do Brasil',
       (SELECT COUNT(*) FROM vw_acidente WHERE fl_coordenada_ausente = 'S') FROM dual
UNION ALL
SELECT 8, 'BR não informada (BR = 0 na fonte)',
       (SELECT COUNT(*) FROM fato_acidente WHERE nr_br IS NULL) FROM dual
UNION ALL
SELECT 9, 'Condição meteorológica não informada (Ignorado)',
       (SELECT COUNT(*) FROM fato_acidente WHERE sk_meteorologia = 0) FROM dual
UNION ALL
SELECT 10, 'Unidade PRF não informada',
       (SELECT COUNT(*) FROM fato_acidente WHERE sk_unidade_prf = 0) FROM dual
UNION ALL
SELECT 11, 'Traçado: textos distintos na fonte',
       (SELECT COUNT(DISTINCT tracado_via) FROM stg_acidente) FROM dual
UNION ALL
SELECT 12, 'Traçado: combinações reais após normalização',
       (SELECT COUNT(*) FROM dim_tracado WHERE sk_tracado > 0) FROM dual;


-- Parte 4. Exportação da base tratada
--  1. Executar: SELECT * FROM vw_acidente ORDER BY id_ocorrencia;
--  2. Clicar com o botão direito no resultado > Exportar.
--  3. Formato csv, cabeçalho marcado, delimitador ";" e codificação UTF-8.
--     O delimitador deve ser ";" porque, na configuração brasileira, os números
--     saem com vírgula decimal e uma vírgula como delimitador dividiria as coordenadas.
--  4. Salvar como Acidentes_PRF_2025_tratado.csv.


-- Parte 5. Conferência
-- Valores esperados calculados diretamente do CSV de 2025.

-- 5.1 Linhas da base tratada. Esperado: 72529.
SELECT COUNT(*) AS qt FROM vw_acidente;

-- 5.2 Classificação calculada. Esperado: Com Vítimas Feridas 56181 |
--     Sem Vítimas 11138 | Com Vítimas Fatais 5210 (5209 da fonte e a linha 'NA', com 1 morto).
SELECT ds_classificacao, COUNT(*) AS qt
  FROM vw_acidente
 GROUP BY ds_classificacao
 ORDER BY qt DESC;

-- 5.3 Qualidade. Esperado: staging 72529 | fato 72529 | rejeitadas 0 | avisos 1 |
--     pessoas inconsistente 3823 | coordenada imprecisa 52 | coordenada ausente 0 |
--     BR não informada 167 | meteorologia 1000 | unidade 2 |
--     traçado 605 textos e 230 combinações.
SELECT ds_indicador, qt FROM vw_qualidade_dados ORDER BY nr_ordem;

-- 5.4 Mensal. Esperado: 12 linhas; jan/2025 com 5528 acidentes e 418 mortos;
--     mês com mais acidentes, dez/2025 (6788).
SELECT ds_ano_mes, qt_acidentes, qt_mortos, nr_mortos_100_acidentes
  FROM vw_ind_mensal
 ORDER BY ds_ano_mes;

-- 5.5 Três principais causas. Esperado: Ausência de reação do condutor 11469 |
--     Reação tardia ou ineficiente do condutor 10799 |
--     Acessar a via sem observar a presença dos outros veículos 7097.
SELECT nr_ranking, ds_causa, qt_acidentes, pc_participacao, pc_acumulado
  FROM vw_ind_causa
 WHERE nr_ranking <= 3
 ORDER BY nr_ranking;

-- 5.6 Traçado, esperado: Reta 53014 | Curva 13140 | Declive 7912 | Aclive 6057
SELECT ds_item_tracado, qt_acidentes, pc_acidentes_com_item
  FROM vw_ind_tracado
 ORDER BY qt_acidentes DESC;

-- 5.7 Trecho mais crítico, esperado: BR-101 / SC - km 200 a 210 com 575
SELECT ds_trecho, qt_acidentes, qt_mortos
  FROM vw_ind_trecho_br
 WHERE nr_ranking_acidentes <= 5
 ORDER BY nr_ranking_acidentes;
