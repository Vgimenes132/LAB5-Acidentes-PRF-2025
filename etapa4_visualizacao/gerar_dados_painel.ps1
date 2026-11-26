param([string]$Zip, [string]$Saida)
# Agrega a base tratada (VW_ACIDENTE exportada) em indicadores por UF para o painel.
# Autor: Vitor Gimenes Magalhães, projeto de extensão do LAB de Desenvolvimento de BD V (Fatec Bauru).
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName Microsoft.VisualBasic
$inv = [Globalization.CultureInfo]::InvariantCulture

$zipf = [IO.Compression.ZipFile]::OpenRead($Zip)
$p = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($zipf.Entries[0].Open(), [Text.Encoding]::UTF8)
$p.SetDelimiters(';'); $p.HasFieldsEnclosedInQuotes = $true
$cab = $p.ReadFields()
$ix = @{}; for ($k = 0; $k -lt $cab.Length; $k++) { $ix[$cab[$k]] = $k }

function Get-Idx($lista, $mapa, $valor) {
    if (-not $mapa.ContainsKey($valor)) { $mapa[$valor] = $lista.Count; [void]$lista.Add($valor) }
    return $mapa[$valor]
}
$Listas = @{}; $Mapas = @{}
foreach ($d in 'causa','tipo','meteo','fase','pista','muni','br') { $Listas[$d] = New-Object Collections.ArrayList; $Mapas[$d] = @{} }
$flags = 'FL_ACLIVE','FL_CURVA','FL_DECLIVE','FL_DESVIO_TEMPORARIO','FL_EM_OBRAS','FL_INTERSECAO_VIAS','FL_PONTE','FL_RETA','FL_RETORNO_REGULAMENTADO','FL_ROTATORIA','FL_TUNEL','FL_VIADUTO'
$ufMeta = @{}
$PorUf = @{}

function New-Uf {
    $o = @{ tot = [long[]]::new(7); mes = @{}; sh = @{}; causa = @{}; tipo = @{}; meteo = @{}; fase = @{}
            pista = @{}; solo = @{}; trac = @{}; cls = @{}; fds = @{}; trecho = @{}; muni = @{}; grid = @{} }
    return $o
}
function Add-Agg($h, $k, $acid, $mortos, $fer) {
    $v = $h[$k]; if ($null -eq $v) { $v = [long[]]::new(3); $h[$k] = $v }
    $v[0] += $acid; $v[1] += $mortos; $v[2] += $fer
}

$n = 0
while (-not $p.EndOfData) {
    $f = $p.ReadFields(); $n++
    $uf = $f[$ix['SG_UF']]
    if (-not $PorUf.ContainsKey($uf)) { $PorUf[$uf] = New-Uf; $ufMeta[$uf] = @($f[$ix['NM_UF']], $f[$ix['NM_REGIAO']]) }
    $u = $PorUf[$uf]
    $mo = [int]$f[$ix['QT_MORTOS']]; $fe = [int]$f[$ix['QT_FERIDOS']]; $gr = [int]$f[$ix['QT_FERIDOS_GRAVES']]
    $t = $u.tot; $t[0]++; $t[1] += $mo; $t[2] += $fe; $t[3] += $gr; $t[4] += [int]$f[$ix['QT_VEICULOS']]; $t[5] += [int]$f[$ix['QT_PESSOAS']]; if ($mo -gt 0) { $t[6]++ }

    Add-Agg $u.mes ([int]$f[$ix['NR_MES']]) 1 $mo $fe
    Add-Agg $u.sh ((([int]$f[$ix['NR_DIA_SEMANA']]) - 1) * 24 + [int]$f[$ix['NR_HORA']]) 1 $mo $fe
    Add-Agg $u.causa (Get-Idx $Listas.causa $Mapas.causa $f[$ix['DS_CAUSA']]) 1 $mo $fe
    Add-Agg $u.tipo  (Get-Idx $Listas.tipo  $Mapas.tipo  $f[$ix['DS_TIPO_ACIDENTE']]) 1 $mo $fe
    Add-Agg $u.meteo (Get-Idx $Listas.meteo $Mapas.meteo $f[$ix['DS_METEOROLOGIA']]) 1 $mo $fe
    Add-Agg $u.fase  (Get-Idx $Listas.fase  $Mapas.fase  $f[$ix['DS_FASE_DIA']]) 1 $mo $fe
    Add-Agg $u.pista (Get-Idx $Listas.pista $Mapas.pista $f[$ix['DS_TIPO_PISTA']]) 1 $mo $fe
    Add-Agg $u.solo  $f[$ix['DS_USO_SOLO']] 1 $mo $fe
    Add-Agg $u.cls   $f[$ix['DS_CLASSIFICACAO']] 1 $mo $fe
    Add-Agg $u.fds   $f[$ix['FL_FIM_SEMANA']] 1 $mo $fe
    for ($q = 0; $q -lt $flags.Length; $q++) { if ($f[$ix[$flags[$q]]] -eq 'S') { Add-Agg $u.trac $q 1 $mo $fe } }

    $mi = Get-Idx $Listas.muni $Mapas.muni $f[$ix['NM_MUNICIPIO']]
    Add-Agg $u.muni $mi 1 $mo $fe

    $br = $f[$ix['NR_BR']]; $km = $f[$ix['NR_KM']]
    if ($br -ne '' -and $km -ne '') {
        $kmv = [double]::Parse($km.Replace(',', '.'), $inv)
        Add-Agg $u.trecho ("$br|" + ([math]::Floor($kmv / 10) * 10)) 1 $mo $fe
    }
    $la = $f[$ix['NR_LATITUDE']]; $lo = $f[$ix['NR_LONGITUDE']]
    if ($la -ne '' -and $lo -ne '') {
        $gy = [math]::Floor([double]::Parse($la.Replace(',', '.'), $inv) * 10)
        $gx = [math]::Floor([double]::Parse($lo.Replace(',', '.'), $inv) * 10)
        Add-Agg $u.grid "$gy|$gx" 1 $mo $fe
    }
}
$p.Close(); $zipf.Dispose()

# Serialização em JSON compacto, feita manualmente para reduzir o tamanho do arquivo
function Esc([string]$s) { '"' + $s.Replace('\', '\\').Replace('"', '\"') + '"' }
function Lst($a) { '[' + (($a | ForEach-Object { Esc $_ }) -join ',') + ']' }
function Arr3($v) { "[$($v[0]),$($v[1]),$($v[2])]" }
function MapIdx($h) { '[' + (($h.Keys | Sort-Object | ForEach-Object { "[$_,$($h[$_][0]),$($h[$_][1]),$($h[$_][2])]" }) -join ',') + ']' }
function MapTxt($h) { '{' + (($h.Keys | Sort-Object | ForEach-Object { (Esc $_) + ':' + (Arr3 $h[$_]) }) -join ',') + '}' }
function Dense($h, $tam, $base) {
    $o = for ($i = 0; $i -lt $tam; $i++) { $v = $h[$i + $base]; if ($v) { Arr3 $v } else { '[0,0,0]' } }
    '[' + ($o -join ',') + ']'
}

$sb = New-Object Text.StringBuilder
[void]$sb.Append('window.DADOS={')
[void]$sb.Append('"gerado":' + (Esc (Get-Date -Format 'yyyy-MM-dd')) + ',"linhas":' + $n)
foreach ($d in 'causa','tipo','meteo','fase','pista','muni') { [void]$sb.Append(",`"$d`":" + (Lst $Listas[$d])) }
[void]$sb.Append(',"tracado":["Aclive","Curva","Declive","Desvio temporário","Em obras","Interseção de vias","Ponte","Reta","Retorno regulamentado","Rotatória","Túnel","Viaduto"]')
[void]$sb.Append(',"ufs":{')
$prim = $true
foreach ($uf in ($PorUf.Keys | Sort-Object)) {
    $u = $PorUf[$uf]
    if (-not $prim) { [void]$sb.Append(',') }; $prim = $false
    $trechos = ($u.trecho.Keys | ForEach-Object { $k = $_.Split('|'); $v = $u.trecho[$_]; "[$($k[0]),$($k[1]),$($v[0]),$($v[1]),$($v[2])]" }) -join ','
    $grid = ($u.grid.Keys | ForEach-Object { $k = $_.Split('|'); $v = $u.grid[$_]; "[$($k[0]),$($k[1]),$($v[0]),$($v[1])]" }) -join ','
    [void]$sb.Append((Esc $uf) + ':{' +
        '"nome":' + (Esc $ufMeta[$uf][0]) + ',"regiao":' + (Esc $ufMeta[$uf][1]) +
        ',"tot":[' + ($u.tot -join ',') + ']' +
        ',"mes":' + (Dense $u.mes 12 1) +
        ',"sh":' + (Dense $u.sh 168 0) +
        ',"causa":' + (MapIdx $u.causa) + ',"tipo":' + (MapIdx $u.tipo) +
        ',"meteo":' + (MapIdx $u.meteo) + ',"fase":' + (MapIdx $u.fase) + ',"pista":' + (MapIdx $u.pista) +
        ',"trac":' + (MapIdx $u.trac) + ',"muni":' + (MapIdx $u.muni) +
        ',"solo":' + (MapTxt $u.solo) + ',"cls":' + (MapTxt $u.cls) + ',"fds":' + (MapTxt $u.fds) +
        ',"trecho":[' + $trechos + '],"grid":[' + $grid + ']}')
}
[void]$sb.Append('}};')
[IO.File]::WriteAllText($Saida, $sb.ToString(), (New-Object Text.UTF8Encoding($false)))
"Linhas lidas: $n | UFs: $($PorUf.Count) | causas: $($Listas.causa.Count) | municipios: $($Listas.muni.Count) | bytes: $((Get-Item $Saida).Length)"
