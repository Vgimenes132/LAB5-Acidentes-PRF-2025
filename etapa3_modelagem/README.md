# Etapa 3 - Modelagem e Implementação do Banco de Dados

Entrega em 28/11/2026, junto com a Etapa 4. Peso de 30% na média.

## Conteúdo

| Arquivo | Descrição |
|---|---|
| `relatorios/Relatorio_Tecnico_Etapa3_Modelagem.pdf` (e `.docx`) | Documentação técnica: requisitos, modelos conceitual e lógico, decisões de projeto, implementação e testes |
| `relatorios/Manual_Publico_Banco_de_Dados.pdf` (e `.docx`) | Manual simplificado para o público externo |
| `diagramas/modelo_conceitual.png` | Modelo conceitual (Diagrama ER, notação de Chen) |
| `diagramas/modelo_logico.png` | Modelo lógico com as 10 tabelas do Oracle, colunas, tipos e chaves |
| `evidencias/` | Capturas do SQL Developer com a execução do `05_testes_integridade.sql` (24/11/2026) |

Os scripts de criação, carga e teste do banco estão em `../scripts_sql`. A estrutura das tabelas está em `02_dimensoes_fato.sql`, e os testes de integridade em `05_testes_integridade.sql`.

## Diagramas

As versões `.svg` têm a mesma imagem em formato vetorial. Os arquivos `.dot` são o código-fonte dos diagramas no Graphviz; o do modelo lógico é gerado por `gerar_modelo_logico.py`:

```
python gerar_modelo_logico.py
neato -Tpng -Gdpi=150 modelo_logico.dot -o modelo_logico.png
dot -Tpng -Gdpi=150 modelo_conceitual.dot -o modelo_conceitual.png
```

No modelo conceitual, retângulos são entidades, losangos são relacionamentos e elipses são atributos (sublinhados quando identificam a entidade). A cardinalidade de todos os relacionamentos é 1:N: cada acidente tem uma data, uma causa, um local etc., e cada um desses elementos pode estar associado a vários acidentes.

No modelo lógico, a tabela `FATO_ACIDENTE` fica no centro, com uma linha por acidente, e as nove dimensões (`DIM_*`) ficam ao redor. Nas ligações, o pé de galinha indica o lado "muitos" (fato) e os dois traços, o lado "exatamente um" (dimensão). Toda dimensão tem um registro de chave 0, "Não informado", para que nenhuma chave da fato fique vazia.
