# 궤적 데이터 (pid 기반): 투수 구종별 투구 + 타자 홈런 → trajectory.js
param([string]$From="2026-06-01",[string]$To="2026-06-10")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$Hd=@{Referer="https://m.sports.naver.com/"}
function J($u){ (Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $Hd).Content|ConvertFrom-Json }
function PlateZ($p){ $a=0.5*[double]$p.ay; $b=[double]$p.vy0; $c=[double]$p.y0-[double]$p.crossPlateY
  $disc=$b*$b-4*$a*$c; if($disc -lt 0){return $null}; $t=(-$b-[math]::Sqrt($disc))/(2*$a); if($t -le 0){$t=(-$b+[math]::Sqrt($disc))/(2*$a)}
  [math]::Round([double]$p.z0+[double]$p.vz0*$t+0.5*[double]$p.az*$t*$t,2) }
$dirMap=@{'좌익'=-33;'좌측'=-33;'좌월'=-30;'좌중간'=-16;'중견'=0;'중월'=0;'중앙'=0;'우중간'=16;'우익'=33;'우측'=33;'우월'=30}

$pit=@{}; $hit=@{}; $pnm=@{}
$d=[datetime]::ParseExact($From,'yyyy-MM-dd',$null); $end=[datetime]::ParseExact($To,'yyyy-MM-dd',$null)
for(; $d -le $end; $d=$d.AddDays(1)){
  $ds=$d.ToString('yyyy-MM-dd')
  $games=(J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$ds&toDate=$ds&size=30").result.games
  foreach($g in $games){ if($g.statusCode -ne 'RESULT'){continue}
    $gid=$g.gameId
    foreach($inn in 1..12){ try{ $rd=(J "https://api-gw.sports.naver.com/schedule/games/$gid/relay?inning=$inn").result.textRelayData }catch{continue}
      if(-not $rd.textRelays){continue}
      foreach($e in $rd.textRelays){
        # 투수 구종별 투구
        $pits=@($e.textOptions|Where-Object{$_.ptsPitchId})
        if($pits.Count){
          $coord=@{}; foreach($o in $e.ptsOptions){ $coord[[string]$o.pitchId]=$o }
          $pc=[string]$e.textOptions[0].currentGameState.pitcher; $pn=$e.textOptions[0].currentPlayersInfo.away.playerType
          $pcname=$null  # 이름은 record에서 채움
          if(-not $pit.ContainsKey($pc)){ $pit[$pc]=[System.Collections.ArrayList]@() }
          foreach($pt in $pits){ $cx=$coord[[string]$pt.ptsPitchId]; if(-not $cx){continue}; $z=PlateZ $cx; if($null -eq $z){continue}
            [void]$pit[$pc].Add([pscustomobject]@{ s=$pt.stuff; x=[math]::Round([double]$cx.crossPlateX,2); z=$z; v=[int]$pt.speed; r=$pt.pitchResult }) }
        }
        # 타자 홈런
        foreach($t in $e.textOptions){ if($t.text -and $t.text -match '홈런' -and $t.text -match '홈런거리'){
          $bc=[string]$e.textOptions[0].currentGameState.batter
          $dist=if($t.text -match '홈런거리:(\d+)'){[int]$matches[1]}else{110}
          $deg=0; foreach($k in $dirMap.Keys){ if($t.text -match $k){ $deg=$dirMap[$k]; break } }
          if(-not $hit.ContainsKey($bc)){ $hit[$bc]=[System.Collections.ArrayList]@() }
          [void]$hit[$bc].Add([pscustomobject]@{ deg=$deg; dist=$dist; d=$ds }) } }
      }
      Start-Sleep -Milliseconds 70
    }
    # 이름 매핑
    $rec=(J "https://api-gw.sports.naver.com/schedule/games/$gid/record").result.recordData
    foreach($s in 'away','home'){ foreach($p in $rec.pitchersBoxscore.$s){ $pnm[[string]$p.pcode]=$p.name }; foreach($b in $rec.battersBoxscore.$s){ $pnm[[string]$b.playerCode]=$b.name } }
  }
  Write-Host "  $ds 처리 (투수 $($pit.Count) / 타자홈런 $($hit.Count))"
}
# 이름 채워서 출력 구조
$pitchers=@{}; foreach($k in $pit.Keys){ $pitchers[$k]=[ordered]@{ name=$pnm[$k]; pitches=$pit[$k] } }
$hitters=@{}; foreach($k in $hit.Keys){ $hitters[$k]=[ordered]@{ name=$pnm[$k]; hrs=$hit[$k] } }
$out=[ordered]@{ from=$From; to=$To; pitchers=$pitchers; hitters=$hitters }
$json=$out|ConvertTo-Json -Depth 6
$root=if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}
[System.IO.File]::WriteAllText("$root/trajectory.js","window.KBO_TRAJ = $json;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "DONE: 투수 $($pitchers.Count)명 / 홈런타자 $($hitters.Count)명 / $([math]::Round((Get-Item "$root/trajectory.js").Length/1KB))KB"