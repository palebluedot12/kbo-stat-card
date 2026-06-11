# 궤적 프로토타입: 투수1명 구종별 투구 + 최근 홈런 스프레이 → trajectory.js
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$Hd=@{Referer="https://m.sports.naver.com/"}
function J($u){ (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $Hd).Content|ConvertFrom-Json }
# 홈플레이트 통과 높이(z) 물리계산
function PlateZ($p){
  $a=0.5*[double]$p.ay; $b=[double]$p.vy0; $c=[double]$p.y0-[double]$p.crossPlateY
  $disc=$b*$b-4*$a*$c; if($disc -lt 0){return $null}
  $t=(-$b-[math]::Sqrt($disc))/(2*$a); if($t -le 0){ $t=(-$b+[math]::Sqrt($disc))/(2*$a) }
  [math]::Round([double]$p.z0+[double]$p.vz0*$t+0.5*[double]$p.az*$t*$t,2)
}
$dirMap=@{'좌익'=-32;'좌측'=-32;'좌월'=-30;'좌중간'=-16;'중견'=0;'중월'=0;'중앙'=0;'우중간'=16;'우익'=32;'우측'=32;'우월'=30}

# === 투수 1명: 6/10 한화전 (화이트 선발) ===
$gid="20260610HTHH02026"
$pmap=@{}   # pcode -> pitches
foreach($inn in 1..9){
  $rd=(J "https://api-gw.sports.naver.com/schedule/games/$gid/relay?inning=$inn").result.textRelayData
  if(-not $rd.textRelays){continue}
  foreach($e in $rd.textRelays){
    $pits=@($e.textOptions|Where-Object{$_.ptsPitchId}); if(-not $pits.Count){continue}
    $coord=@{}; foreach($o in $e.ptsOptions){ $coord[[string]$o.pitchId]=$o }
    $pc=[string]$e.textOptions[0].currentGameState.pitcher
    if(-not $pmap.ContainsKey($pc)){ $pmap[$pc]=@() }
    foreach($pt in $pits){ $cx=$coord[[string]$pt.ptsPitchId]; if(-not $cx){continue}
      $z=PlateZ $cx; if($null -eq $z){continue}
      $pmap[$pc]+=[pscustomobject]@{ stuff=$pt.stuff; speed=[int]$pt.speed; x=[math]::Round([double]$cx.crossPlateX,2); z=$z; res=$pt.pitchResult; top=[double]$cx.topSz; bot=[double]$cx.bottomSz }
    }
  }
  Start-Sleep -Milliseconds 90
}
$rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData
$pname=@{}; foreach($s in 'away','home'){ foreach($p in $rec.pitchersBoxscore.$s){ $pname[[string]$p.pcode]=$p.name } }
$top=$pmap.GetEnumerator()|Sort-Object{$_.Value.Count} -Descending|Select-Object -First 1
$pitcher=[pscustomobject]@{ name=$pname[$top.Key]; pitches=$top.Value }
Write-Host "투수: $($pitcher.name) 투구 $($pitcher.pitches.Count)개 / 구종: $(($pitcher.pitches.stuff|Select-Object -Unique) -join ',')"

# === 홈런 스프레이: 6/8~6/10 전체 홈런 ===
$hr=@{}
foreach($d in '2026-06-08','2026-06-09','2026-06-10'){
  $games=(J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$d&toDate=$d&size=30").result.games
  foreach($g in $games){ if($g.statusCode -ne 'RESULT'){continue}
    foreach($inn in 1..12){ try{ $rd=(J "https://api-gw.sports.naver.com/schedule/games/$($g.gameId)/relay?inning=$inn").result.textRelayData }catch{continue}
      if(-not $rd.textRelays){continue}
      foreach($e in $rd.textRelays){ foreach($t in $e.textOptions){ if($t.text -and $t.text -match '홈런' -and $t.text -match '홈런거리'){
        $nm=($t.text -split ' : ')[0].Trim()
        $dist=if($t.text -match '홈런거리:(\d+)'){[int]$matches[1]}else{110}
        $deg=0; foreach($k in $dirMap.Keys){ if($t.text -match $k){ $deg=$dirMap[$k]; break } }
        if(-not $hr.ContainsKey($nm)){ $hr[$nm]=@() }
        $hr[$nm]+=[pscustomobject]@{ deg=$deg; dist=$dist; txt=($t.text -replace '\(.*','').Trim() }
      } } }
      Start-Sleep -Milliseconds 80
    }
  }
}
$hitters=@($hr.GetEnumerator()|Sort-Object{$_.Value.Count} -Descending|ForEach-Object{ [pscustomobject]@{ name=$_.Key; hrs=$_.Value } })
Write-Host "홈런 친 선수 $($hitters.Count)명 / 최다: $($hitters[0].name) $($hitters[0].hrs.Count)개"

$out=[ordered]@{ pitcher=$pitcher; hitters=$hitters }
$json=$out|ConvertTo-Json -Depth 6
$root=if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}
[System.IO.File]::WriteAllText("$root/trajectory.js","window.KBO_TRAJ = $json;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "trajectory.js 생성 완료"