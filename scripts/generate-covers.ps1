<#
.SYNOPSIS
    Generates reusable tag-based cover banners for blog posts.

.DESCRIPTION
    Creates 1200x630 PNG banners (OG-standard) for each tag, with a consistent
    layout (gradient + dot grid + isometric cubes) but a tag-specific accent
    color. Banners are written to src/content/assets/<tag>-cover.png.

    Layout note: the left half of each banner is intentionally left clean so
    the article title + metadata pill (rendered by [post].astro) sits there
    without overlapping the visual elements.

.PARAMETER OutputDir
    Where to write the generated PNGs. Defaults to src/content/assets/.

.PARAMETER Tag
    Optional. Generate only one tag's banner (e.g. -Tag azure). Without this,
    generates all defined tags.

.EXAMPLE
    pwsh scripts/generate-covers.ps1
    # Regenerates every tag banner.

.EXAMPLE
    pwsh scripts/generate-covers.ps1 -Tag azure
    # Regenerates only the Azure banner.

.NOTES
    To add a new tag banner: add an entry to the $Palettes hash table below,
    then re-run the script.
#>

param(
    [string]$OutputDir = "$PSScriptRoot\..\src\content\assets",
    [string]$Tag = ""
)

Add-Type -AssemblyName System.Drawing

# Tag -> color palette (Dark1, Dark2, Accent)
# Dark1 = upper-left gradient stop, Dark2 = lower-right gradient stop, Accent = cube highlight.
$Palettes = @{
    azure      = @{ Dark1 = @(5,12,35);   Dark2 = @(0,90,180);    Accent = @(120,220,255) }
    devops     = @{ Dark1 = @(10,30,20);  Dark2 = @(20,140,90);   Accent = @(140,255,200) }
    kubernetes = @{ Dark1 = @(5,15,45);   Dark2 = @(50,100,210);  Accent = @(160,200,255) }
    terraform  = @{ Dark1 = @(25,10,55);  Dark2 = @(110,80,220);  Accent = @(200,170,255) }
    "ci-cd"    = @{ Dark1 = @(30,15,5);   Dark2 = @(210,110,30);  Accent = @(255,200,140) }
    notes      = @{ Dark1 = @(15,15,20);  Dark2 = @(70,70,90);    Accent = @(200,200,220) }
    guide      = @{ Dark1 = @(5,25,25);   Dark2 = @(20,140,140);  Accent = @(150,230,230) }
    linux      = @{ Dark1 = @(5,10,5);    Dark2 = @(15,50,15);    Accent = @(120,255,140) }
}

function New-CoverImage {
    param(
        [string]$TagName,
        [hashtable]$Palette,
        [string]$OutPath
    )

    $w = 1200; $h = 630
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $d1 = $Palette.Dark1; $d2 = $Palette.Dark2; $a = $Palette.Accent

    # 1) Diagonal gradient background
    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(255, $d1[0], $d1[1], $d1[2]),
        [System.Drawing.Color]::FromArgb(255, $d2[0], $d2[1], $d2[2]),
        25.0)
    $g.FillRectangle($bg, $rect)

    # 2) Subtle dot grid
    $dot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, $a[0], $a[1], $a[2]))
    for ($x = 30; $x -lt $w; $x += 40) {
        for ($y = 30; $y -lt $h; $y += 40) {
            $g.FillEllipse($dot, $x, $y, 2, 2)
        }
    }

    # 3) Soft highlight from upper-right
    $highlight = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle ([int]($w * 0.55)), 0, ([int]($w * 0.5)), $h),
        [System.Drawing.Color]::FromArgb(60, $a[0], $a[1], $a[2]),
        [System.Drawing.Color]::FromArgb(0, 0, 0, 0),
        225.0)
    $g.FillRectangle($highlight, ([int]($w * 0.55)), 0, ([int]($w * 0.5)), $h)

    # 4) Isometric cubes on the right side
    function DrawCube {
        param([int]$cx, [int]$cy, [int]$size, [int]$alpha, [int[]]$accentColor)
        $s = $size
        $halfH = [int]($s * 0.5)
        $top = @(
            (New-Object System.Drawing.Point $cx, ($cy - $s)),
            (New-Object System.Drawing.Point ($cx + $s), ($cy - $halfH)),
            (New-Object System.Drawing.Point $cx, $cy),
            (New-Object System.Drawing.Point ($cx - $s), ($cy - $halfH))
        )
        $left = @(
            (New-Object System.Drawing.Point ($cx - $s), ($cy - $halfH)),
            (New-Object System.Drawing.Point $cx, $cy),
            (New-Object System.Drawing.Point $cx, ($cy + $s)),
            (New-Object System.Drawing.Point ($cx - $s), ($cy + $halfH))
        )
        $right = @(
            (New-Object System.Drawing.Point ($cx + $s), ($cy - $halfH)),
            (New-Object System.Drawing.Point $cx, $cy),
            (New-Object System.Drawing.Point $cx, ($cy + $s)),
            (New-Object System.Drawing.Point ($cx + $s), ($cy + $halfH))
        )
        $bTop   = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, $accentColor[0], $accentColor[1], $accentColor[2]))
        $bLeft  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, [int]($accentColor[0] * 0.5), [int]($accentColor[1] * 0.6), [int]($accentColor[2] * 0.8)))
        $bRight = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, [int]($accentColor[0] * 0.25), [int]($accentColor[1] * 0.35), [int]($accentColor[2] * 0.6)))
        $script:g.FillPolygon($bTop, $top)
        $script:g.FillPolygon($bLeft, $left)
        $script:g.FillPolygon($bRight, $right)
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb([int]($alpha * 0.7), [int]($accentColor[0] * 0.9), [int]($accentColor[1] * 0.95), $accentColor[2])), 1.5
        $script:g.DrawPolygon($pen, $top)
        $script:g.DrawPolygon($pen, $left)
        $script:g.DrawPolygon($pen, $right)
    }

    $script:g = $g
    DrawCube 950 380 80 230 $a
    DrawCube 1050 280 60 200 $a
    DrawCube 870 250 50 170 $a
    DrawCube 1080 430 50 180 $a
    DrawCube 920 480 40 150 $a

    # 5) Corner accent strokes
    $accentPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(200, $a[0], $a[1], $a[2])), 3
    $g.DrawLine($accentPen, ($w - 60), 30, ($w - 30), 60)
    $g.DrawLine($accentPen, ($w - 100), 30, ($w - 30), 100)

    $g.Dispose()
    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    "Generated [$TagName] -> $OutPath  ($((Get-Item $OutPath).Length) bytes)"
}

# --- main ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$tagsToGenerate = if ($Tag) { @($Tag) } else { $Palettes.Keys }

foreach ($t in $tagsToGenerate) {
    if (-not $Palettes.ContainsKey($t)) {
        Write-Warning "No palette defined for tag '$t'. Skipping. (Add it to `$Palettes in this script.)"
        continue
    }
    $outFile = Join-Path $OutputDir "$t-cover.png"
    New-CoverImage -TagName $t -Palette $Palettes[$t] -OutPath $outFile
}
