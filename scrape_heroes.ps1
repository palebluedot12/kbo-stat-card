# 오늘의 영웅 (경기별): 각 경기 BEST3 + WORST1 → heroes.js / PBP 아카이브
param([string]$Date = "2026-06-09")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$HDR=@{Referer="https://m.sports.naver.com/"}
function J($url){ (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $HDR).Content | ConvertFrom-Json }
$PHOTO="https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle/2026/"
$wc=New-Object System.Net.WebClient

# RE24 표 (KBO 보정) + REa 계산용
$RE=@{}
$RE["000_0"]=0.53;$RE["100_0"]=0.96;$RE["010_0"]=1.22;$RE["001_0"]=1.44;$RE["110_0"]=1.55;$RE["101_0"]=1.75;$RE["011_0"]=2.05;$RE["111_0"]=2.40
$RE["000_1"]=0.28;$RE["100_1"]=0.57;$RE["010_1"]=0.77;$RE["001_1"]=1.14;$RE["110_1"]=0.96;$RE["101_1"]=1.27;$RE["011_1"]=1.45;$RE["111_1"]=1.65
$RE["000_2"]=0.11;$RE["100_2"]=0.23;$RE["010_2"]=0.34;$RE["001_2"]=0.38;$RE["110_2"]=0.48;$RE["101_2"]=0.52;$RE["011_2"]=0.61;$RE["111_2"]=0.80
function REof($b1,$b2,$b3,$o){ if([int]$o -ge 3){return 0.0}; [double]$RE["$b1$b2$b3`_$o"] }
function PInn($s){ $s=[string]$s; $w=0; $f=0.0
  if($s -match '(\d+)'){ $w=[int]$matches[1] }
  if($s.Contains([char]0x2154)){ $f=2.0/3 } elseif($s.Contains([char]0x2153)){ $f=1.0/3 } elseif($s -match '\.([12])$'){ $f=[int]$matches[1]/3.0 }
  return $w+$f }
$lgRA9=5.9   # 투수 REa = (lgRA9/9 × IP) − 실점

$games = (J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$Date&toDate=$Date&size=30").result.games
Write-Host "[$Date] 경기 $($games.Count)개"

$gamesOut=@(); $pbp=@()
foreach($g in $games){
  $gid=$g.gameId
  if($g.statusCode -ne 'RESULT'){ Write-Host "  $($g.awayTeamName) vs $($g.homeTeamName): 미종료($($g.statusCode)) skip"; continue }
  $awayT=$g.awayTeamName; $homeT=$g.homeTeamName
  Write-Host "  $awayT $($g.awayTeamScore) : $($g.homeTeamScore) $homeT ($gid)"
  try{ $rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData }catch{ Write-Host "    기록없음 skip"; continue }

  $meta=@{}; $prea=@{}
  foreach($side in 'away','home'){
    $tn=if($side -eq 'away'){$awayT}else{$homeT}
    foreach($b in $rec.battersBoxscore.$side){
      $line="$($b.ab)타수 $($b.hit)안타"; if([int]$b.hr -gt 0){$line+=" $($b.hr)홈런"}; if([int]$b.rbi -gt 0){$line+=" $($b.rbi)타점"}; if([int]$b.sb -gt 0){$line+=" $($b.sb)도루"}
      $meta[[string]$b.playerCode]=@{name=$b.name;team=$tn;kind='타자';line=$line}
    }
    foreach($p in $rec.pitchersBoxscore.$side){
      $dec=if($p.wls){" $($p.wls)"}else{""}
      $meta[[string]$p.pcode]=@{name=$p.name;team=$tn;kind='투수';line="$($p.inn)이닝 $($p.er)자책 $($p.kk)K$dec"}
      $prea[[string]$p.pcode]=[math]::Round(($lgRA9/9*(PInn $p.inn))-[int]$p.r,2)   # 투수 REa(rate)
    }
  }

  $wpa=@{}; $pas=@()
  foreach($inn in 1..15){
    try{ $rd=(J "https://api-gw.sports.naver.com/schedule/games/$gid/relay?inning=$inn").result.textRelayData }catch{ continue }
    if(-not $rd.textRelays){ continue }
    foreach($e in $rd.textRelays){
      if($e.textOptions[0].type -eq 8){
        $gs=$e.textOptions[0].currentGameState
        $bp=[string]$gs.batter; $pp=[string]$gs.pitcher
        $w=if($e.metricOption){[double]$e.metricOption.wpaByPlate}else{0}
        if($e.metricOption){ if($bp){$wpa[$bp]=[double]$wpa[$bp]+$w}; if($pp){$wpa[$pp]=[double]$wpa[$pp]-$w} }
        $sc=if($e.homeOrAway -eq '1'){[int]$gs.homeScore}else{[int]$gs.awayScore}
        $pas += [pscustomobject]@{ no=[int]$e.no; inn=[int]$e.inn; ha=[string]$e.homeOrAway
          b1=([int]($gs.base1 -ne '0' -and $gs.base1 -ne '')); b2=([int]($gs.base2 -ne '0' -and $gs.base2 -ne '')); b3=([int]($gs.base3 -ne '0' -and $gs.base3 -ne '')); o=[int]$gs.out
          bsc=$sc; bat=$bp; pit=$pp }
        $pbp += [pscustomobject]@{ gid=$gid; inn=$e.inn; ha=$e.homeOrAway; hs=$gs.homeScore; as=$gs.awayScore; o=$gs.out; b1=$gs.base1; b2=$gs.base2; b3=$gs.base3; bat=$bp; pit=$pp; wpa=$w }
      }
    }
    Start-Sleep -Milliseconds 100
  }

  # REa (RE24 자체계산)
  $rea=@{}
  $pasS=@($pas|Sort-Object no)
  foreach($team in '0','1'){
    $seq=@($pasS|Where-Object{$_.ha -eq $team})
    $final=if($team -eq '1'){[int]$g.homeTeamScore}else{[int]$g.awayTeamScore}
    for($i=0;$i -lt $seq.Count;$i++){
      $p=$seq[$i]; $before=REof $p.b1 $p.b2 $p.b3 $p.o
      if($i -lt $seq.Count-1){ $n=$seq[$i+1]; $runs=$n.bsc-$p.bsc; $after=if($n.inn -eq $p.inn){REof $n.b1 $n.b2 $n.b3 $n.o}else{0.0} }
      else{ $runs=$final-$p.bsc; $after=0.0 }
      $v=$after+$runs-$before
      if($p.bat){ $rea[$p.bat]=[double]$rea[$p.bat]+$v }   # 타자만 RE24
    }
  }
  foreach($k in $prea.Keys){ $rea[$k]=$prea[$k] }   # 투수는 rate 방식으로 덮어씀

  $ranked = $rea.GetEnumerator() | Where-Object { $meta.ContainsKey($_.Key) } | Sort-Object Value -Descending
  function Card($kv){
    $m=$meta[$kv.Key]
    $card=[pscustomobject]@{ name=$m.name; team=$m.team; kind=$m.kind; rea=[math]::Round($kv.Value,2); wpa=[math]::Round([double]$wpa[$kv.Key]/100,3); line=$m.line; pid=$kv.Key; photo=($PHOTO+$kv.Key+".jpg") }
    try{ $b=$wc.DownloadData($card.photo); if($b.Length -gt 800){ $card.photo="data:image/jpeg;base64,"+[Convert]::ToBase64String($b) } }catch{}
    return $card
  }
  $best  = @($ranked | Select-Object -First 3 | ForEach-Object { Card $_ })
  $worst = Card ($ranked | Select-Object -Last 1)

  $gamesOut += [pscustomobject]@{
    gid=$gid; away=$awayT; home=$homeT
    awayScore=[int]$g.awayTeamScore; homeScore=[int]$g.homeTeamScore
    best=$best; worst=$worst
  }
}

$out=[ordered]@{ date=$Date; games=$gamesOut }
$json=$out|ConvertTo-Json -Depth 7
$root = if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}
[System.IO.File]::WriteAllText("$root/heroes.js","window.KBO_HEROES = $json;",(New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText("$root/pbp_$Date.json",($pbp|ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding $false))

Write-Host ""
foreach($go in $gamesOut){
  Write-Host "=== $($go.away) $($go.awayScore) : $($go.homeScore) $($go.home) ==="
  $go.best | ForEach-Object { "  BEST {0} {1}({2}) REa {3} (WPA {4}) | {5}" -f $_.name,$_.team,$_.kind,$_.rea,$_.wpa,$_.line }
  "  WORST {0} {1}({2}) REa {3} | {4}" -f $go.worst.name,$go.worst.team,$go.worst.kind,$go.worst.rea,$go.worst.line
}
Write-Host "PBP: $($pbp.Count) 타석"