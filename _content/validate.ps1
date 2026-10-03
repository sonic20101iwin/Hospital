# validate.ps1 - QA checks for the Band-Aid Medical Center site
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$files = Get-ChildItem *.html -File

function Read-Utf8($path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }

Write-Output '=== 1. Anchor targets (#id must exist) ==='
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $ids = @()
    foreach ($m in [regex]::Matches($c, 'id="([^"]+)"')) { $ids += $m.Groups[1].Value }
    $anchors = @()
    foreach ($m in [regex]::Matches($c, 'href="#([^"]+)"')) {
        $a = $m.Groups[1].Value
        if ($anchors -notcontains $a) { $anchors += $a }
    }
    $miss = @()
    foreach ($a in $anchors) { if ($ids -notcontains $a) { $miss += $a } }
    if ($miss.Count) { Write-Output ('  ' + $f.Name + ': MISSING -> ' + ($miss -join ', ')) }
    else { Write-Output ('  ' + $f.Name + ': OK (' + $anchors.Count + ' anchors)') }
}

Write-Output ''
Write-Output '=== 2. Active nav link (should be exactly 2: desktop + mobile) ==='
foreach ($f in $files) {
    if ($f.Name -eq 'index.html' -or $f.Name -eq 'admin.html') { continue }
    $c = Read-Utf8 $f.FullName
    $active = [regex]::Matches($c, '<a class="nav__link is-active" href="([^"]+)"')
    $where = @()
    foreach ($m in $active) { $where += $m.Groups[1].Value }
    $ok = ($active.Count -eq 2) -and ($where[0] -eq $f.Name)
    $status = if ($ok) { 'OK' } else { 'CHECK' }
    Write-Output ('  ' + $f.Name + ': ' + $active.Count + ' active -> [' + ($where -join ', ') + '] ' + $status)
}

Write-Output ''
Write-Output '=== 3. No leftover tokens, no scripts ==='
$bad = 0
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $tok = ([regex]::Matches($c, '__[A-Z_]+__')).Count
    $scr = ([regex]::Matches($c, '<script')).Count
    if ($tok -gt 0 -or $scr -gt 0) { Write-Output ('  ' + $f.Name + ': tokens=' + $tok + ' scripts=' + $scr); $bad++ }
}
if ($bad -eq 0) { Write-Output '  OK - no tokens, no <script>' }

Write-Output ''
Write-Output '=== 4. Tag balance ==='
$tags = 'div','section','article','header','footer','main','nav','ul','li','form','aside','table','tbody','tr'
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $issues = @()
    foreach ($t in $tags) {
        $open = ([regex]::Matches($c, ('<' + $t + '[\s>]'))).Count
        $close = ([regex]::Matches($c, ('</' + $t + '>'))).Count
        if ($open -ne $close) { $issues += ($t + ' ' + $open + '/' + $close) }
    }
    if ($issues) { Write-Output ('  ' + $f.Name + ': ' + ($issues -join ', ')) }
    else { Write-Output ('  ' + $f.Name + ': balanced') }
}

Write-Output ''
Write-Output '=== 5. Duplicate IDs ==='
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $ids = @()
    foreach ($m in [regex]::Matches($c, 'id="([^"]+)"')) { $ids += $m.Groups[1].Value }
    $dup = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dup) { Write-Output ('  ' + $f.Name + ': ' + (($dup | ForEach-Object { $_.Name }) -join ', ')) }
    else { Write-Output ('  ' + $f.Name + ': none') }
}

Write-Output ''
Write-Output '=== 6. Internal link targets exist ==='
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $missing = @()
    foreach ($m in [regex]::Matches($c, 'href="((?!https?:|mailto:|tel:|data:|#)[^"]+)"')) {
        $href = $m.Groups[1].Value
        if ($href -match '\.(html|css|js|png|jpg|jpeg|svg|webp)$') {
            if (-not (Test-Path $href)) { $missing += $href }
        }
    }
    if ($missing) { Write-Output ('  ' + $f.Name + ': MISSING -> ' + (($missing | Select-Object -Unique) -join ', ')) }
    else { Write-Output ('  ' + $f.Name + ': OK') }
}

Write-Output ''
Write-Output '=== 7. Encoding: only intended non-ASCII characters ==='
$allowed = 0x2014, 0x2013, 0x2026, 0x00A9, 0x00B7, 0x2019, 0x00E9, 0x00E7
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $odd = @()
    for ($i = 0; $i -lt $c.Length; $i++) {
        $code = [int]$c[$i]
        if ($code -gt 127 -and $allowed -notcontains $code) { $odd += ('U+{0:X4}' -f $code) }
    }
    $odd = $odd | Select-Object -Unique
    if ($odd) { Write-Output ('  ' + $f.Name + ': unexpected ' + ($odd -join ' ')) }
    else { Write-Output ('  ' + $f.Name + ': OK') }
}

Write-Output ''
Write-Output '=== 8. Font Awesome icons used ==='
$icons = New-Object System.Collections.Generic.List[string]
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    foreach ($m in [regex]::Matches($c, 'class="fa-[a-z0-9 -]*?\b(fa-[a-z0-9-]+)\b')) {
        $n = $m.Groups[1].Value
        if (-not $icons.Contains($n)) { $icons.Add($n) }
    }
    foreach ($m in [regex]::Matches($c, 'fa-solid (fa-[a-z0-9-]+)')) {
        $n = $m.Groups[1].Value
        if (-not $icons.Contains($n)) { $icons.Add($n) }
    }
}
$icons.Sort()
Write-Output ('  ' + $icons.Count + ' unique icon names:')
$icons | ForEach-Object { Write-Output ('    ' + $_) }

Write-Output ''
Write-Output '=== 9. Icon allowlist and style pairings (Font Awesome Free 6.5.1) ==='
$styleTags = @('fa-solid', 'fa-brands', 'fa-regular')
$solidIcons = @(
    'fa-arrow-right', 'fa-arrow-right-from-bracket', 'fa-arrow-trend-down', 'fa-arrow-trend-up',
    'fa-arrow-up-right-from-square', 'fa-award', 'fa-baby', 'fa-bed', 'fa-bed-pulse', 'fa-bell',
    'fa-bone', 'fa-brain', 'fa-building-shield', 'fa-bullseye', 'fa-calendar-check',
    'fa-chart-simple', 'fa-check', 'fa-check-double', 'fa-chevron-right', 'fa-circle-check',
    'fa-circle-info', 'fa-clock', 'fa-clock-rotate-left', 'fa-comments', 'fa-database',
    'fa-envelope', 'fa-eye', 'fa-flask-vial', 'fa-floppy-disk', 'fa-gauge-high', 'fa-gear',
    'fa-globe', 'fa-hand-dots', 'fa-hand-holding-heart', 'fa-headset', 'fa-heart',
    'fa-heart-pulse', 'fa-hospital', 'fa-hospital-user', 'fa-hourglass-half', 'fa-images',
    'fa-layer-group', 'fa-lightbulb', 'fa-list', 'fa-location-dot', 'fa-magnifying-glass',
    'fa-microscope', 'fa-minus', 'fa-moon', 'fa-notes-medical', 'fa-paper-plane',
    'fa-pen-to-square', 'fa-people-group', 'fa-person-pregnant', 'fa-person-walking', 'fa-phone',
    'fa-phone-volume', 'fa-prescription-bottle-medical', 'fa-quote-left', 'fa-ribbon',
    'fa-rotate-left', 'fa-route', 'fa-scale-balanced', 'fa-shield-heart', 'fa-star',
    'fa-stethoscope', 'fa-sun', 'fa-syringe', 'fa-triangle-exclamation', 'fa-truck-medical',
    'fa-upload', 'fa-user-doctor', 'fa-user-nurse', 'fa-user-shield', 'fa-user-tie', 'fa-x-ray',
    'fa-xmark'
)
$brandIcons = @('fa-facebook-f', 'fa-instagram', 'fa-linkedin-in', 'fa-x-twitter')
$regularIcons = @('fa-bell', 'fa-calendar-check', 'fa-paper-plane', 'fa-star')
$fail9 = 0
foreach ($f in $files) {
    $c = Read-Utf8 $f.FullName
    $issues = @()
    foreach ($m in [regex]::Matches($c, 'fa-brands\s+(fa-[a-z0-9-]+)')) {
        $n = $m.Groups[1].Value
        if ($brandIcons -notcontains $n) { $issues += ('bad-brand ' + $n) }
    }
    foreach ($m in [regex]::Matches($c, 'fa-regular\s+(fa-[a-z0-9-]+)')) {
        $n = $m.Groups[1].Value
        if ($regularIcons -notcontains $n) { $issues += ('bad-regular ' + $n) }
    }
    foreach ($m in [regex]::Matches($c, '\bfa-[a-z0-9-]+')) {
        $n = $m.Value
        if ($styleTags -contains $n) { continue }
        if ($solidIcons -notcontains $n -and $brandIcons -notcontains $n) {
            $issues += ('unknown ' + $n)
        }
    }
    $issues = @($issues | Select-Object -Unique)
    if ($issues.Count) { Write-Output ('  ' + $f.Name + ': FAIL -> ' + ($issues -join ', ')); $fail9++ }
    else { Write-Output ('  ' + $f.Name + ': OK') }
}
if ($fail9 -eq 0) { Write-Output '  OK - all icons exist in Font Awesome Free 6.5.1' }

Write-Output ''
Write-Output 'Done.'

