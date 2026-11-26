# Acidentes nas rodovias federais - PRF 2025

Base pública de acidentes da Polícia Rodoviária Federal, tratada e organizada em banco de dados Oracle, com painel de consulta aberto à população.

**Painel:** https://vgimenes132.github.io/LAB5-Acidentes-PRF-2025/

Projeto de Curricularização da Extensão "Transformar Base de Dados Públicas em Banco de Dados Acessível à Sociedade", desenvolvido por Vitor Gimenes Magalhães na disciplina Laboratório de Desenvolvimento de Banco de Dados V (CST em Banco de Dados, Fatec Bauru), sob orientação da Profa. Mariana Rodrigues Santesso, no 2º semestre de 2026.

## Sobre o projeto

A PRF publica como dados abertos todos os acidentes que atende nas rodovias federais. O arquivo é público, mas pouco acessível: é grande, usa códigos e convenções próprias, traz números com vírgula decimal, perde a acentuação quando aberto com a codificação errada e contém alguns erros de origem.

O projeto partiu do arquivo de 2025, com 72.529 ocorrências. Os problemas foram diagnosticados e tratados, os dados foram organizados em um modelo estrela no Oracle e o resultado foi publicado em três formatos: planilha, CSV e um painel interativo. O público-alvo inclui motoristas, órgãos públicos como o DNIT, concessionárias, jornalistas, pesquisadores e estudantes.

## Números de 2025

| Indicador | Valor |
|---|---|
| Acidentes atendidos pela PRF | 72.529 |
| Pessoas mortas | 6.043 |
| Pessoas feridas | 83.550 |
| Mortes a cada 100 acidentes na madrugada / pela manhã | 14,3 / 5,9 |
| Tipo de acidente mais letal | Colisão frontal (39,3 mortes a cada 100) |
| Trecho com mais acidentes | BR-101/SC, km 200 a 210 (575 ocorrências) |

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `dados/original` | Arquivo original da PRF, compactado (ISO-8859-1, separador `;`) |
| `dados/tratados` | Base tratada em `.xlsx` e `.csv`, e o dicionário de dados |
| `scripts_sql` | Scripts Oracle: ambiente, staging, diagnóstico, modelo, carga, views e testes |
| `etapa1_planejamento` | Planejamento, diagnóstico social e seleção da base |
| `etapa2_etl` | Relatório técnico do ETL e relatório para o público |
| `etapa3_modelagem` | Diagramas do modelo, relatório técnico e manual público do banco |
| `etapa4_visualizacao` | Apresentação, relatório extensionista e script que gera os dados do painel |
| `docs` | Painel interativo, publicado pelo GitHub Pages |
| `referencias_prf` | Dicionários de variáveis e anuário oficiais da PRF |

## Como usar a base tratada

Abra `dados/tratados/Acidentes_PRF_2025_tratado.xlsx` no Excel ou no LibreOffice. Cada linha corresponde a um acidente. Para contar acidentes, some a coluna `QT_ACIDENTES`; para contar mortes, some `QT_MORTOS`. As colunas iniciadas por `FL_` são indicadores com os valores S (sim) e N (não). O significado de cada coluna está em `Dicionario_de_Dados.csv`.

As linhas com `FL_INCONSISTENCIA_PESSOAS = S` ou `FL_COORDENADA_IMPRECISA = S` vieram com problemas da própria fonte. Elas foram mantidas e podem ser filtradas conforme a análise.

## Como recriar o banco

O ambiente usado foi o Oracle AI Database 26ai Free (serviço `FREEPDB1`) com o SQL Developer, em uma máquina virtual Oracle Linux 8. A instalação está descrita em `scripts_sql/00_preparacao_ambiente.txt`. No SQL Developer, com o editor configurado em UTF-8, execute os scripts nesta ordem:

1. `01_staging.sql` e, em seguida, a importação do `datatran2025.csv` com codificação ISO-8859-1
2. `01b_analise_inicial.sql`
3. `02_dimensoes_fato.sql`
4. `03_pkg_carga_acidente.sql`, que já executa `pkg_carga_acidente.prc_carregar`
5. `04_views.sql`
6. `05_testes_integridade.sql`

Cada script termina com consultas de conferência e os valores esperados.

## Limitações

A base cobre apenas as rodovias federais atendidas pela PRF; estradas estaduais, municipais e vias urbanas não estão incluídas. O número de acidentes de um estado ou trecho também depende da extensão da malha e do volume de tráfego, por isso mais registros não indicam, por si só, uma rodovia mais perigosa.

## Fonte dos dados

POLÍCIA RODOVIÁRIA FEDERAL (PRF). Dados Abertos da PRF. Disponível em: https://www.gov.br/prf/pt-br/acesso-a-informacao/dados-abertos/dados-abertos-da-prf. Acesso em: 13 set. 2026.
