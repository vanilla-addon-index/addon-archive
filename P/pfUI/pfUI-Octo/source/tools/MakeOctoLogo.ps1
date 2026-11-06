param([string]$Root = (Join-Path $PSScriptRoot ".."), [string]$Shots = "")
# Draws pfUI Octo's logo and banner (26 Oct 2026, user: "say pfUI Octo in our
# new artwork ... the author Bdot89").
#   img\octo\logo.tga   256 x 128  the About page's logo (32-bit TGA, alpha)
#   docs\logo.png       560 x 256 the same for the web page
#   docs\banner.png     1280 x 640 the web page's top picture and link preview
#                       (needs -Shots <folder with the docs\*.jpg crops>)
# The pixel "pfUI" is Shagu's logo (gui.lua About page, same blocks); "OCTO"
# is BigNoodleTitling from fonts\, blue to violet as the options window.
#   powershell -ExecutionPolicy Bypass -File tools\MakeOctoLogo.ps1 -Shots docs

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"
$Root = (Resolve-Path $Root).Path

$fonts = New-Object System.Drawing.Text.PrivateFontCollection
$fonts.AddFontFile((Join-Path $Root "fonts\BigNoodleTitling.ttf"))
$fonts.AddFontFile((Join-Path $Root "fonts\Expressway.ttf"))
$noodle = $fonts.Families | Where-Object { $_.Name -like "*Noodle*" } | Select-Object -First 1
$express = $fonts.Families | Where-Object { $_.Name -like "*Expressway*" } | Select-Object -First 1

function Col([string]$hex, [int]$a = 255) {
  $v = [Convert]::ToInt32($hex, 16)
  [System.Drawing.Color]::FromArgb($a, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255)
}
$TEAL = Col "33ffcc"; $BLUE = Col "33b3ff"; $VIOLET = Col "9a6bff"; $WHITE = Col "ffffff"

# the logo on graphics g, top left at (x, y), pixel block size p; returns its width
function Logo($g, [double]$x, [double]$y, [double]$p, [bool]$byline) {
  $tealBlocks = @(@(0,2,1,7), @(1,2,2,3), @(1,4,2,5), @(2,0,3,5), @(3,0,4,1), @(1,2,4,3))
  $whiteBlocks = @(@(4,0,5,5), @(5,4,6,5), @(6,0,7,1), @(6,2,7,5))
  # soft shadow first, then the blocks (no smoothing: whole pixels, no seams)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
  $shadow = [System.Drawing.SolidBrush]::new((Col "000000" 110))
  foreach ($b in ($tealBlocks + $whiteBlocks)) {
    $g.FillRectangle($shadow, [single]($x + $b[0] * $p + $p * .12), [single]($y + $b[1] * $p + $p * .12), [single](($b[2] - $b[0]) * $p), [single](($b[3] - $b[1]) * $p))
  }
  $tb = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.PointF]::new([single]$x, [single]$y)), ([System.Drawing.PointF]::new([single]$x, [single]($y + 7 * $p))), $TEAL, (Col "1fb8a8"))
  foreach ($b in $tealBlocks) { $g.FillRectangle($tb, [single]($x + $b[0] * $p), [single]($y + $b[1] * $p), [single](($b[2] - $b[0]) * $p), [single](($b[3] - $b[1]) * $p)) }
  $wb = [System.Drawing.SolidBrush]::new($WHITE)
  foreach ($b in $whiteBlocks) { $g.FillRectangle($wb, [single]($x + $b[0] * $p), [single]($y + $b[1] * $p), [single](($b[2] - $b[0]) * $p), [single](($b[3] - $b[1]) * $p)) }

  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  # OCTO: as tall as the logo's top five blocks, outlined, with a glow
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $em = 7.4 * $p
  $sf = [System.Drawing.StringFormat]::GenericTypographic
  $path.AddString("OCTO", $noodle, 0, [single]$em, ([System.Drawing.PointF]::new([single]($x + 8 * $p), [single]($y - 1.05 * $p))), $sf)
  $r = $path.GetBounds()
  for ($i = 6; $i -ge 1; $i--) {
    $pen = [System.Drawing.Pen]::new((Col "33b3ff" (10 + 6 * (7 - $i))), [single]($p * .16 * $i))
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path)
  }
  $grad = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.PointF]::new($r.Left, $r.Top)), ([System.Drawing.PointF]::new($r.Right, $r.Bottom)), $BLUE, $VIOLET)
  $outline = [System.Drawing.Pen]::new((Col "05070c" 230), [single]($p * .22))
  $outline.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $g.DrawPath($outline, $path)
  $g.FillPath($grad, $path)
  # a light edge along the top of the letters
  $hl = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.PointF]::new($r.Left, $r.Top)), ([System.Drawing.PointF]::new($r.Left, ($r.Top + $r.Height * .45))), (Col "ffffff" 90), (Col "ffffff" 0))
  $g.FillPath($hl, $path)
  $width = $r.Right - $x
  if ($byline) {
    $bf = [System.Drawing.Font]::new($express, [single]($p * 1.15), [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $g.DrawString("by Bdot89", $bf, ([System.Drawing.SolidBrush]::new((Col "c9d6e8"))), [single]($x + 8.15 * $p), [single]($y + 5.55 * $p))
  }
  return $width
}

function NewCanvas([int]$w, [int]$h) {
  $bmp = [System.Drawing.Bitmap]::new($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.Clear([System.Drawing.Color]::Transparent)
  return $bmp, $g
}

# uncompressed 32-bit TGA, bottom-left origin (what 1.12 reads)
function SaveTga($bmp, [string]$path) {
  $w = $bmp.Width; $h = $bmp.Height
  $fs = [System.IO.File]::Create($path)
  $bw = [System.IO.BinaryWriter]::new($fs)
  $bw.Write([byte[]](0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  $bw.Write([uint16]$w); $bw.Write([uint16]$h)
  $bw.Write([byte]32); $bw.Write([byte]8)
  $rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($data.Stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  $bmp.UnlockBits($data)
  for ($y = $h - 1; $y -ge 0; $y--) { $bw.Write($bytes, $y * $data.Stride, $w * 4) }
  $bw.Close()
}

# the logo, drawn big and fitted into a w x h box
function LogoImage([int]$w, [int]$h, [bool]$byline) {
  $big = NewCanvas 2048 512
  $wd = Logo $big[1] 40 64 56 $byline
  $out = NewCanvas $w $h
  $s = [math]::Min(($w - 8) / ($wd + 80), ($h - 4) / 512)
  $out[1].DrawImage($big[0], [single]4, [single](($h - 512 * $s) / 2), [single](2048 * $s), [single](512 * $s))
  return $out[0]
}

New-Item -ItemType Directory -Force (Join-Path $Root "docs") | Out-Null
$tga = LogoImage 256 128 $true
SaveTga $tga (Join-Path $Root "img\octo\logo.tga")
$png = LogoImage 560 256 $true
$png.Save((Join-Path $Root "docs\logo.png"), [System.Drawing.Imaging.ImageFormat]::Png)
"logo: img\octo\logo.tga, docs\logo.png"

# banner: dark with blue / teal light, the logo, a line, three screenshots
if ($Shots -ne "") {
  $Shots = (Resolve-Path $Shots).Path
  $c = NewCanvas 1280 640
  $g = $c[1]
  $g.Clear((Col "0e1014"))
  foreach ($spot in @(@(1050, -40, 700, "33b3ff", 70), @(80, 40, 600, "33ffcc", 40), @(640, 700, 800, "9a6bff", 45))) {
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddEllipse([single]($spot[0] - $spot[2] / 2), [single]($spot[1] - $spot[2] / 2), [single]$spot[2], [single]$spot[2])
    $pg = [System.Drawing.Drawing2D.PathGradientBrush]::new($gp)
    $pg.CenterColor = Col $spot[3] $spot[4]
    $pg.SurroundColors = @((Col $spot[3] 0))
    $g.FillPath($pg, $gp)
  }
  $logo = LogoImage 760 190 $true
  $g.DrawImage($logo, 40, 18)
  $tf = [System.Drawing.Font]::new($express, [single]30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString("Your whole interface in one addon, for OctoWoW 1.12", $tf, ([System.Drawing.SolidBrush]::new((Col "e9eef6"))), [single]52, [single]212)
  $tf2 = [System.Drawing.Font]::new($express, [single]22, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString("Unit frames - action bars - nameplates - meters - combat text - gear sets - layouts", $tf2, ([System.Drawing.SolidBrush]::new((Col "9fb3c8"))), [single]52, [single]254)
  $pics = @("layouts.jpg", "meters.jpg", "gear.jpg")
  $x = 40
  foreach ($name in $pics) {
    $img = [System.Drawing.Image]::FromFile((Join-Path $Shots $name))
    $w = 388; $hh = [int]($img.Height * $w / $img.Width)
    $border = [System.Drawing.Drawing2D.LinearGradientBrush]::new(([System.Drawing.PointF]::new($x, 300)), ([System.Drawing.PointF]::new(($x + $w), 600)), $BLUE, $VIOLET)
    $g.FillRectangle($border, [single]($x - 3), [single](300 - 3), [single]($w + 6), [single]($hh + 6))
    $g.DrawImage($img, [single]$x, [single]300, [single]$w, [single]$hh)
    $img.Dispose()
    $x += $w + 18
  }
  $c[0].Save((Join-Path $Root "docs\banner.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  "banner: docs\banner.png"
}
