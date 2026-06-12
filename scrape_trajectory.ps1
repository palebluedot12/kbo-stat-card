# 궤적 데이터 (pid 기반)
#  - 투수 구종별 투구위치 → trajectory.js (최근 WindowDays일 롤링, 매번 새로 덮어씀)
#  - 타자 홈런 스프레이   → traj_hr.js   (시즌 전체 누적, 매일 병합·중복제거)
# 사용:
#   데일리   : ./scrape_trajectory.ps1                 (어제 포함 최근 10일)
#   HR백필   : ./scrape_trajectory.ps1 -From 2026-03-20 -To 2026-06-11 -HrOnly
param([string]$From,[string]$To,[switch]$HrOnly,[int]$WindowDays=10)
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$Hd=@{Referer="https://m.sports.naver.com/"}
function J($u){ (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $Hd).Content|ConvertFrom-Json }
function PlateZ($p){ $a=0.5*[double]$p.ay; $b=[double]$p.vy0; $c=[double]$p.y0-[double]$p.crossPlateY
  $disc=$b*$b-4*$a*$c; if($disc -lt 0){return $null}; $t=(-$b-[math]::Sqrt($disc))/(2*$a); if($t -le 0){$t=(-$b+[math]::Sqrt($disc))/(2*$a)}
  [math]::Round([double]$p.z0+[double]$p.vz0*$t+0.5*[double]$p.az*$t*$t,2) }
$dirMap=@{'좌익'=-33;'좌측'=-33;'좌월'=-30;'좌중간'=-16;'중견'=0;'중월'=0;'중앙'=0;'우중간'=16;'우익'=33;'우측'=33;'우월'=30}
$root=if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}

# 날짜 기본값: To=어제(KST), From=To-(WindowDays-1)
if(-not $To){ $To=(Get-Date).ToUniversalTime().AddHours(9).AddDays(-1).ToString('yyyy-MM-dd') }
if(-not $From){ $From=([datetime]::ParseExact($To,'yyyy-MM-dd',$null)).AddDays(-1*($WindowDays-1)).ToString('yyyy-MM-dd') }
Write-Host "scrape_trajectory: $From ~ $To (HrOnly=$HrOnly)"

# ── 기존 누적 홈런 로드 (작은 파일, 안전하게 파싱) ──
$exHit=@{}; $exFrom=$To; $exTo=$To; $seen=@{}
$hrPath="$root/traj_hr.js"
if(Test-Path $hrPath){
  $raw=[System.IO.File]::ReadAllText($hrPath)
  $j=$raw.Substring($raw.IndexOf('=')+1).TrimEnd().TrimEnd(';')|ConvertFrom-Json
  if($j.from){$exFrom=[string]$j.from}; if($j.to){$exTo=[string]$j.to}
  foreach($pp in $j.hitters.PSObject.Properties){
    $arr=[System.Collections.ArrayList]@(); foreach($h in $pp.Value.hrs){ [void]$arr.Add([pscustomobject]@{deg=[int]$h.deg;dist=[int]$h.dist;d=[string]$h.d}); $seen["$($pp.Name)|$($h.d)|$($h.deg)|$($h.dist)"]=$true }
    $exHit[$pp.Name]=@{ name=[string]$pp.Value.name; hrs=$arr }
  }
  Write-Host "  기존 홈런타자 $($exHit.Count)명 로드 ($exFrom~$exTo)"
}

$pit=@{}; $pnm=@{}
$d=[datetime]::ParseExact($From,'yyyy-MM-dd',$null); $end=[datetime]::ParseExact($To,'yyyy-MM-dd',$null)
for(; $d -le $end; $d=$d.AddDays(1)){
  $ds=$d.ToString('yyyy-MM-dd')
  $games=(J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$ds&toDate=$ds&size=30").result.games
  foreach($g in $games){ if($g.statusCode -ne 'RESULT'){continue}
    $gid=$g.gameId
    foreach($inn in 1..12){ try{ $rd=(J "https://api-gw.sports.naver.com/schedule/games/$gid/relay?inning=$inn").result.textRelayData }catch{continue}
      if(-not $rd.textRelays){continue}
      foreach($e in $rd.textRelays){
        # 투수 구종별 투구 (HrOnly면 스킵)
        if(-not $HrOnly){
          $pits=@($e.textOptions|Where-Object{$_.ptsPitchId})
          if($pits.Count){
            $coord=@{}; foreach($o in $e.ptsOptions){ $coord[[string]$o.pitchId]=$o }
            $pc=[string]$e.textOptions[0].currentGameState.pitcher
            if(-not $pit.ContainsKey($pc)){ $pit[$pc]=[System.Collections.ArrayList]@() }
            foreach($pt in $pits){ $cx=$coord[[string]$pt.ptsPitchId]; if(-not $cx){continue}; $z=PlateZ $cx; if($null -eq $z){continue}
              [void]$pit[$pc].Add([pscustomobject]@{ s=$pt.stuff; x=[math]::Round([double]$cx.crossPlateX,2); z=$z; v=[int]$pt.speed; r=$pt.pitchResult }) }
          }
        }
        # 타자 홈런 (시즌 누적·중복제거)
        foreach($t in $e.textOptions){ if($t.text -and $t.text -match '홈런' -and $t.text -match '홈런거리'){
          $bc=[string]$e.textOptions[0].currentGameState.batter
          $dist=if($t.text -match '홈런거리:(\d+)'){[int]$matches[1]}else{110}
          $deg=0; foreach($k in $dirMap.Keys){ if($t.text -match $k){ $deg=$dirMap[$k]; break } }
          $key="$bc|$ds|$deg|$dist"
          if(-not $seen.ContainsKey($key)){
            if(-not $exHit.ContainsKey($bc)){ $exHit[$bc]=@{ name=$null; hrs=[System.Collections.ArrayList]@() } }
            [void]$exHit[$bc].hrs.Add([pscustomobject]@{ deg=$deg; dist=$dist; d=$ds }); $seen[$key]=$true
          }
        } }
      }
      Start-Sleep -Milliseconds 70
    }
    # 이름 매핑
    try{ $rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData
      foreach($s in 'away','home'){ foreach($p in $rec.pitchersBoxscore.$s){ $pnm[[string]$p.pcode]=$p.name }; foreach($b in $rec.battersBoxscore.$s){ $pnm[[string]$b.playerCode]=$b.name } } }catch{}
  }
  Write-Host "  $ds 처리 (투수 $($pit.Count) / 누적홈런타자 $($exHit.Count))"
}
# 이름 채우기
foreach($k in @($exHit.Keys)){ if(-not $exHit[$k].name -and $pnm[$k]){ $exHit[$k].name=$pnm[$k] } }

# ── 홈런 누적 저장 (traj_hr.js) ──
$newFrom=if(([string]$From) -lt $exFrom){$From}else{$exFrom}
$newTo=if(([string]$To) -gt $exTo){$To}else{$exTo}
$hitters=[ordered]@{}
foreach($k in ($exHit.Keys|Sort-Object)){ if($exHit[$k].hrs.Count){ $hitters[$k]=[ordered]@{ name=$exHit[$k].name; hrs=@($exHit[$k].hrs) } } }
$hj=([ordered]@{ from=$newFrom; to=$newTo; hitters=$hitters })|ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($hrPath,"window.KBO_HR = $hj;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "HR DONE: 홈런타자 $($hitters.Count)명 ($newFrom~$newTo) / $([math]::Round((Get-Item $hrPath).Length/1KB))KB"

# ── 투구 롤링 저장 (trajectory.js, 새로 덮어씀) ──
if(-not $HrOnly){
  $pitchers=[ordered]@{}; foreach($k in $pit.Keys){ if($pit[$k].Count){ $pitchers[$k]=[ordered]@{ name=$pnm[$k]; pitches=@($pit[$k]) } } }
  $pj=([ordered]@{ from=$From; to=$To; pitchers=$pitchers })|ConvertTo-Json -Depth 6
  [System.IO.File]::WriteAllText("$root/trajectory.js","window.KBO_TRAJ = $pj;",(New-Object System.Text.UTF8Encoding $false))
  Write-Host "PITCH DONE: 투수 $($pitchers.Count)명 ($From~$To) / $([math]::Round((Get-Item "$root/trajectory.js").Length/1KB))KB"
}
