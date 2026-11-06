param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\plates"))
# Draws pfUI Octo's nameplate art (modules/plates.lua). Our own drawings:
# Plater's textures are All Rights Reserved, so none of them is used.
#   bar-flat / soft / gloss / glass / split  256 x 32  health and cast bar fills
#   arrow      64 x 64  target arrow, points right (the left one is mirrored)
#   chevron    64 x 64  double arrow, points right
#   corner     32 x 32  an L in the top left corner (turned for the others)
#   underglow 256 x 64  soft light under the target's bar
#   spark      32 x 64  the bright edge of a filling cast bar
#   star       32 x 32  elite / rare mark, dark outline
#   skull      32 x 32  boss mark, dark outline
#   tick        8 x 32  execute marker on the bar
#   quest-objective / quest-start / quest-end / pet  32 x 32  marks by the name
# and into img\bars (action buttons):
#   btn-inner / gloss / corners  64 x 64  hover and press looks
#   btn-grad / stripes / dots    64 x 64  empty slot fills
#   btn-ring  64 x 64  proc burst      btn-edge  64 x 16  cooldown edge
#   bar-smooth / bevel / steel / cloud / diagonal / pill / minimal  256 x 32  more bar fills
#   uf-elite / uf-rare  64 x 32  unit frame badges   uf-afk / uf-offline  32 x 32  status marks
# White (grey shading) + alpha, tinted in game. Uncompressed 32-bit TGA,
# bottom-left origin, 4 x 4 samples per pixel. Same output every run.
#   powershell -ExecutionPolicy Bypass -File tools\MakePlateArt.ps1

$src = @"
using System;
using System.IO;
public static class Art {
  static bool Poly(double[] p, double x, double y) {
    bool c = false;
    int n = p.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = p[2 * i], yi = p[2 * i + 1], xj = p[2 * j], yj = p[2 * j + 1];
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) c = !c;
    }
    return c;
  }
  static bool Circle(double x, double y, double cx, double cy, double r) {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
  }
  static double[] Star() {
    double[] p = new double[20];
    for (int i = 0; i < 10; i++) {
      double r = (i % 2 == 0) ? 0.46 : 0.19;
      double a = Math.PI / 2 + i * Math.PI / 5;
      p[2 * i] = 0.5 + r * Math.Cos(a);
      p[2 * i + 1] = 0.47 + r * Math.Sin(a);
    }
    return p;
  }
  static readonly double[] STAR = Star();
  static readonly double[] CROWN = { 0.12, 0.2, 0.88, 0.2, 0.9, 0.72, 0.7, 0.48, 0.5, 0.82, 0.3, 0.48, 0.1, 0.72 };
  static readonly double[] SHIELD = { 0.16, 0.86, 0.84, 0.86, 0.84, 0.5, 0.5, 0.1, 0.16, 0.5 };
  static readonly double[] SPARKLE = { 0.5, 0.95, 0.6, 0.6, 0.95, 0.5, 0.6, 0.4, 0.5, 0.05, 0.4, 0.4, 0.05, 0.5, 0.4, 0.6 };
  static readonly double[] HEX = { 0.5, 0.92, 0.86, 0.71, 0.86, 0.29, 0.5, 0.08, 0.14, 0.29, 0.14, 0.71 };
  static readonly double[] ARROW = { 0.12, 0.14, 0.88, 0.5, 0.12, 0.86, 0.34, 0.5 };
  static readonly double[] CHEV1 = { 0.06, 0.12, 0.26, 0.12, 0.54, 0.5, 0.26, 0.88, 0.06, 0.88, 0.34, 0.5 };
  static readonly double[] CHEV2 = { 0.40, 0.12, 0.60, 0.12, 0.88, 0.5, 0.60, 0.88, 0.40, 0.88, 0.68, 0.5 };

  // a shape grown around (cx, cy): the outline is "grown but not the shape"
  static bool StarAt(double x, double y, double s) { return Poly(STAR, 0.5 + (x - 0.5) / s, 0.47 + (y - 0.47) / s); }
  static bool Skull(double x, double y, double s) {
    x = 0.5 + (x - 0.5) / s; y = 0.5 + (y - 0.5) / s;
    bool head = Circle(x, y, 0.5, 0.58, 0.33);
    bool jaw = x >= 0.32 && x <= 0.68 && y >= 0.14 && y <= 0.36;
    return head || jaw;
  }
  static bool SkullHole(double x, double y) {
    bool eye = Circle(x, y, 0.37, 0.55, 0.095) || Circle(x, y, 0.63, 0.55, 0.095);
    bool nose = Poly(new double[] { 0.5, 0.45, 0.45, 0.36, 0.55, 0.36 }, x, y);
    bool teeth = y >= 0.14 && y <= 0.27 && (Math.Abs(x - 0.42) < 0.018 || Math.Abs(x - 0.5) < 0.018 || Math.Abs(x - 0.58) < 0.018);
    return eye || nose || teeth;
  }

  // an exclamation mark between y0 and y1 (v up) around x = cx; grow = outline
  static bool Bang(double x, double y, double cx, double y0, double y1, double grow = 0) {
    double h = y1 - y0, w = 0.07 + grow;
    bool stem = Math.Abs(x - cx) <= w && y >= y0 + h * 0.32 - grow && y <= y1 + grow;
    bool dot = Circle(x, y, cx, y0 + h * 0.1, h * 0.1 + grow);
    return stem || dot;
  }
  // a question mark: a ring arc, a short stem and a dot
  static bool Ask(double x, double y, double grow) {
    double r = Math.Sqrt((x - 0.5) * (x - 0.5) + (y - 0.66) * (y - 0.66));
    double ang = Math.Atan2(y - 0.66, x - 0.5) * 180 / Math.PI;
    bool arc = r >= 0.13 - grow && r <= 0.27 + grow && (ang >= -50 || ang >= 150 || ang <= -170);
    bool stem = Math.Abs(x - 0.5) <= 0.07 + grow && y >= 0.3 - grow && y <= 0.5;
    bool dot = Circle(x, y, 0.5, 0.14, 0.08 + grow);
    return arc || stem || dot;
  }

  // repeatable noise (same output every run)
  static double Noise(double x, double seed) {
    double s = Math.Sin(x * 12.9898 + seed * 78.233) * 43758.5453;
    return s - Math.Floor(s) - 0.5;
  }
  static double Smooth(double x, double y, double seed) {
    double xi = Math.Floor(x), yi = Math.Floor(y), xf = x - xi, yf = y - yi;
    Func<double, double, double> h = (a, b) => Noise(a * 57 + b * 131, seed);
    double sx = xf * xf * (3 - 2 * xf), sy = yf * yf * (3 - 2 * yf);
    double top = h(xi, yi) * (1 - sx) + h(xi + 1, yi) * sx;
    double bot = h(xi, yi + 1) * (1 - sx) + h(xi + 1, yi + 1) * sx;
    return (top * (1 - sy) + bot * sy) * 2;
  }
  // a "Z" in the box x0..x1, y0..y1 (v up), stroke w
  static bool ZigZag(double u, double v, double x0, double x1, double y0, double y1, double w) {
    if (u < x0 - w || u > x1 + w || v < y0 - w || v > y1 + w) return false;
    bool top = Math.Abs(v - y1) < w && u >= x0 - w && u <= x1 + w;
    bool bot = Math.Abs(v - y0) < w && u >= x0 - w && u <= x1 + w;
    double t = (v - y0) / (y1 - y0);
    double xd = x0 + t * (x1 - x0);
    bool diag = Math.Abs(u - xd) < w * 1.3 && v >= y0 && v <= y1;
    return top || bot || diag;
  }

  // one sample: u, v in 0..1 (v up); lum 0..1 (shading), a 0..1 (cover)
  public static void Sample(string kind, double u, double v, double pw, double ph, out double lum, out double a) {
    lum = 1; a = 1;
    switch (kind) {
      case "bar-flat":
        lum = v > 1 - ph ? 1.0 : (v < ph ? 0.72 : 0.9);
        return;
      case "bar-soft":
        lum = 0.68 + 0.32 * v;
        return;
      case "bar-gloss":
        lum = v >= 0.5 ? 1.0 - 0.12 * (v - 0.5) * 2 : 0.70 + 0.12 * v * 2;
        if (v > 1 - ph) lum = 1.0;
        return;
      case "bar-glass": {
        double hl = Math.Exp(-Math.Pow((v - 0.72) / 0.09, 2));
        lum = Math.Min(1.0, 0.80 + 0.20 * hl - (v < 0.25 ? (0.25 - v) * 0.6 : 0));
        return;
      }
      case "bar-split":
        lum = v > 0.58 ? 1.0 : (v > 0.52 ? 0.78 + (v - 0.52) / 0.06 * 0.22 : 0.78);
        return;
      case "arrow":
        a = Poly(ARROW, u, v) ? 1 : 0;
        lum = 0.82 + 0.18 * v;
        return;
      case "chevron":
        a = (Poly(CHEV1, u, v) || Poly(CHEV2, u, v)) ? 1 : 0;
        lum = 0.82 + 0.18 * v;
        return;
      case "corner": {
        double t = 0.16;
        a = ((v >= 1 - t) || (u <= t)) ? 1 : 0;
        return;
      }
      case "underglow": {
        double dx = (u - 0.5) / 0.36, dy = (v - 0.5) / 0.30;
        a = Math.Exp(-(dx * dx + dy * dy) * 2.2);
        return;
      }
      case "spark": {
        double dx = (u - 0.5) / 0.16, dy = (v - 0.5) / 0.5;
        a = Math.Exp(-dx * dx * 2.5) * Math.Max(0, 1 - Math.Pow(Math.Abs(dy), 3));
        return;
      }
      case "star":
        if (StarAt(u, v, 1.0)) { lum = 0.75 + 0.25 * v; a = 1; }
        else if (StarAt(u, v, 1.16)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      case "skull":
        if (Skull(u, v, 1.0)) { if (SkullHole(u, v)) { lum = 0; a = 1; } else { lum = 0.8 + 0.2 * v; a = 1; } }
        else if (Skull(u, v, 1.12)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      case "tick":
        a = 1;
        lum = Math.Abs(u - 0.5) < 0.2 ? 1.0 : 0.0;
        return;
      // quest marks: a diamond with "!" (objective), "!" (quest to take), "?" (quest to hand in)
      case "quest-objective": {
        double d = Math.Abs(u - 0.5) + Math.Abs(v - 0.5);
        bool mark = Bang(u, v, 0.5, 0.2, 0.62);
        if (d <= 0.40) { lum = mark ? 0.0 : 0.8 + 0.2 * v; a = 1; }
        else if (d <= 0.47) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      }
      case "quest-start":
        if (Bang(u, v, 0.5, 0.08, 0.92)) { lum = 0.85 + 0.15 * v; a = 1; }
        else if (Bang(u, v, 0.5, 0.04, 0.96, 0.06)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      case "quest-end":
        if (Ask(u, v, 0)) { lum = 0.85 + 0.15 * v; a = 1; }
        else if (Ask(u, v, 0.05)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      // combo points: a lit orb, a cut gem, a bevelled square, an empty ring, a soft glow
      case "cp-orb": {
        double r = Math.Sqrt((u - .5) * (u - .5) + (v - .5) * (v - .5));
        if (r <= .40) {
          double hl = Math.Max(0, 1 - Math.Sqrt((u - .38) * (u - .38) + (v - .64) * (v - .64)) / .30);
          lum = Math.Min(1, .45 + .35 * (1 - r / .40) + .55 * hl * hl); a = 1;
        } else if (r <= .47) { lum = 0; a = .9; }
        else a = 0;
        return;
      }
      case "cp-gem": {
        double d = Math.Abs(u - .5) + Math.Abs(v - .5);
        if (d <= .40) {
          bool top = v >= .5, left = u < .5;
          lum = top ? (left ? 1.0 : .82) : (left ? .7 : .55);
          if (d <= .16) lum = Math.Min(1, lum + .15);
          a = 1;
        } else if (d <= .47) { lum = 0; a = .9; }
        else a = 0;
        return;
      }
      case "cp-square": {
        double au = Math.Abs(u - .5), av = Math.Abs(v - .5);
        double m = Math.Max(au, av);
        if (m <= .36) {
          lum = .78;
          if (m > .28) lum = (v > .5 || u < .5) ? 1.0 : .5;
          a = 1;
        } else if (m <= .43) { lum = 0; a = .9; }
        else a = 0;
        return;
      }
      case "cp-ring": {
        double r = Math.Sqrt((u - .5) * (u - .5) + (v - .5) * (v - .5));
        if (r <= .40 && r >= .30) { lum = .9; a = 1; }
        else if (r <= .47 && r >= .24) { lum = 0; a = .8; }
        else a = 0;
        return;
      }
      case "cp-glow": {
        double r = Math.Sqrt((u - .5) * (u - .5) + (v - .5) * (v - .5));
        a = Math.Exp(-r * r * 18);
        return;
      }
      // marks to choose from (elite / rare / boss / quest): solid shapes, dark outline
      case "mark-crown": case "mark-shield": case "mark-sparkle": case "mark-hex": {
        double[] poly = kind == "mark-crown" ? CROWN : kind == "mark-shield" ? SHIELD : kind == "mark-sparkle" ? SPARKLE : HEX;
        if (Poly(poly, u, v)) { lum = 0.72 + 0.28 * v; a = 1; }
        else if (Poly(poly, 0.5 + (u - 0.5) / 1.14, 0.5 + (v - 0.5) / 1.14)) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      }
      case "quest-circle": case "quest-circle-ask": {
        double r = Math.Sqrt((u - .5) * (u - .5) + (v - .5) * (v - .5));
        bool sign = kind == "quest-circle" ? Bang(u, v, 0.5, 0.2, 0.8) : Ask(0.5 + (u - 0.5) * 1.35, 0.5 + (v - 0.5) * 1.35, 0);
        if (r <= .42) { lum = sign ? 0.0 : 0.75 + 0.25 * v; a = 1; }
        else if (r <= .48) { lum = 0; a = .9; }
        else a = 0;
        return;
      }
      // action buttons (img\bars): hover / press looks, empty slot fills, proc ring, cooldown edge
      case "btn-inner": {
        double d = Math.Min(Math.Min(u, 1 - u), Math.Min(v, 1 - v));
        a = Math.Exp(-d / 0.09);
        return;
      }
      case "btn-gloss": {
        double y0 = 0.5 + 0.1 * Math.Cos((u - 0.5) * Math.PI);
        double s = Math.Max(0, Math.Min(1, (v - y0) / 0.04));
        a = s * (0.12 + 0.45 * Math.Max(0, (v - y0) / (1 - y0)));
        return;
      }
      case "btn-corners": {
        double t = 0.09, len = 0.32;
        bool edge = u < t || v < t || u > 1 - t || v > 1 - t;
        bool corner = (u < len || u > 1 - len) && (v < len || v > 1 - len);
        a = edge && corner ? 1 : 0;
        return;
      }
      case "btn-grad":
        lum = 0.45 + 0.55 * v;
        return;
      case "btn-stripes":
        a = ((u + v) * 6) % 1.0 < 0.5 ? 1 : 0.4;
        return;
      case "btn-dots": {
        double cu = (u * 4) % 1.0 - 0.5, cv = (v * 4) % 1.0 - 0.5;
        a = cu * cu + cv * cv < 0.04 ? 1 : 0.35;
        return;
      }
      case "btn-ring": {
        double r = Math.Sqrt((u - .5) * (u - .5) + (v - .5) * (v - .5));
        a = Math.Exp(-Math.Pow((r - 0.40) / 0.06, 2));
        return;
      }
      case "btn-edge":
        a = Math.Exp(-Math.Pow((v - 0.5) / 0.2, 2));
        return;
      // more bar fills (unit frames, castbar, xp... every texture menu)
      case "bar-smooth":
        lum = 0.72 + 0.28 * Math.Sin(v * Math.PI);
        return;
      case "bar-bevel":
        lum = v > 1 - 2 * ph ? 1.0 : (v < 2 * ph ? 0.5 : 0.78 + 0.1 * v);
        return;
      case "bar-steel": {
        double n = Noise(Math.Floor(v * 32), 7) * 0.08 + Noise(Math.Floor(u * 256) * 0.05 + Math.Floor(v * 32), 3) * 0.05;
        lum = 0.74 + 0.16 * v + n;
        return;
      }
      case "bar-cloud": {
        double n = Smooth(u * 9, v * 3, 11) * 0.6 + Smooth(u * 23, v * 7, 5) * 0.4;
        lum = 0.8 + 0.1 * n + 0.08 * v;
        return;
      }
      case "bar-diagonal":
        lum = ((u * 256 + v * 32) / 10.0 % 1.0) < 0.5 ? 0.92 : 0.78;
        lum += 0.08 * (v - 0.5);
        return;
      case "bar-pill": {
        double d = Math.Abs(v - 0.5) * 2;
        lum = 0.95 - 0.35 * d * d;
        if (v > 0.6 && v < 0.75) lum = Math.Min(1, lum + 0.08);
        return;
      }
      case "bar-minimal":
        lum = v > 1 - ph ? 1.0 : 0.85;
        return;
      // swing timer looks (modules/swing.lua): our own art in the styles
      // WeaponSwingTimer offers (its art is GPL-3 and was not used)
      case "swing-cdm":
        // a soft fill, lighter at the top with a thin shine line
        lum = 0.70 + 0.26 * v;
        if (v > 1 - 3 * ph && v < 1 - ph) lum = 1.0;
        return;
      case "swing-frame": case "swing-back": {
        // a rounded box: the frame is a 2 px line, the back the filled inside
        double W = 1 / pw, H = 1 / ph, x = u * W, y = v * H, r = Math.Min(10, H / 2 - 1);
        double cx = Math.Max(r + 1, Math.Min(W - r - 1, x)), cy = Math.Max(r + 1, Math.Min(H - r - 1, y));
        double d = Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r;
        bool corner = (x < r + 1 || x > W - r - 1) && (y < r + 1 || y > H - r - 1);
        double edge = corner ? d : Math.Max(Math.Max(1 - x, x - (W - 1)), Math.Max(1 - y, y - (H - 1)));
        if (kind == "swing-frame") { a = Math.Max(0, Math.Min(1, 1.5 - Math.Abs(edge + 1))); lum = 0.9 + 0.1 * v; }
        else { a = edge < 0 ? Math.Min(1, -edge) : 0; lum = 0.25; }
        return;
      }
      case "swing-diamond": {
        // a gold diamond with a dark rim
        double dd = Math.Abs(u - 0.5) + Math.Abs(v - 0.5);
        if (dd > 0.47) { a = 0; return; }
        lum = dd > 0.38 ? 0.25 : 0.75 + 0.25 * (1 - dd / 0.38) * v;
        return;
      }
      // unit frame badges and status marks
      case "uf-elite": case "uf-rare": {
        // a crest: two swept wings round a diamond
        double x = u, y = v;
        bool diamond = Math.Abs(x - 0.5) * 2.2 + Math.Abs(y - 0.5) * 1.6 <= 0.62;
        bool wingL = Poly(new double[] { 0.42, 0.62, 0.05, 0.92, 0.12, 0.62, 0.0, 0.5, 0.14, 0.38, 0.04, 0.12, 0.42, 0.36 }, x, y);
        bool wingR = Poly(new double[] { 0.58, 0.62, 0.95, 0.92, 0.88, 0.62, 1.0, 0.5, 0.86, 0.38, 0.96, 0.12, 0.58, 0.36 }, x, y);
        bool inner = Math.Abs(x - 0.5) * 2.2 + Math.Abs(y - 0.5) * 1.6 <= 0.34;
        if (diamond) { lum = inner ? 1.0 : 0.72 + 0.28 * y; a = 1; }
        else if (wingL || wingR) { lum = 0.6 + 0.4 * y; a = 1; }
        else {
          bool edge = Math.Abs(x - 0.5) * 2.2 + Math.Abs(y - 0.5) * 1.6 <= 0.72
            || Poly(new double[] { 0.42, 0.68, 0.0, 1.0, 0.06, 0.62, -0.06, 0.5, 0.08, 0.38, -0.02, 0.04, 0.42, 0.3 }, x, y)
            || Poly(new double[] { 0.58, 0.68, 1.0, 1.0, 0.94, 0.62, 1.06, 0.5, 0.92, 0.38, 1.02, 0.04, 0.58, 0.3 }, x, y);
          if (edge) { lum = 0; a = 0.85; } else a = 0;
        }
        return;
      }
      case "uf-afk": {
        // "Zz": two zigzags
        bool z1 = ZigZag(u, v, 0.12, 0.5, 0.55, 0.92, 0.07);
        bool z2 = ZigZag(u, v, 0.55, 0.85, 0.12, 0.45, 0.06);
        bool o1 = ZigZag(u, v, 0.12, 0.5, 0.55, 0.92, 0.12);
        bool o2 = ZigZag(u, v, 0.55, 0.85, 0.12, 0.45, 0.11);
        if (z1 || z2) { lum = 0.85 + 0.15 * v; a = 1; }
        else if (o1 || o2) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      }
      case "uf-offline": {
        // a plug pulled out: body, two prongs, a slash
        bool body = u >= 0.3 && u <= 0.7 && v >= 0.3 && v <= 0.62;
        bool prong = (Math.Abs(u - 0.4) < 0.045 || Math.Abs(u - 0.6) < 0.045) && v > 0.62 && v < 0.85;
        bool cable = Math.Abs(u - 0.5) < 0.06 && v < 0.3 && v > 0.08;
        bool slash = Math.Abs((u - 0.5) - (v - 0.5)) < 0.06 && Math.Abs(u - 0.5) < 0.42;
        bool rim = (u >= 0.25 && u <= 0.75 && v >= 0.25 && v <= 0.67) || ((Math.Abs(u - 0.4) < 0.09 || Math.Abs(u - 0.6) < 0.09) && v > 0.6 && v < 0.9)
          || (Math.Abs(u - 0.5) < 0.11 && v < 0.32 && v > 0.03) || (Math.Abs((u - 0.5) - (v - 0.5)) < 0.11 && Math.Abs(u - 0.5) < 0.46);
        if (slash) { lum = 0.95; a = 1; }
        else if (body || prong || cable) { lum = 0.75 + 0.2 * v; a = 1; }
        else if (rim) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      }
      case "pet": {
        bool pad = Circle(u, v, 0.5, 0.36, 0.2);
        bool toes = Circle(u, v, 0.22, 0.62, 0.09) || Circle(u, v, 0.4, 0.76, 0.09) || Circle(u, v, 0.6, 0.76, 0.09) || Circle(u, v, 0.78, 0.62, 0.09);
        bool edge = Circle(u, v, 0.5, 0.36, 0.25) || Circle(u, v, 0.22, 0.62, 0.135) || Circle(u, v, 0.4, 0.76, 0.135)
          || Circle(u, v, 0.6, 0.76, 0.135) || Circle(u, v, 0.78, 0.62, 0.135);
        if (pad || toes) { lum = 0.85 + 0.15 * v; a = 1; }
        else if (edge) { lum = 0; a = 0.9; }
        else a = 0;
        return;
      }
    }
  }

  public static void Write(string path, string kind, int w, int h) {
    using (var f = new BinaryWriter(File.Create(path))) {
      f.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      f.Write((ushort)w); f.Write((ushort)h);
      f.Write((byte)32); f.Write((byte)8);
      int n = 4;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          double sa = 0, sl = 0;
          for (int i = 0; i < n; i++) {
            for (int j = 0; j < n; j++) {
              double lum, a;
              Sample(kind, (x + (i + 0.5) / n) / w, (y + (j + 0.5) / n) / h, 1.0 / h, 1.0 / h, out lum, out a);
              sa += a; sl += lum * a;
            }
          }
          double alpha = sa / (n * n);
          double l = sa > 0 ? sl / sa : 0;
          byte c = (byte)Math.Round(Math.Max(0, Math.Min(1, l)) * 255);
          f.Write(c); f.Write(c); f.Write(c); f.Write((byte)Math.Round(alpha * 255));
        }
      }
    }
  }
}
"@
Add-Type -TypeDefinition $src

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$list = @(
  @("bar-flat", 256, 32), @("bar-soft", 256, 32), @("bar-gloss", 256, 32), @("bar-glass", 256, 32), @("bar-split", 256, 32),
  @("arrow", 64, 64), @("chevron", 64, 64), @("corner", 32, 32), @("underglow", 256, 64), @("spark", 32, 64),
  @("star", 32, 32), @("skull", 32, 32), @("tick", 8, 32),
  @("quest-objective", 32, 32), @("quest-start", 32, 32), @("quest-end", 32, 32), @("pet", 32, 32),
  @("cp-orb", 32, 32), @("cp-gem", 32, 32), @("cp-square", 32, 32), @("cp-ring", 32, 32), @("cp-glow", 32, 32),
  @("mark-crown", 32, 32), @("mark-shield", 32, 32), @("mark-sparkle", 32, 32), @("mark-hex", 32, 32),
  @("quest-circle", 32, 32), @("quest-circle-ask", 32, 32)
)
foreach ($t in $list) {
  [Art]::Write((Join-Path $OutDir ($t[0] + ".tga")), $t[0], $t[1], $t[2])
}
Get-ChildItem $OutDir -Filter *.tga | ForEach-Object { "{0,-16} {1,7} bytes" -f $_.Name, $_.Length }

# action button art (modules/actionbar-octo.lua), next to the plates' folder
$BarDir = Join-Path (Split-Path $OutDir -Parent) "bars"
if (-not (Test-Path $BarDir)) { New-Item -ItemType Directory -Force $BarDir | Out-Null }
$bars = @(
  @("btn-inner", 64, 64), @("btn-gloss", 64, 64), @("btn-corners", 64, 64), @("btn-grad", 64, 64),
  @("btn-stripes", 64, 64), @("btn-dots", 64, 64), @("btn-ring", 64, 64), @("btn-edge", 64, 16),
  @("bar-smooth", 256, 32), @("bar-bevel", 256, 32), @("bar-steel", 256, 32), @("bar-cloud", 256, 32),
  @("bar-diagonal", 256, 32), @("bar-pill", 256, 32), @("bar-minimal", 256, 32),
  @("uf-elite", 64, 32), @("uf-rare", 64, 32), @("uf-afk", 32, 32), @("uf-offline", 32, 32),
  @("swing-cdm", 256, 32), @("swing-frame", 256, 32), @("swing-back", 256, 32), @("swing-diamond", 32, 32)
)
foreach ($t in $bars) {
  [Art]::Write((Join-Path $BarDir ($t[0] + ".tga")), $t[0], $t[1], $t[2])
}
Get-ChildItem $BarDir -Filter *.tga | ForEach-Object { "{0,-16} {1,7} bytes" -f $_.Name, $_.Length }
