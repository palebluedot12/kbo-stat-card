# 타자 주포지션(포수/내야/외야) → positions.js 생성
#  기준: KBO 수비기록에서 "올시즌 가장 많은 경기수(G)를 출장한 단일 포지션"으로 결정
#  (등록 포지션이 아니라 실제 최다 출장 포지션. 예: 김태연이 주전 1루 출장 → 내야)
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$TEAMS='LG','KT','SS','HT','HH','OB','SK','NC','LT','WO'
$DDLTEAM='ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlTeam$ddlTeam'
$DDLPOS ='ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlPos$ddlPos'
$DEF='https://www.koreabaseball.com/Record/Player/Defense/Basic.aspx'

# 개별 수비포지션 텍스트 → 그룹
function PosGroup($t){
  if($t -match '포수'){return '포수'}
  if($t -match '(1루|2루|3루|유격)'){return '내야'}
  if($t -match '(좌익|중견|우익|외야)'){return '외야'}
  return $null
}
function Get-FormFields($html){
  $f=@{}
  foreach($m in [regex]::Matches($html,'<input type="hidden" name="([^"]+)"(?: id="[^"]*")? value="([^"]*)"')){ $f[$m.Groups[1].Value]=$m.Groups[2].Value }
  foreach($sm in [regex]::Matches($html,'(?s)<select name="([^"]+)".*?</select>')){ $sel=[regex]::Match($sm.Value,'<option selected="selected" value="([^"]*)"'); if($sel.Success){$f[$sm.Groups[1].Value]=$sel.Groups[1].Value} }
  return $f
}
# 수비기록 행 파싱 → (pid, pos텍스트, G) 누적
function Parse-Def($html,$best){
  foreach($row in [regex]::Matches($html,'<tr>(?:(?!</tr>).)*?playerId=(\d+)(?:(?!</tr>).)*?</tr>','Singleline')){
    $rv=$row.Value
    $pno=[regex]::Match($rv,'playerId=(\d+)').Groups[1].Value
    $tds=[regex]::Matches($rv,'(?s)<td[^>]*>(.*?)</td>') | ForEach-Object { ($_.Groups[1].Value -replace '<[^>]+>','').Trim() }
    if($tds.Count -lt 5){continue}
    $posTxt=$tds[3]; $g=0; [int]::TryParse(($tds[4] -replace '[^\d]',''),[ref]$g)|Out-Null
    $grp=PosGroup $posTxt; if(-not $grp){continue}
    # 이 선수의 최다 G 단일 포지션만 보관 (동률이면 먼저 잡힌 포수>내야>외야 그룹순서로 들어와 유지)
    if(-not $best.ContainsKey($pno) -or $g -gt $best[$pno].g){ $best[$pno]=[pscustomobject]@{g=$g;grp=$grp;pos=$posTxt} }
  }
}

# 포수>내야>외야 순서로 그룹 순회(동률 시 더 전문 포지션 우선 유지)
$groups=@(@('2','포수'),@('3,4,5,6','내야'),@('7,8,9','외야'))
$best=@{}
foreach($tc in $TEAMS){
  foreach($g in $groups){
    $r=Invoke-WebRequest -Uri $DEF -UseBasicParsing -SessionVariable sess -TimeoutSec 30
    $f=Get-FormFields $r.Content
    $f[$DDLTEAM]=$tc; $f[$DDLPOS]=$g[0]; $f['__EVENTTARGET']=$DDLPOS; $f['__EVENTARGUMENT']=''
    Start-Sleep -Milliseconds 180
    $r2=Invoke-WebRequest -Uri $DEF -Method POST -Body $f -WebSession $sess -UseBasicParsing -TimeoutSec 30
    Parse-Def $r2.Content $best
  }
  Write-Host "  $tc 완료"
}

$posMap=@{}
foreach($k in $best.Keys){ $posMap[$k]=$best[$k].grp }
Write-Host "수비기준 수집: $($posMap.Count)명"

# 수비기록 없는 선수(순수 DH 등)는 기존 positions.js 값 유지
$existing="H:\KBOWEB\positions.js"
if(Test-Path $existing){
  $old=[System.IO.File]::ReadAllText($existing,[System.Text.Encoding]::UTF8)
  $keep=0
  foreach($m in [regex]::Matches($old,'"(\d+)":"([^"]+)"')){
    $ppid=$m.Groups[1].Value
    if(-not $posMap.ContainsKey($ppid)){ $posMap[$ppid]=$m.Groups[2].Value; $keep++ }
  }
  if($keep){ Write-Host "기존값 유지(수비기록 없음): $keep명" }
}

# 주포지션 강제 지정(휴리스틱이 틀리는 선수만 pid:포지션 으로 고정)
$override=@{}
foreach($k in $override.Keys){ $posMap[$k]=$override[$k] }

# 작은 매핑 파일만 생성 (4MB JSON 재파싱/덮어쓰기 회피)
$json=$posMap|ConvertTo-Json -Compress
[System.IO.File]::WriteAllText("H:\KBOWEB\positions.js","window.KBO_POS = $json;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "positions.js 생성: $($posMap.Count)명"
($posMap.Values|Group-Object|ForEach-Object{ "$($_.Name): $($_.Count)" }) -join '   '
if($best.ContainsKey('66704')){ Write-Host ("김태연(66704): {0} (최다출장 {1} {2}G)" -f $posMap['66704'],$best['66704'].pos,$best['66704'].g) }
