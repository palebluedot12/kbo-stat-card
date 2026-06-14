# 공유용 OG 이미지(1200x630) 생성 → og.png
Add-Type -AssemblyName System.Drawing
$W=1200; $H=630
$bmp=New-Object System.Drawing.Bitmap $W,$H
$g=[System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode=[System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint=[System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

function Col($h){ [System.Drawing.ColorTranslator]::FromHtml($h) }
$rect=New-Object System.Drawing.Rectangle 0,0,$W,$H

# 배경 그라데이션
$bg=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,(Col '#16213c'),(Col '#0a0e1a'),60.0)
$g.FillRectangle($bg,$rect)
# 상단 은은한 글로우
$glowRect=New-Object System.Drawing.Rectangle 300,-260,600,520
$gp=New-Object System.Drawing.Drawing2D.GraphicsPath
$gp.AddEllipse($glowRect)
$pgb=New-Object System.Drawing.Drawing2D.PathGradientBrush($gp)
$pgb.CenterColor=[System.Drawing.Color]::FromArgb(70,255,170,60)
$pgb.SurroundColors=@([System.Drawing.Color]::FromArgb(0,255,170,60))
$g.FillEllipse($pgb,$glowRect)

$sf=New-Object System.Drawing.StringFormat
$sf.Alignment=[System.Drawing.StringAlignment]::Center
$sf.LineAlignment=[System.Drawing.StringAlignment]::Center

# 야구공 아이콘
$bx=600; $by=170; $br=52
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)),($bx-$br),($by-$br),($br*2),($br*2))
$redPen=New-Object System.Drawing.Pen((Col '#e0463c'),5)
$g.DrawArc($redPen,($bx-$br+10),($by-$br-26),($br*2-20),($br*2),35,110)
$g.DrawArc($redPen,($bx-$br+10),($by-$br+26),($br*2-20),($br*2),215,110)

# 타이틀 "크보웹" (금색 그라데이션)
$titleRect=New-Object System.Drawing.RectangleF 0,250,$W,150
$gold=New-Object System.Drawing.Drawing2D.LinearGradientBrush($titleRect,(Col '#ffe08a'),(Col '#ff8a1c'),0.0)
$titleFont=New-Object System.Drawing.Font('Malgun Gothic',104,[System.Drawing.FontStyle]::Bold)
$g.DrawString('크보웹',$titleFont,$gold,$titleRect,$sf)

# 서브타이틀
$white=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235,232,237,248))
$sub1Font=New-Object System.Drawing.Font('Malgun Gothic',38,[System.Drawing.FontStyle]::Bold)
$g.DrawString('KBO 선수 스탯카드',$sub1Font,$white,(New-Object System.Drawing.RectangleF 0,405,$W,55),$sf)

$gray=New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,138,150,180))
$sub2Font=New-Object System.Drawing.Font('Malgun Gothic',28,[System.Drawing.FontStyle]::Regular)
$g.DrawString('레이더 카드 · 마이팀 · 오늘의 BEST · WORST',$sub2Font,$gray,(New-Object System.Drawing.RectangleF 0,470,$W,45),$sf)

# 하단 도메인
$domFont=New-Object System.Drawing.Font('Malgun Gothic',24,[System.Drawing.FontStyle]::Bold)
$g.DrawString('kbo-stat-card.vercel.app',$domFont,(New-Object System.Drawing.SolidBrush (Col '#ff9f1c')),(New-Object System.Drawing.RectangleF 0,560,$W,40),$sf)

$root=if($PSScriptRoot){$PSScriptRoot}else{'H:\KBOWEB'}
$bmp.Save("$root\og.png",[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Host "og.png 생성: $([math]::Round((Get-Item "$root\og.png").Length/1KB))KB"
