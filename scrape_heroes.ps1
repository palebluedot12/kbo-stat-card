# 오늘의 영웅 (경기별): 각 경기 BEST3 + WORST1 → heroes.js / PBP 아카이브
param([string]$Date = "2026-06-09")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$HDR=@{Referer="https://m.sports.naver.com/"}
function J($url){ (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $HDR).Content | ConvertFrom-Json }
$PHOTO="https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle/2026/"
$wc=New-Object System.Net.WebClient

$games = (J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$Date&toDate=$Date&size=30").result.games
Write-Host "[$Date] 경기 $($games.Count)개"

$gamesOut=@(); $pbp=@()
foreach($g in $games){
  $gid=$g.gameId
  if($g.statusCode -ne 'RESULT'){ Write-Host "  $($g.awayTeamName) vs $($g.homeTeamName): 미종료($($g.statusCode)) skip"; continue }
  $awayT=$g.awayTeamName; $homeT=$g.homeTeamName
  Write-Host "  $awayT $($g.awayTeamScore) : $($g.homeTeamScore) $homeT ($gid)"
  try{ $rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData }catch{ Write-Host "    기록없음 skip"; continue }

  $meta=@{}
  foreach($side in 'away','home'){
    $tn=if($side -eq 'away'){$awayT}else{$homeT}
    foreach($b in $rec.battersBoxscore.$side){
      $line="$($b.ab)타수 $($b.hit)안타"; if([int]$b.hr -gt 0){$line+=" $($b.hr)홈런"}; if([int]$b.rbi -gt 0){$line+=" $($b.rbi)타점"}; if([int]$b.sb -gt 0){$line+=" $($b.sb)도루"}
      $meta[[string]$b.playerCode]=@{name=$b.name;team=$tn;kind='타자';line=$line}
    }
    foreach($p in $rec.pitchersBoxscore.$side){
      $dec=if($p.wls){" $($p.wls)"}else{""}
      $meta[[string]$p.pcode]=@{name=$p.name;team=$tn;kind='투수';line="$($p.inn)이닝 $($p.er)자책 $($p.kk)K$dec"}
    }
  }

  $wpa=@{}
  foreach($inn in 1..15){
    try{ $rd=(J "https://api-gw.sports.naver.com/schedule/games/$gid/relay?inning=$inn").result.textRelayData }catch{ continue }
    if(-not $rd.textRelays){ continue }
    foreach($e in $rd.textRelays){
      if($e.metricOption -and $e.textOptions[0].type -eq 8){
        $w=[double]$e.metricOption.wpaByPlate
        $gs=$e.textOptions[0].currentGameState
        $bp=[string]$gs.batter; $pp=[string]$gs.pitcher
        if($bp){ $wpa[$bp]=[math]::Round(($wpa[$bp]+$w),2) }
        if($pp){ $wpa[$pp]=[math]::Round(($wpa[$pp]-$w),2) }
        $pbp += [pscustomobject]@{ gid=$gid; inn=$e.inn; ha=$e.homeOrAway; hs=$gs.homeScore; as=$gs.awayScore; o=$gs.out; b1=$gs.base1; b2=$gs.base2; b3=$gs.base3; bat=$bp; pit=$pp; wpa=$w }
      }
    }
    Start-Sleep -Milliseconds 100
  }

  $ranked = $wpa.GetEnumerator() | Where-Object { $meta.ContainsKey($_.Key) } | Sort-Object Value -Descending
  function Card($kv){
    $m=$meta[$kv.Key]
    $card=[pscustomobject]@{ name=$m.name; team=$m.team; kind=$m.kind; wpa=[math]::Round($kv.Value/100,3); line=$m.line; pid=$kv.Key; photo=($PHOTO+$kv.Key+".jpg") }
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
  $go.best | ForEach-Object { "  BEST {0} {1}({2}) WPA {3} | {4}" -f $_.name,$_.team,$_.kind,$_.wpa,$_.line }
  "  WORST {0} {1}({2}) WPA {3} | {4}" -f $go.worst.name,$go.worst.team,$go.worst.kind,$go.worst.wpa,$go.worst.line
}
Write-Host "PBP: $($pbp.Count) 타석"