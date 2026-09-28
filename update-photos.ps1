# ==========================================================
#  1 Jour 1 Ulysse - traitement des photos
#
#  1. Prend les photos du dossier originaux/ (jamais publie)
#  2. Cree des copies nettoyees dans photos/ :
#       - AUCUNE metadonnee (GPS, date, telephone...) : -strip
#       - redimensionnees (2000 px max) et allegees
#       - nom anonyme (empreinte du fichier), + miniature
#  3. Met a jour le calendrier (photos.js) :
#       - un jour passe garde TOUJOURS sa photo
#       - les jours suivants piochent d'abord dans les photos
#         jamais montrees, puis au hasard sans repetition proche
#  4. Avec -Publier : verifie tout, puis envoie sur GitHub.
# ==========================================================
param([switch]$Publier)

$ErrorActionPreference = 'Stop'
$root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir   = Join-Path $root 'originaux'
$outDir   = Join-Path $root 'photos'
$miniDir  = Join-Path $outDir 'mini'
$listFile = Join-Path $root 'photos.js'
$inv      = [Globalization.CultureInfo]::InvariantCulture

$MaxSide   = 2000   # taille max de la photo (px)
$MiniSide  = 480    # taille max de la miniature (px)
$Quality   = 82     # qualite JPEG
$Horizon   = 365    # nombre de jours planifies a l'avance (apres les photos jamais montrees)
$Exts      = @('.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.avif', '.gif', '.tif', '.tiff', '.bmp')

function Say($msg, $color = 'Gray') { Write-Host "  $msg" -ForegroundColor $color }
function Fail($msg) { Write-Host ''; Say $msg 'Red'; Write-Host ''; exit 1 }

# Verifie qu'un JPEG ne contient que l'image : aucun segment de metadonnees
# (APP1 = EXIF/GPS/XMP, APP2..APP15 = ICC/IPTC/Photoshop..., COM = commentaire)
# et rien d'accroche apres la fin de l'image (ex. video des « Motion Photos »).
function Test-CleanJpeg([string]$path) {
  $b = [IO.File]::ReadAllBytes($path)
  if ($b.Length -lt 4 -or $b[0] -ne 0xFF -or $b[1] -ne 0xD8) { return $false }
  if ($b[$b.Length - 2] -ne 0xFF -or $b[$b.Length - 1] -ne 0xD9) { return $false }
  $i = 2
  while ($i + 3 -lt $b.Length) {
    if ($b[$i] -ne 0xFF) { return $false }
    $m = $b[$i + 1]
    if ($m -eq 0xFF) { $i++; continue }
    if ($m -eq 0xDA) { return $true }                       # debut des donnees image
    if (($m -ge 0xE1 -and $m -le 0xEF) -or $m -eq 0xFE) { return $false }
    $i += 2 + ($b[$i + 2] * 256 + $b[$i + 3])
  }
  return $false
}

function Shuffle($items) { if (@($items).Count -eq 0) { return @() }; @($items | Sort-Object { Get-Random }) }

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
  Fail "ImageMagick est introuvable. Installez-le depuis https://imagemagick.org puis relancez."
}
foreach ($d in @($srcDir, $outDir, $miniDir)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }

Write-Host ''
Say '1 Jour 1 Ulysse' 'Yellow'
Write-Host ''

$sha = [Security.Cryptography.SHA256]::Create()
function Get-Hash([string]$path) {
  $s = [IO.File]::OpenRead($path)
  try { -join ($sha.ComputeHash($s)[0..7] | ForEach-Object { $_.ToString('x2') }) } finally { $s.Dispose() }
}

# Range un original dans originaux/ (sans jamais ecraser : doublon exact supprime, sinon renomme)
function Move-Original($file, [string]$destDir, [string]$name) {
  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir | Out-Null }
  $dest = Join-Path $destDir $name
  if (Test-Path $dest) {
    if ((Get-Hash $dest) -eq (Get-Hash $file.FullName)) { Remove-Item $file.FullName; return }
    $dest = Join-Path $destDir ('{0}-{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($name), (Get-Date -Format 'yyyyMMddHHmmss'), [IO.Path]::GetExtension($name))
  }
  Move-Item $file.FullName $dest
}

# ---------- 0. Photos deposees dans photos/ par erreur -> originaux/ ----------
# Le portrait (portrait.jpg, .png...) est range a part dans originaux/portrait/.
$portraitDir = Join-Path $srcDir 'portrait'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$moved = 0
foreach ($f in @(Get-ChildItem -Path $outDir -File) + @(Get-ChildItem -Path $srcDir -File | Where-Object { $_.BaseName -eq 'portrait' })) {
  if ($Exts -notcontains $f.Extension.ToLower()) { continue }
  if ($f.DirectoryName -eq $outDir -and $f.Name -match '^([0-9a-f]{16}|portrait)\.jpg$' -and (Test-CleanJpeg $f.FullName)) { continue }
  if ($f.BaseName -eq 'portrait') { Move-Original $f $portraitDir "portrait-$stamp$($f.Extension)" }
  else { Move-Original $f $srcDir $f.Name }
  $moved++
}
if ($moved) { Say "$moved photo(s) deplacee(s) de photos/ vers originaux/" 'DarkYellow' }

# ---------- 1. Traitement des nouvelles photos ----------
$added = 0; $failed = 0
$toProcess = Get-ChildItem -Path $srcDir -File -Recurse | Where-Object {
  $Exts -contains $_.Extension.ToLower() -and -not $_.FullName.StartsWith($portraitDir + '\')
}
foreach ($f in $toProcess) {
  $hash = Get-Hash $f.FullName
  $out  = Join-Path $outDir  "$hash.jpg"
  $mini = Join-Path $miniDir "$hash.jpg"
  if ((Test-Path $out) -and (Test-Path $mini)) { continue }

  Say "Traitement : $($f.Name)"
  $in = $f.FullName + '[0]'
  & magick $in -auto-orient -resize "${MaxSide}x${MaxSide}>" -strip -sampling-factor 4:2:0 -interlace JPEG -quality $Quality $out
  $ok1 = $LASTEXITCODE -eq 0
  & magick $in -auto-orient -resize "${MiniSide}x${MiniSide}^>" -strip -sampling-factor 4:2:0 -interlace JPEG -quality 78 $mini
  $ok2 = $LASTEXITCODE -eq 0
  if (-not ($ok1 -and $ok2)) {
    Say "  -> echec, photo ignoree" 'Red'; $failed++
    Remove-Item $out, $mini -ErrorAction SilentlyContinue
    continue
  }
  $added++
}

# Portrait de la presentation : le plus recent de originaux/portrait/ -> photos/portrait.jpg
$pSrc = Get-ChildItem -Path $portraitDir -File -ErrorAction SilentlyContinue |
  Where-Object { $Exts -contains $_.Extension.ToLower() } | Sort-Object Name -Descending | Select-Object -First 1
if ($pSrc) {
  & magick ($pSrc.FullName + '[0]') -auto-orient -resize '1400x1400>' -strip -sampling-factor 4:2:0 -interlace JPEG -quality $Quality (Join-Path $outDir 'portrait.jpg')
  if ($LASTEXITCODE -ne 0) { Say "Echec du traitement du portrait" 'Red' }
}

# Verification : toutes les photos publiables doivent etre propres
$dirty = @(Get-ChildItem -Path $outDir -File -Recurse -Filter *.jpg | Where-Object { -not (Test-CleanJpeg $_.FullName) })
if ($dirty.Count) {
  $dirty | ForEach-Object { Say "Metadonnees detectees : $($_.FullName)" 'Red' }
  Fail "Des photos de photos/ contiennent des metadonnees. Supprimez-les et relancez."
}
$stray = @(Get-ChildItem -Path $outDir -File -Recurse | Where-Object {
  $_.Name -notmatch '^[0-9a-f]{16}\.jpg$' -and -not ($_.Name -eq 'portrait.jpg' -and $_.DirectoryName -eq $outDir)
})
if ($stray.Count) {
  $stray | ForEach-Object { Say "Fichier inattendu : $($_.FullName)" 'Red' }
  Fail "Deposez vos photos dans originaux/, pas dans photos/. Deplacez ces fichiers puis relancez."
}

# ---------- 2. Calendrier ----------
$startIso = [regex]::Match([IO.File]::ReadAllText((Join-Path $root 'app.js')), 'START_DATE\s*=\s*"(\d{4}-\d{2}-\d{2})"').Groups[1].Value
if (-not $startIso) { Fail "START_DATE introuvable dans app.js" }
$start = [datetime]::ParseExact($startIso, 'yyyy-MM-dd', $inv)
$today = (Get-Date).Date
$key   = { param($d) $d.ToString('yyyy-MM-dd', $inv) }

$oldPool = @(); $cal = @{}
if (Test-Path $listFile) {
  $txt = [IO.File]::ReadAllText($listFile, [Text.Encoding]::UTF8)
  $poolBlock = [regex]::Match($txt, 'ULYSSE_PHOTOS\s*=\s*\[([^\]]*)\]').Groups[1].Value
  $oldPool = @([regex]::Matches($poolBlock, '"(photos/[^"]+)"') | ForEach-Object { $_.Groups[1].Value })
  foreach ($m in [regex]::Matches($txt, '"(\d{4}-\d{2}-\d{2})"\s*:\s*"(photos/[^"]+)"')) { $cal[$m.Groups[1].Value] = $m.Groups[2].Value }
}

# Jours deja affiches sans entree au calendrier : on fige ce que le site a montre
if ($oldPool.Count) {
  for ($d = $start; $d -le $today; $d = $d.AddDays(1)) {
    $k = & $key $d
    if (-not $cal.ContainsKey($k)) { $cal[$k] = $oldPool[(($d - $start).Days % $oldPool.Count)] }
  }
}

# Pool : ordre existant conserve, nouvelles photos ajoutees a la fin (au hasard)
$files = @(Get-ChildItem -Path $outDir -File -Filter *.jpg | Where-Object { $_.Name -match '^[0-9a-f]{16}\.jpg$' } | ForEach-Object { "photos/$($_.Name)" })
$fileSet = @{}; foreach ($p in $files) { $fileSet[$p] = $true }
$pool = @($oldPool | Where-Object { $fileSet.ContainsKey($_) })
$inPool = @{}; foreach ($p in $pool) { $inPool[$p] = $true }
$pool += Shuffle @($files | Where-Object { -not $inPool.ContainsKey($_) })

# On garde les jours passes (et aujourd'hui), on replanifie l'avenir
$used = @{}
foreach ($k in @($cal.Keys)) {
  $d = [datetime]::ParseExact($k, 'yyyy-MM-dd', $inv)
  if ($d -gt $today -or $d -lt $start -or -not $fileSet.ContainsKey($cal[$k])) { $cal.Remove($k) } else { $used[$cal[$k]] = $true }
}

if ($pool.Count) {
  $queue = New-Object System.Collections.Generic.Queue[string]
  Shuffle @($pool | Where-Object { -not $used.ContainsKey($_) }) | ForEach-Object { $queue.Enqueue($_) }
  $last = $null
  $end = $today.AddDays($queue.Count + $Horizon)
  for ($d = $start; $d -le $end; $d = $d.AddDays(1)) {
    $k = & $key $d
    if ($cal.ContainsKey($k)) { $last = $cal[$k]; continue }
    if ($queue.Count -eq 0) {
      # Nouveau tour : toutes les photos, melangees, sans repeter la veille
      $bag = Shuffle $pool
      if ($bag.Count -gt 1 -and $bag[0] -eq $last) { $bag[0], $bag[1] = $bag[1], $bag[0] }
      $bag | ForEach-Object { $queue.Enqueue($_) }
    }
    $cal[$k] = $queue.Dequeue(); $last = $cal[$k]
  }
}

# ---------- 3. Ecriture de photos.js ----------
$lines = @(
  '// Genere par update-photos.ps1 - ne pas modifier a la main.'
  '// ULYSSE_PHOTOS : toutes les photos. ULYSSE_CALENDAR : la photo de chaque jour.'
  'window.ULYSSE_PHOTOS = ['
) + @($pool | ForEach-Object { "  `"$_`"," }) + @(
  '];'
  'window.ULYSSE_CALENDAR = {'
) + @($cal.Keys | Sort-Object | ForEach-Object { "  `"$_`": `"$($cal[$_])`"," }) + @('};', '')
[IO.File]::WriteAllText($listFile, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))

$sizeMb = [math]::Round(((Get-ChildItem $outDir -File -Recurse | Measure-Object Length -Sum).Sum / 1MB), 1)
Say "Nouvelles photos : $added"
if ($failed) { Say "Echecs           : $failed" 'Red' }
Say "Photos au total  : $($pool.Count)  ($sizeMb Mo en ligne)"
Say "Metadonnees      : aucune (verifie)" 'Green'
Write-Host ''

if (-not $Publier) { exit 0 }

# ---------- 4. Publication sur GitHub ----------
$ErrorActionPreference = 'Continue'
Set-Location $root

$email = (& git config user.email)
if ($email -notmatch '@users\.noreply\.github\.com$') {
  Say "Publication bloquee : votre adresse e-mail git ($email) serait visible publiquement." 'Red'
  Say "Configurez l'adresse anonyme fournie par GitHub (voir README, section Confidentialite)." 'Red'
  Write-Host ''; exit 1
}

& git add -A
$staged = @(& git diff --cached --name-only)
if (-not $staged.Count) { Say 'Rien de nouveau a publier.' 'Green'; Write-Host ''; exit 0 }

$bad = @($staged | Where-Object {
  ($_ -match '\.(jpe?g|png|webp|heic|heif|avif|gif|tiff?|bmp|mp4|mov)$' -and $_ -notmatch '^photos/((mini/)?[0-9a-f]{16}|portrait)\.jpg$') -or
  ($_ -match '^photos/.+\.jpg$' -and -not (Test-CleanJpeg (Join-Path $root $_))) -or
  ($_ -like 'originaux/*')
})
if ($bad.Count) {
  & git reset -q
  $bad | ForEach-Object { Say "Refuse : $_" 'Red' }
  Say 'Publication annulee : ces fichiers ne doivent pas etre publies.' 'Red'; Write-Host ''; exit 1
}

& git commit -q -m ("Photos du " + (Get-Date -Format 'dd/MM/yyyy'))
& git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { Say "L'envoi vers GitHub a echoue (voir le message ci-dessus)." 'Red'; Write-Host ''; exit 1 }
Write-Host ''
Say 'Publie ! Le site sera a jour dans une a deux minutes.' 'Green'
Write-Host ''
