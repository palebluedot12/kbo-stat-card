# 오늘의 영웅: 하루 전체 경기 → 선수별 WPA 합산 → Top3 + 최악 + PBP 아카이브
param([string]$Date = "2026-06-09")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$H=@{Referer="https://m.sports.naver.com/"}
function J($url){ (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $H).Content | ConvertFrom-Json }
$PHOTO="https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle/2026/"

# 1) 그날 경기 목록
$games = (J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$Date&toDate=$Date&size=30").result.games
Write-Host "[$Date] 경기 $($games.Count)개"

$wpa=@{}; $meta=@{}; $pbp=@()
foreach($g in $games){
  $gid=$g.gameId
  $awayT=$g.awayTeamName; $homeT=$g.homeTeamName
  Write-Host "  $awayT vs $homeT ($gid) ..."
  try{ $rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData }catch{ Write-Host "    기록없음 skip"; continue }
  # 박스스코어 -> 기록줄
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
  # 릴레이 전 이닝 -> WPA 합산 + PBP 저장
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
    Start-Sleep -Milliseconds 120
  }
}

# 2) 랭킹
$ranked = $wpa.GetEnumerator() | Where-Object { $meta.ContainsKey($_.Key) } | Sort-Object Value -Descending
function Card($kv){
  $m=$meta[$kv.Key]
  [pscustomobject]@{ name=$m.name; team=$m.team; kind=$m.kind; wpa=[math]::Round($kv.Value/100,3); line=$m.line; pid=$kv.Key; photo=($PHOTO+$kv.Key+".jpg") }
}
$heroes = @($ranked | Select-Object -First 3 | ForEach-Object { Card $_ })
$villain = Card ($ranked | Select-Object -Last 1)

# 3) 영웅/최악 사진만 base64 임베드 (PNG 추출용)
$wc=New-Object System.Net.WebClient
foreach($c in ($heroes + $villain)){
  try{ $b=$wc.DownloadData($c.photo); if($b.Length -gt 800){ $c.photo="data:image/jpeg;base64,"+[Convert]::ToBase64String($b) } }catch{}
}

$out=[ordered]@{ date=$Date; heroes=$heroes; villain=$villain }
$json=$out|ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("H:\KBOWEB\heroes.js","window.KBO_HEROES = $json;",(New-Object System.Text.UTF8Encoding $false))
# PBP 아카이브 (미래 자체계산용)
[System.IO.File]::WriteAllText("H:\KBOWEB\pbp_$Date.json",($pbp|ConvertTo-Json -Compress),(New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "=== $Date 오늘의 영웅 ==="
$heroes | ForEach-Object { "  {0} {1} ({2}) WPA {3} | {4}" -f $_.name,$_.team,$_.kind,$_.wpa,$_.line }
Write-Host "=== 최악 ==="
"  {0} {1} ({2}) WPA {3} | {4}" -f $villain.name,$villain.team,$villain.kind,$villain.wpa,$villain.line
Write-Host "PBP 아카이브: $($pbp.Count) 타석"