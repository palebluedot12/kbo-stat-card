# KBO 타자 기록 스크래퍼 v2
#  - 규정타석 충족 선수(기본) + 전팀 순회로 전체 선수 + qual 플래그
#  - 슬래시라인/ISO/BB·K/wRC+ 자체 산출, 사진 base64 임베드
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
# 기본(규정타석) - 페이지2까지
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
# 전팀 순회(전체 선수)
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

$B='https://www.koreabaseball.com/Record/Player/HitterBasic/Basic1.aspx'
$D='https://www.koreabaseball.com/Record/Player/HitterBasic/Detail1.aspx'
$RN='https://www.koreabaseball.com/Record/Player/Runner/Basic.aspx'

Write-Host "[1] 규정타석 선수(기본/세부)..."
$qualBasic = Scrape-Default $B
$qualPids  = $qualBasic.Keys
Write-Host "  규정 $($qualPids.Count)명"
Write-Host "[2] 전체 선수(전팀 순회)..."
$basic  = Scrape-AllTeams $B
$detail = Scrape-AllTeams $D
Write-Host "  전체 기본 $($basic.Count) / 세부 $($detail.Count)"
Write-Host "[3] 주루..."
$runner = Scrape-Default $RN

# ===== 병합 =====
function N($h,$k){ if($h.ContainsKey($k) -and $h[$k] -ne '' -and $h[$k] -ne '-'){ [double]$h[$k] } else { $null } }
$players=@()
foreach($pno in $basic.Keys){
  $b=$basic[$pno]
  $d=if($detail.ContainsKey($pno)){$detail[$pno].stats}else{@{}}
  $rn=if($runner.ContainsKey($pno)){$runner[$pno].stats}else{@{}}
  $AB=N $b.stats 'AB_CN'; $PA=N $b.stats 'PA_CN'; $AVG=N $b.stats 'HRA_RT'
  if($null -eq $AB -or $AB -lt 1 -or $null -eq $AVG){ continue }   # 타석 없는 선수 제외
  $G=N $b.stats 'GAME_CN'; $H=N $b.stats 'HIT_CN'; $TB=N $b.stats 'TB_CN'
  $SF=[double](N $b.stats 'SF_CN'); $SH=[double](N $b.stats 'SH_CN')
  $H2=N $b.stats 'H2_CN'; $H3=N $b.stats 'H3_CN'; $HR=N $b.stats 'HR_CN'
  $RBI=N $b.stats 'RBI_CN'; $R=N $b.stats 'RUN_CN'
  $kkbb=N $d 'KK_BB_RT'                       # = BB/K (KBO 헤더 기준)
  $sb=$null; foreach($cand in 'SB_CN','SBA_CN'){ if($rn.ContainsKey($cand)){ $sb=N $rn $cand; break } }
  if($null -eq $sb){ $sb=0 }
  $SLG=if($AB){[math]::Round($TB/$AB,3)}else{$null}
  $W=$PA-$AB-$SF-$SH
  $OBP=if(($AB+$W+$SF) -gt 0){[math]::Round(($H+$W)/($AB+$W+$SF),3)}else{$null}
  $OPS=if($null -ne $OBP -and $null -ne $SLG){[math]::Round($OBP+$SLG,3)}else{$null}
  $ISO=if($null -ne $SLG -and $null -ne $AVG){[math]::Round($SLG-$AVG,3)}else{$null}
  $players += [pscustomobject]@{
    pid=$pno; name=$b.name; team=$b.team
    photo="https://6ptotvmi5753.edge.naverncp.com/KBO_IMAGE/person/middle/2026/$pno.jpg"
    qual=[bool]($qualPids -contains $pno)
    G=$G; PA=$PA; AB=$AB; H=$H; H2=$H2; H3=$H3; HR=$HR; RBI=$RBI; R=$R; TB=$TB; SF=$SF
    AVG=$AVG; OBP=$OBP; SLG=$SLG; OPS=$OPS; ISO=$ISO; BBK=$kkbb; SB=$sb; BBHBP=$W
  }
}
$qn = ($players | Where-Object { $_.qual }).Count
Write-Host "  병합 완료: $($players.Count)명 (규정 $qn)"

# ===== wRC+ (리그 합계 베이스라인) =====
Write-Host "[4] wRC+ ..."
$lg=@{AB=0.0;H=0.0;H2=0.0;H3=0.0;HR=0.0;PA=0.0;SH=0.0;SF=0.0;R=0.0}
try{
  $tc=(Invoke-WebRequest -Uri 'https://www.koreabaseball.com/Record/Team/Hitter/Basic1.aspx' -UseBasicParsing -TimeoutSec 25).Content
  foreach($tr in [regex]::Matches($tc,'<tr[^>]*>(?:(?!</tr>).)*?data-id(?:(?!</tr>).)*?</tr>','Singleline')){
    $s=@{}; foreach($m in [regex]::Matches($tr.Value,'data-id="([^"]+)">([^<]*)</td>')){ $s[$m.Groups[1].Value]=$m.Groups[2].Value }
    $lg.AB+=[double]$s['AB_CN'];$lg.H+=[double]$s['HIT_CN'];$lg.H2+=[double]$s['H2_CN'];$lg.H3+=[double]$s['H3_CN']
    $lg.HR+=[double]$s['HR_CN'];$lg.PA+=[double]$s['PA_CN'];$lg.SH+=[double]$s['SH_CN'];$lg.SF+=[double]$s['SF_CN'];$lg.R+=[double]$s['RUN_CN']
  }
}catch{ Write-Host "  팀합계 실패" }
$wW=0.70;$w1=0.89;$w2=1.27;$w3=1.62;$wHR=2.10;$scale=1.20
$lgW=$lg.PA-$lg.AB-$lg.SF-$lg.SH; $lg1B=$lg.H-$lg.H2-$lg.H3-$lg.HR
$lgwOBA=($wW*$lgW+$w1*$lg1B+$w2*$lg.H2+$w3*$lg.H3+$wHR*$lg.HR)/($lg.AB+$lgW+$lg.SF)
$lgRPA=$lg.R/$lg.PA
Write-Host ("  lgwOBA={0:N3} lgR/PA={1:N3}" -f $lgwOBA,$lgRPA)
foreach($p in $players){
  $W=[double]$p.BBHBP; $oneB=[double]$p.H-[double]$p.H2-[double]$p.H3-[double]$p.HR; $den=[double]$p.AB+$W+[double]$p.SF
  $woba=if($den -gt 0){($wW*$W+$w1*$oneB+$w2*[double]$p.H2+$w3*[double]$p.H3+$wHR*[double]$p.HR)/$den}else{0}
  $wrc=if($lgRPA -gt 0){[math]::Round((((($woba-$lgwOBA)/$scale)+$lgRPA)/$lgRPA)*100)}else{$null}
  $p|Add-Member -NotePropertyName wRCplus -NotePropertyValue $wrc -Force
}

# ===== 사진 base64 =====
Write-Host "[5] 사진 임베드 ($($players.Count)장)..."
$PLACEHOLDER="data:image/svg+xml;base64,"+[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<svg xmlns="http://www.w3.org/2000/svg" width="74" height="90"><rect width="74" height="90" fill="#1c2742"/><text x="37" y="50" fill="#5b6884" font-size="11" text-anchor="middle">NO IMG</text></svg>'))
$wc=New-Object System.Net.WebClient; $okc=0
foreach($p in $players){
  try{ $bytes=$wc.DownloadData($p.photo); if($bytes.Length -gt 800){$p.photo="data:image/jpeg;base64,"+[Convert]::ToBase64String($bytes);$okc++}else{$p.photo=$PLACEHOLDER} }catch{ $p.photo=$PLACEHOLDER }
}
Write-Host "  사진 $okc/$($players.Count)"

$players=$players|Sort-Object {-1*([double]$_.AVG)}
$json=$players|ConvertTo-Json -Depth 5
$root = if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}
[System.IO.File]::WriteAllText("$root/players.json",$json,(New-Object System.Text.UTF8Encoding $false))
[System.IO.File]::WriteAllText("$root/data.js","window.KBO_PLAYERS = $json;",(New-Object System.Text.UTF8Encoding $false))
$qn2 = ($players | Where-Object { $_.qual }).Count
Write-Host ""
Write-Host "DONE: 전체 $($players.Count)명 / 규정 $qn2 명 -> $root"
$players | Where-Object { $_.qual } | Sort-Object {-1*$_.wRCplus} | Select-Object name,team,AVG,OBP,SLG,OPS,BBK,wRCplus,SB -First 8 | Format-Table -AutoSize