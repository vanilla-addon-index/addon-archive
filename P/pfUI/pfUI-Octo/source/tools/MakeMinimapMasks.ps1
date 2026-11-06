param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\minimap"))
# Makes the minimap shapes of pfUI Octo's map styles (modules/minimap-style.lua):
#   mask-<shape>.tga     128 x 128, white inside the shape, clear outside -
#                        Minimap:SetMaskTexture shows the map where it is white
#   outline-<shape>.tga  256 x 256, a thin white line along the shape's edge,
#                        tinted in game (the border of that shape)
# Uncompressed 32-bit TGA, bottom-left origin, 4 x 4 samples per pixel for
# smooth edges. Same output every run. The round shape uses the game's own
# mask (textures\MinimapMask), square uses pfUI's img\minimap.
#   powershell -ExecutionPolicy Bypass -File tools\MakeMinimapMasks.ps1

$src = @"
using System;
using System.IO;
public static class Shapes {
  // u, v in -1..1 (v up). true when inside the shape.
  public static bool Inside(string kind, double u, double v) {
    double au = Math.Abs(u), av = Math.Abs(v);
    switch (kind) {
      case "square":   return au <= 1 && av <= 1;
      case "round":    return u * u + v * v <= 1;
      case "rounded":  return Box(au, av, 0.22);
      case "rounder":  return Box(au, av, 0.45);
      case "squircle": return Math.Pow(au, 4) + Math.Pow(av, 4) <= 1;
      case "octagon":  return au <= 1 && av <= 1 && au + av <= 1.4142;
      case "diamond":  return au + av <= 1;
      // one square corner, the rest round (SexyMap's corner shapes)
      case "corner-tl": return (u <= 0 && v >= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-tr": return (u >= 0 && v >= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-bl": return (u <= 0 && v <= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-br": return (u >= 0 && v <= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
    }
    return false;
  }

  // a box with corner radius r
  static bool Box(double au, double av, double r) {
    double qx = au - (1 - r), qy = av - (1 - r);
    double ox = Math.Max(qx, 0), oy = Math.Max(qy, 0);
    return Math.Sqrt(ox * ox + oy * oy) + Math.Min(Math.Max(qx, qy), 0) - r <= 0;
  }

  // coverage 0..1 of a pixel: mask = inside; outline = inside but not inside
  // the shape shrunk by `line` pixels (pad: room so the line is not cut)
  static double Cover(string kind, int x, int y, int size, bool outline, double line, double pad) {
    int n = 4, hit = 0;
    double half = size / 2.0, scale = (half - pad) / half;
    double inner = (half - pad - line) / (half - pad);
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        double px = x + (i + 0.5) / n, py = y + (j + 0.5) / n;
        double u = (px - half) / half / scale, v = (py - half) / half / scale;
        bool a = Inside(kind, u, v);
        if (outline) a = a && !Inside(kind, u / inner, v / inner);
        if (a) hit++;
      }
    }
    return hit / (double)(n * n);
  }

  public static void Write(string path, string kind, int size, bool outline, double line, double pad) {
    using (var f = new BinaryWriter(File.Create(path))) {
      f.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      f.Write((ushort)size); f.Write((ushort)size);
      f.Write((byte)32); f.Write((byte)8);
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          byte a = (byte)Math.Round(Cover(kind, x, y, size, outline, line, pad) * 255);
          // white where covered, black and clear outside (works as mask either way)
          byte c = a;
          f.Write(c); f.Write(c); f.Write(c); f.Write(a);
        }
      }
    }
  }
}
"@
Add-Type -TypeDefinition $src

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$shapes = "rounded", "rounder", "squircle", "octagon", "diamond", "corner-tl", "corner-tr", "corner-bl", "corner-br"
# (round: the game masks the real map; this one draws the options preview)
foreach ($s in $shapes + "round") {
  [Shapes]::Write((Join-Path $OutDir "mask-$s.tga"), $s, 128, $false, 0, 0)
}
foreach ($s in $shapes + "round", "square") {
  # 256 px over the map's size: a 3 px line, 2 px from the edge
  [Shapes]::Write((Join-Path $OutDir "outline-$s.tga"), $s, 256, $true, 3, 2)
}
Get-ChildItem $OutDir -Filter *.tga | ForEach-Object { "{0,-24} {1,7} bytes" -f $_.Name, $_.Length }
