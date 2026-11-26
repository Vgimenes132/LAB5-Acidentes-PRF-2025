# Autor: Vitor Gimenes Magalhães, projeto de extensão do LAB de Desenvolvimento de BD V (Fatec Bauru).
# Gera o diagrama do modelo lógico (modelo_logico.dot) a partir da estrutura
# definida em scripts_sql/02_dimensoes_fato.sql.
# Uso: python gerar_modelo_logico.py && neato -Tpng -Gdpi=150 modelo_logico.dot -o modelo_logico.png

V = 'VARCHAR2'
FLAGS = ['aclive', 'curva', 'declive', 'desvio_temporario', 'em_obras', 'intersecao_vias',
         'ponte', 'reta', 'retorno_regulamentado', 'rotatoria', 'tunel', 'viaduto']

DIMS = {
    'dim_data': [('PK', 'sk_data', 'NUMBER(8)'), ('UK', 'dt_data', 'DATE'), ('', 'nr_ano', 'NUMBER(4)'),
                 ('', 'nr_semestre', 'NUMBER(1)'), ('', 'nr_trimestre', 'NUMBER(1)'), ('', 'nr_mes', 'NUMBER(2)'),
                 ('NN', 'nm_mes', V + '(15)'), ('', 'nm_mes_abrev', V + '(3)'), ('', 'ds_ano_mes', V + '(7)'),
                 ('', 'nr_dia', 'NUMBER(2)'), ('', 'nr_dia_semana', 'NUMBER(1)'), ('NN', 'nm_dia_semana', V + '(15)'),
                 ('', 'nr_semana_ano', 'NUMBER(2)'), ('NN CK', 'fl_fim_semana', 'CHAR(1)')],
    'dim_horario': [('PK', 'sk_horario', 'NUMBER(4)'), ('', 'nr_hora', 'NUMBER(2)'), ('', 'nr_minuto', 'NUMBER(2)'),
                    ('UK NN', 'hr_formatada', V + '(5)'), ('NN', 'ds_faixa_horaria', V + '(30)'),
                    ('', 'nr_ordem_faixa', 'NUMBER(1)')],
    'dim_causa': [('PK', 'sk_causa', 'NUMBER(6)'), ('UK NN', 'ds_causa', V + '(200)')],
    'dim_tipo_acidente': [('PK', 'sk_tipo_acidente', 'NUMBER(6)'), ('UK NN', 'ds_tipo_acidente', V + '(100)')],
    'dim_meteorologia': [('PK', 'sk_meteorologia', 'NUMBER(6)'), ('UK NN', 'ds_meteorologia', V + '(50)')],
    'dim_localidade': [('PK', 'sk_localidade', 'NUMBER(6)'), ('UK NN', 'nm_municipio', V + '(100)'),
                       ('UK NN', 'sg_uf', V + '(2)'), ('NN', 'nm_uf', V + '(30)'), ('NN', 'nm_regiao', V + '(20)')],
    'dim_unidade_prf': [('PK', 'sk_unidade_prf', 'NUMBER(6)'), ('UK NN', 'ds_regional', V + '(20)'),
                        ('UK NN', 'ds_delegacia', V + '(20)'), ('UK NN', 'ds_uop', V + '(30)')],
    'dim_condicao_via': [('PK', 'sk_condicao_via', 'NUMBER(6)'), ('UK NN', 'ds_fase_dia', V + '(30)'),
                         ('UK NN', 'ds_sentido_via', V + '(30)'), ('UK NN', 'ds_tipo_pista', V + '(30)'),
                         ('UK NN', 'ds_uso_solo', V + '(10)')],
    'dim_tracado': [('PK', 'sk_tracado', 'NUMBER(6)'), ('UK NN', 'ds_tracado', V + '(200)'),
                    ('NN', 'qt_itens', 'NUMBER(2)')] + [('NN CK', 'fl_' + f, 'CHAR(1)') for f in FLAGS],
}

FATO = ([('PK', 'id_ocorrencia', 'NUMBER(10)')]
        + [('FK NN', c, t) for c, t in [('sk_data', 'NUMBER(8)'), ('sk_horario', 'NUMBER(4)'),
                                         ('sk_localidade', 'NUMBER(6)'), ('sk_unidade_prf', 'NUMBER(6)'),
                                         ('sk_causa', 'NUMBER(6)'), ('sk_tipo_acidente', 'NUMBER(6)'),
                                         ('sk_meteorologia', 'NUMBER(6)'), ('sk_condicao_via', 'NUMBER(6)'),
                                         ('sk_tracado', 'NUMBER(6)')]]
        + [('', 'nr_br', 'NUMBER(3)'), ('', 'nr_km', 'NUMBER(6,1)'),
           ('', 'nr_latitude', 'NUMBER(12,10)'), ('', 'nr_longitude', 'NUMBER(12,10)')]
        + [('NN CK', 'qt_' + q, 'NUMBER(4)') for q in
           ['pessoas', 'mortos', 'feridos_leves', 'feridos_graves', 'ilesos', 'ignorados', 'veiculos']]
        + [('NN', 'dt_carga', 'DATE')])

ESQUERDA = ['dim_data', 'dim_horario', 'dim_causa', 'dim_tipo_acidente', 'dim_meteorologia']
DIREITA = ['dim_localidade', 'dim_unidade_prf', 'dim_condicao_via', 'dim_tracado']


def tabela(nome, colunas, cor, x, y):
    linhas = []
    for chave, col, tipo in colunas:
        fundo = '#FFF4CC' if 'PK' in chave else 'white'
        txt_chave = f'<FONT POINT-SIZE="10"><B>{chave}</B></FONT>' if chave else ' '
        txt_col = f'<B>{col}</B>' if 'PK' in chave else col
        linhas.append(f'<TR><TD PORT="{col}_w" ALIGN="LEFT" BGCOLOR="{fundo}">{txt_chave}</TD>'
                      f'<TD ALIGN="LEFT">{txt_col}</TD>'
                      f'<TD PORT="{col}_e" ALIGN="LEFT"><FONT COLOR="#555555">{tipo}</FONT></TD></TR>')
    return (f'{nome} [shape=plain, pos="{x},{y:.2f}!", label=<<TABLE BORDER="1" CELLBORDER="1" '
            f'CELLSPACING="0" CELLPADDING="4" BGCOLOR="white" COLOR="{cor}">'
            f'<TR><TD COLSPAN="3" BGCOLOR="{cor}"><FONT COLOR="white"><B>{nome.upper()}</B></FONT></TD></TR>'
            + ''.join(linhas) + '</TABLE>>];')


def coluna(dims, x, saida):
    altura_linha, espaco = 0.34, 0.55
    total = sum((len(DIMS[d]) + 1) * altura_linha for d in dims) + espaco * (len(dims) - 1)
    y = total / 2
    for d in dims:
        h = (len(DIMS[d]) + 1) * altura_linha
        saida.append(tabela(d, DIMS[d], '#1F4E79', x, y - h / 2))
        y -= h + espaco


saida = ['digraph logico {',
         'layout=neato; splines=true; pad=0.4; bgcolor=white;',
         'label=<<B>Modelo Lógico (esquema estrela, Oracle)</B><BR/><FONT POINT-SIZE="12">'
         'PK chave primária | FK chave estrangeira | UK única | NN obrigatória | CK regra CHECK</FONT>>;',
         'labelloc=t; fontname="DejaVu Sans"; fontsize=20;',
         'node [fontname="DejaVu Sans", fontsize=11];',
         'edge [color="#555555", penwidth=1.4, dir=both, arrowtail=crow, arrowhead=teetee, arrowsize=1.1];',
         tabela('fato_acidente', FATO, '#B5651D', 0, 0)]
coluna(ESQUERDA, -6.2, saida)
coluna(DIREITA, 6.4, saida)
for d in ESQUERDA:
    pk = DIMS[d][0][1]
    saida.append(f'fato_acidente:{pk}_w:w -> {d}:{pk}_e:e;')
for d in DIREITA:
    pk = DIMS[d][0][1]
    saida.append(f'fato_acidente:{pk}_e:e -> {d}:{pk}_w:w;')
saida.append('}')

with open('modelo_logico.dot', 'w', encoding='utf-8') as arq:
    arq.write('\n'.join(saida))
