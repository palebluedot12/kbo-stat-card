# KBO 투수 기록 스크래퍼 -> data_pitchers.js (window.KBO_PITCHERS)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$TEAMS = 'LG','KT','SS','HT','HH','OB','SK','NC','LT','WO'
$DDLTEAM = 'ctl00$ctl00$ctl00$cphContents$cphContents$cphContents$ddlTeam$ddlTeam'

function Parse-Rows($html){
  $out=@{}
  foreach($row in [regex]::Matches($html,'<tr>(?:(?!</tr>).)*?playerId=(\d+)(?:(?!</tr>).)*?</tr>','Singleline')){
    $rv=$row.Value
    $pno=[regex]::Match($rv,'playerId=(\d+)').Groups[1].Value
    $name=[regex]::Match($rv,'playerId=\d+">([^<]+)</a>').Groups[1].Value
    $team=[regex]::Match($rv,'</a></td>\s*<td>([^<]+)</td>').Groups[1].Value
    $stats=@{}; foreach($m in [regex]::Matches($rv,'data-id="([^"]+)">([^<]*)</td>')){ $stats[$m.Groups[1].Value]=$m.Groups[2].Value }
    $out[$pno]=[pscustomobject]@{ pid=$pno; name=$name; team=$team; stats=$stats }
  }
  return $out
}
function Get-FormFields($html){
  $f=@{}
  foreach($m in [regex]::Matches($html,'<input type="hidden" name="([^"]+)"(?: id="[^"]*")? value="([^"]*)"')){ $f[$m.Groups[1].Value]=$m.Groups[2].Value }
  foreach($sm in [regex]::Matches($html,'(?s)<select name="([^"]+)".*?</select>')){ $sel=[regex]::Match($sm.Value,'<option selected="selected" value="([^"]*)"'); if($sel.Success){$f[$sm.Groups[1].Value]=$sel.Groups[1].Value} }
  return $f
}
function Scrape-Default($url){
  $r=Invoke-WebRequest -Uri $url -UseBasicParsing -SessionVariable sess -TimeoutSec 30
  $m=Parse-Rows $r.Content
  $pg2=[regex]::Match($r.Content,"__doPostBack\(&#39;([^&]*ucPager\`$btnNo2)&#39;")
  if($pg2.Success){
    $f=Get-FormFields $r.Content; $f['__EVENTTARGET']=$pg2.Groups[1].Value; $f['__EVENTARGUMENT']=''
    Start-Sleep -Milliseconds 350
    $r2=Invoke-WebRequest -Uri $url -Method POST -Body $f -WebSession $sess -UseBasicParsing -TimeoutSec 30
    foreach($kv in (Parse-Rows $r2.Content).GetEnumerator()){ $m[$kv.Key]=$kv.Value }
  }
  return $m
}
function Scrape-AllTeams($url){
  $all=@{}
  foreach($tc in $TEAMS){
    $r=Invoke-WebRequest -Uri $url -UseBasicParsing -SessionVariable sess -TimeoutSec 30
    $f=Get-FormFields $r.Content; $f[$DDLTEAM]=$tc; $f['__EVENTTARGET']=$DDLTEAM; $f['__EVENTARGUMENT']=''
    Start-Sleep -Milliseconds 250
    $r2=Invoke-WebRequest -Uri $url -Method POST -Body $f -WebSession $sess -UseBasicParsing -TimeoutSec 30
    foreach($kv in (Parse-Rows $r2.Content).GetEnumerator()){ $all[$kv.Key]=$kv.Value }
  }
  return $all
}
# "75 1/3" -> 75.33
function ParseIP($s){
  if(-not $s){ return $null }
  $s=$s.Trim()
  if($s -match '^(\d+)\s+(\d)/3$'){ return [math]::Round([int]$Matches[1]+[int]$Matches[2]/3,3) }
  if($s -match '^(\d)/3$'){ return [math]::Round([int]$Matches[1]/3,3) }
  if($s -match '^(\d+(\.\d+)?)$'){ return [double]$Matches[1] }
  return $null
}

$B='https://www.koreabaseball.com/Record/Player/PitcherBasic/Basic1.aspx'
$D='https://www.koreabaseball.com/Record/Player/PitcherBasic/Detail1.aspx'

Write-Host "[1] 규정이닝 투수..."
$qual = Scrape-Default $B
$qualPids = $qual.Keys
Write-Host "  규정 $($qualPids.Count)명"
Write-Host "[2] 전체 투수(전팀)..."
$basic  = Scrape-AllTeams $B
$detail = Scrape-AllTeams $D
Write-Host "  전체 $($basic.Count)명"

function N($h,$k){ if($h.ContainsKey($k) -and $h[$k] -ne '' -and $h[$k] -ne '-'){ [double]$h[$k] } else { $null } }
$pitchers=@()
foreach($pno in $basic.Keys){
  $b=$basic[$pno]
  $d=if($detail.ContainsKey($pno)){$detail[$pno].stats}else{@{}}
  $ip=ParseIP $b.stats['INN2_CN']
  if($null -eq $ip -or $ip -lt 1){ continue }
  $H=N $b.stats 'HIT_CN'; $HR=N $b.stats 'HR_CN'; $BB=N $b.stats 'BB_CN'; $HBP=N $b.stats 'HP_CN'
  $SO=N $b.stats 'KK_CN'; $ER=N $b.stats 'ER_CN'; $ERA=N $b.stats 'ERA_RT'; $WHIP=N $b.stats 'WHIP_RT'
  $G=N $b.stats 'GAME_CN'; $W=N $b.stats 'W_CN'; $L=N $b.stats 'L_CN'; $SV=N $b.stats 'SV_CN'; $HLD=N $b.stats 'HOLD_CN'
  $GS=N $d 'START_CN'
  $K9 =[math]::Round($SO*9/$ip,2)
  $BB9=[math]::Round($BB*9/$ip,2)
  $HR9=[math]::Round($HR*9/$ip,2)
  $KBB=if($BB -gt 0){[math]::Round($SO/$BB,2)}else{$null}
  $role=if($null -ne $GS -and $G -gt 0 -and ($GS/$G) -ge 0.5){'선발'}else{'구원'}
  $pitchers += [pscustomobject]@{
    pid=$pno; name=$b.name; team=$b.team
    photo="https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle/2026/$pno.jpg"
    qual=[bool]($qualPids -contains $pno); role=$role
    G=$G; GS=$GS; W=$W; L=$L; SV=$SV; HLD=$HLD
    IP=$ip; ipText=$b.stats['INN2_CN']; H=$H; HR=$HR; BB=$BB; HBP=$HBP; SO=$SO; ER=$ER
    ERA=$ERA; WHIP=$WHIP; K9=$K9; BB9=$BB9; HR9=$HR9; KBB=$KBB
  }
}
Write-Host "  유효 $($pitchers.Count)명"

# ===== FIP (리그 베이스라인) =====
Write-Host "[3] FIP 베이스라인(팀 투구 합계)..."
$lg=@{HR=0.0;BB=0.0;HBP=0.0;SO=0.0;IP=0.0;ER=0.0}
try{
  $tc=(Invoke-WebRequest -Uri 'https://www.koreabaseball.com/Record/Team/Pitcher/Basic1.aspx' -UseBasicParsing -TimeoutSec 25).Content
  foreach($tr in [regex]::Matches($tc,'<tr[^>]*>(?:(?!</tr>).)*?data-id(?:(?!</tr>).)*?</tr>','Singleline')){
    $s=@{}; foreach($m in [regex]::Matches($tr.Value,'data-id="([^"]+)">([^<]*)</td>')){ $s[$m.Groups[1].Value]=$m.Groups[2].Value }
    $lg.HR+=[double]$s['HR_CN']; $lg.BB+=[double]$s['BB_CN']; $lg.HBP+=[double]$s['HP_CN']
    $lg.SO+=[double]$s['KK_CN']; $lg.ER+=[double]$s['ER_CN']; $lg.IP+=(ParseIP $s['INN2_CN'])
  }
}catch{ Write-Host "  팀합계 실패: $($_.Exception.Message)" }
$lgERA=9*$lg.ER/$lg.IP
$cFIP=$lgERA-((13*$lg.HR+3*($lg.BB+$lg.HBP)-2*$lg.SO)/$lg.IP)
Write-Host ("  리그ERA={0:N2}  cFIP={1:N2}" -f $lgERA,$cFIP)
foreach($p in $pitchers){
  $fip=[math]::Round(((13*[double]$p.HR+3*([double]$p.BB+[double]$p.HBP)-2*[double]$p.SO)/[double]$p.IP)+$cFIP,2)
  $p|Add-Member -NotePropertyName FIP -NotePropertyValue $fip -Force
}

# ===== 사진 =====
Write-Host "[4] 사진 임베드 ($($pitchers.Count)장)..."
$PLACEHOLDER="data:image/svg+xml;base64,"+[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<svg xmlns="http://www.w3.org/2000/svg" width="74" height="90"><rect width="74" height="90" fill="#1c2742"/><text x="37" y="50" fill="#5b6884" font-size="11" text-anchor="middle">NO IMG</text></svg>'))
$wc=New-Object System.Net.WebClient; $okc=0
foreach($p in $pitchers){
  try{ $bytes=$wc.DownloadData($p.photo); if($bytes.Length -gt 800){$p.photo="data:image/jpeg;base64,"+[Convert]::ToBase64String($bytes);$okc++}else{$p.photo=$PLACEHOLDER} }catch{ $p.photo=$PLACEHOLDER }
}
Write-Host "  사진 $okc/$($pitchers.Count)"

$pitchers=$pitchers|Sort-Object {[double]$_.ERA}
$json=$pitchers|ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText("H:\KBOWEB\data_pitchers.js","window.KBO_PITCHERS = $json;",(New-Object System.Text.UTF8Encoding $false))
$qn=($pitchers|Where-Object{$_.qual}).Count
Write-Host ""
Write-Host "DONE: 전체 $($pitchers.Count)명 / 규정 $qn 명 -> data_pitchers.js"
$pitchers|Where-Object{$_.qual}|Sort-Object {[double]$_.FIP}|Select-Object name,team,role,ERA,WHIP,K9,BB9,IP,FIP -First 8|Format-Table -AutoSize