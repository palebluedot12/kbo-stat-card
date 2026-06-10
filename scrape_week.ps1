# 주간 판타지 포인트: 그 주(월~오늘) 전 경기 박스스코어 합산 → weekly.js
param([string]$WeekStart = "")
$ErrorActionPreference="Stop"; $ProgressPreference="SilentlyContinue"
$ua="Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
$HDR=@{Referer="https://m.sports.naver.com/"}
function J($url){ (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20 -UserAgent $ua -Headers $HDR).Content | ConvertFrom-Json }
function PInn($s){ $s=[string]$s; if($s -match '^(\d+)\.(\d)$'){ [int]$matches[1]+[int]$matches[2]/3 } elseif($s -match '^\d+$'){ [double]$s } else { 0 } }

# 이번 주 월요일 계산 (KST 기준)
if(-not $WeekStart){
  $now=(Get-Date).ToUniversalTime().AddHours(9)
  $off=(([int]$now.DayOfWeek+6)%7)   # 월=0
  $WeekStart=$now.AddDays(-$off).ToString('yyyy-MM-dd')
}
$mon=[datetime]::ParseExact($WeekStart,'yyyy-MM-dd',$null)
$today=(Get-Date).ToUniversalTime().AddHours(9).Date
$end=$mon.AddDays(6); if($end -gt $today){$end=$today}
Write-Host "주간: $($mon.ToString('yyyy-MM-dd')) ~ $($end.ToString('yyyy-MM-dd'))"

$agg=@{}   # pcode -> totals
function Acc($pc,$name,$team,$kind,$pos){
  if(-not $agg.ContainsKey($pc)){ $agg[$pc]=[ordered]@{name=$name;team=$team;kind=$kind;pos=$pos;gp=0;ab=0;h=0;hr=0;rbi=0;r=0;bb=0;sb=0;ip=0.0;er=0;kk=0;w=0;sv=0;hld=0} }
  return $agg[$pc]
}

for($d=$mon; $d -le $end; $d=$d.AddDays(1)){
  $ds=$d.ToString('yyyy-MM-dd')
  $games=(J "https://api-gw.sports.naver.com/schedule/games?fields=basic&upperCategoryId=kbaseball&categoryId=kbo&fromDate=$ds&toDate=$ds&size=30").result.games
  foreach($g in $games){
    if($g.statusCode -ne 'RESULT'){ continue }
    try{ $rec=(J "https://api-gw.sports.naver.com/schedule/games/$($g.gameId)/record").result.recordData }catch{ continue }
    foreach($side in 'away','home'){
      $tn=if($side -eq 'away'){$g.awayTeamName}else{$g.homeTeamName}
      foreach($b in $rec.battersBoxscore.$side){
        if([int]$b.ab -eq 0 -and [int]$b.bb -eq 0){ continue }
        $a=Acc ([string]$b.playerCode) $b.name $tn '타자' $b.pos
        $a.gp++; $a.ab+=[int]$b.ab; $a.h+=[int]$b.hit; $a.hr+=[int]$b.hr; $a.rbi+=[int]$b.rbi; $a.r+=[int]$b.run; $a.bb+=[int]$b.bb; $a.sb+=[int]$b.sb
      }
      foreach($p in $rec.pitchersBoxscore.$side){
        $a=Acc ([string]$p.pcode) $p.name $tn '투수' '투'
        $a.gp++; $a.ip+=(PInn $p.inn); $a.er+=[int]$p.er; $a.kk+=[int]$p.kk; $a.hr+=[int]$p.hr
        if($p.wls -eq '승'){$a.w++}; if($p.wls -eq '세'){$a.sv++}; if($p.wls -eq '홀'){$a.hld++}
      }
    }
    Start-Sleep -Milliseconds 100
  }
  Write-Host "  $ds 처리"
}

# 판타지 포인트 + 기록줄
$players=@()
foreach($pc in $agg.Keys){
  $a=$agg[$pc]
  if($a.kind -eq '타자'){
    $fp=$a.h*1 + $a.hr*3 + $a.rbi*1 + $a.r*1 + $a.bb*0.5 + $a.sb*1
    $line="$($a.ab)타수 $($a.h)안타"; if($a.hr){$line+=" $($a.hr)홈런"}; if($a.rbi){$line+=" $($a.rbi)타점"}; if($a.sb){$line+=" $($a.sb)도루"}
  } else {
    $ipr=[math]::Round($a.ip,1)
    $fp=$a.ip*1.5 + $a.kk*0.5 + $a.w*4 + $a.sv*4 + $a.hld*2 - $a.er*1.5 - $a.hr*1
    $line="$($ipr)이닝 $($a.er)자책 $($a.kk)K"; if($a.w){$line+=" $($a.w)승"}; if($a.sv){$line+=" $($a.sv)세"}; if($a.hld){$line+=" $($a.hld)홀"}
  }
  $players += [pscustomobject]@{ pid=$pc; name=$a.name; team=$a.team; kind=$a.kind; pos=$a.pos; gp=$a.gp; fp=[math]::Round($fp,1); line=$line }
}

$out=[ordered]@{ weekStart=$mon.ToString('yyyy-MM-dd'); weekEnd=$end.ToString('yyyy-MM-dd'); players=$players }
$json=$out|ConvertTo-Json -Depth 6
$root=if($PSScriptRoot){$PSScriptRoot}else{"H:\KBOWEB"}
[System.IO.File]::WriteAllText("$root/weekly.js","window.KBO_WEEKLY = $json;",(New-Object System.Text.UTF8Encoding $false))
Write-Host "weekly.js 생성: $($players.Count)명"
"=== 주간 판타지 TOP 10 ==="
$players|Sort-Object fp -Descending|Select-Object -First 10|ForEach-Object{ "  {0,-7} {1,-4} {2} fp={3} | {4}" -f $_.name,$_.team,$_.kind,$_.fp,$_.line }