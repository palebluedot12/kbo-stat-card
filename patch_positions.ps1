# 타자 포지션(포수/내야/외야)만 긁어서 players.json + data.js 에 patch
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$TEAMS='LG','KT','SS','HT','HH','OB','SK','NC','LT','WO'
$DDLTEAM='ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlTeam$ddlTeam'
$DDLPOS ='ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlPos$ddlPos'
$B='https://www.koreabaseball.com/Record/Player/HitterBasic/Basic1.aspx'

function Get-FormFields($html){
  $f=@{}
  foreach($m in [regex]::Matches($html,'<input type="hidden" name="([^"]+)"(?: id="[^"]*")? value="([^"]*)"')){ $f[$m.Groups[1].Value]=$m.Groups[2].Value }
  foreach($sm in [regex]::Matches($html,'(?s)<select name="([^"]+)".*?</select>')){ $sel=[regex]::Match($sm.Value,'<option selected="selected" value="([^"]*)"'); if($sel.Success){$f[$sm.Groups[1].Value]=$sel.Groups[1].Value} }
  return $f
}
function Pids($html){ [regex]::Matches($html,'playerId=(\d+)') | ForEach-Object { $_.Groups[1].Value } }

$posMap=@{}
$groups=@(@('2','포수'),@('3,4,5,6','내야'),@('7,8,9','외야'))
foreach($tc in $TEAMS){
  foreach($g in $groups){
    $r=Invoke-WebRequest -Uri $B -UseBasicParsing -SessionVariable sess -TimeoutSec 30
    $f=Get-FormFields $r.Content
    $f[$DDLTEAM]=$tc; $f[$DDLPOS]=$g[0]; $f['__EVENTTARGET']=$DDLPOS; $f['__EVENTARGUMENT']=''
    Start-Sleep -Milliseconds 180
    $r2=Invoke-WebRequest -Uri $B -Method POST -Body $f -WebSession $sess -UseBasicParsing -TimeoutSec 30
    foreach($pno in (Pids $r2.Content)){ $posMap[$pno]=$g[1] }
  }
  Write-Host "  $tc 완료"
}
Write-Host "포지션 수집: $($posMap.Count)명"

# 작은 매핑 파일만 생성 (4MB JSON 재파싱/덮어쓰기 회피)
$json=$posMap|ConvertTo-Json -Compress
[System.IO.File]::WriteAllText("H:\KBOWEB\positions.js","window.KBO_POS = $json;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "positions.js 생성: $($posMap.Count)명"
($posMap.Values|Group-Object|ForEach-Object{ "$($_.Name): $($_.Count)" }) -join '   '