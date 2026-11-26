# Etapa 4 - Visualização, Publicação e Divulgação

Entrega em 28/11/2026, junto com a Etapa 3. Peso de 50% na média.

## Painel público

https://vgimenes132.github.io/LAB5-Acidentes-PRF-2025/

O painel fica na pasta `docs/` da raiz do repositório e é publicado pelo GitHub Pages a partir da branch `main`. Os indicadores podem ser vistos para o Brasil ou para um estado:

- resumo com acidentes, mortes, feridos, mortes a cada 100 acidentes e percentual de acidentes com morte;
- destaques gerados a partir dos dados: mês e horário com mais ocorrências, gravidade na madrugada, causa principal, tipo mais letal e trecho mais crítico;
- distribuição no tempo: acidentes por mês, mapa de calor por dia da semana e hora, gravidade por período do dia e comparação entre fim de semana e dias úteis;
- distribuição no espaço: mapa de pontos, ranking de estados ou municípios, os dez trechos de 10 km com mais acidentes e busca por município;
- circunstâncias: causas, tipos de acidente, tipos mais letais, condição do tempo e traçado da via;
- links para baixar a planilha, o CSV e o dicionário de dados.

Todos os gráficos alternam entre acidentes e mortes e têm uma versão em tabela, para leitores de tela. A página funciona no celular, tem tema claro e escuro e não depende de servidor nem de bibliotecas externas. O endereço com `#SP` no final, por exemplo, abre o painel já filtrado em São Paulo.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `docs/index.html` | Página do painel |
| `docs/painel.js` | Código dos gráficos, em JavaScript sem bibliotecas |
| `docs/dados.js` | Indicadores agregados por estado, gerados a partir da base tratada |
| `gerar_dados_painel.ps1` | Script que lê `Acidentes_PRF_2025_tratado.csv.zip` e gera o `docs/dados.js` |
| `apresentacao/Apresentacao_Acidentes_PRF_2025.pdf` (e `.pptx`) | Apresentação do projeto em 14 slides, com notas do apresentador no `.pptx` |
| `relatorios/Relatorio_Extensionista_Etapa4.pdf` (e `.docx`) | Relatório extensionista: público beneficiado, ações, resultados e relevância social |

## Conferência dos dados

Os totais do `dados.js` foram comparados com os valores esperados das consultas de conferência do `04_views.sql`: 72.529 acidentes, 6.043 mortos, 83.550 feridos, 144.922 veículos, 188.346 pessoas e 5.210 acidentes com morte; janeiro com 5.528 acidentes e 418 mortos; dezembro com 6.788 acidentes; as mesmas três causas principais; e o trecho da BR-101/SC entre os km 200 e 210, com 575 ocorrências.

## Atualização dos dados do painel

No PowerShell, a partir da raiz do repositório:

```powershell
.\etapa4_visualizacao\gerar_dados_painel.ps1 -Zip .\dados\tratados\Acidentes_PRF_2025_tratado.csv.zip -Saida .\docs\dados.js
```

Depois de enviar o novo `dados.js` para a branch `main`, o GitHub Pages atualiza o painel em um ou dois minutos.
