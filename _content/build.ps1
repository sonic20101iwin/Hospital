# ============================================================
# Band-Aid Medical Center - static page assembler
# Combines _head.html + page content + _footer.html
# Pure PowerShell. No Node.js, no build frameworks.
# ============================================================
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$content = $PSScriptRoot

$head = Get-Content (Join-Path $content '_head.html') -Raw -Encoding UTF8
$footer = Get-Content (Join-Path $content '_footer.html') -Raw -Encoding UTF8

$pages = @(
    @{ file = 'about.html';        token = 'ABOUT';      title = 'About Us | Band-Aid Medical Center';             desc = 'Learn about Band-Aid Medical Center: our mission, vision, values and commitment to patient safety, medical excellence and compassionate care.'; content = 'about.html' },
    @{ file = 'services.html';     token = 'SERVICES';   title = 'Medical Services | Band-Aid Medical Center';     desc = 'Explore our medical services: emergency care, cardiology, neurology, pediatrics, orthopedics, oncology, women''s health, surgery, imaging and laboratory services.'; content = 'services.html' },
    @{ file = 'crew.html';         token = 'CREW';       title = 'Our Crew | Band-Aid Medical Center';             desc = 'Meet our crew: medical departments, experienced doctors and staff, and the modern facilities behind exceptional care at Band-Aid Medical Center.'; content = 'crew.html' },
    @{ file = 'gallery.html';      token = 'GALLERY';    title = 'Gallery | Band-Aid Medical Center';              desc = 'A look inside Band-Aid Medical Center: our facilities, clinical spaces, medical equipment and the people who deliver care every day.'; content = 'gallery.html' },
    @{ file = 'testimonials.html'; token = 'TESTIMONIALS'; title = 'Patient Testimonials | Band-Aid Medical Center'; desc = 'Sample experiences shared by the patients and families cared for at Band-Aid Medical Center.'; content = 'testimonials.html' },
    @{ file = 'contact.html';      token = 'CONTACT';    title = 'Contact Us | Band-Aid Medical Center';           desc = 'Contact Band-Aid Medical Center: address, phone, email, opening hours, emergency information and appointment requests.'; content = 'contact.html' }
)

$tokens = @('HOME','ABOUT','SERVICES','CREW','GALLERY','TESTIMONIALS','CONTACT')

foreach ($page in $pages) {
    $body = Get-Content (Join-Path $content $page.content) -Raw -Encoding UTF8

    $h = $head.Replace('__TITLE__', $page.title).Replace('__DESC__', $page.desc)
    foreach ($t in $tokens) {
        $value = ''
        if ($t -eq $page.token) { $value = 'is-active' }
        $h = $h.Replace("__${t}__", $value)
    }

    $html = $h + $body + $footer

    # Tidy: remove the empty class slot left by an unused token
    $html = $html.Replace('class="nav__link "', 'class="nav__link"')

    # Write without a byte-order mark for clean HTML output
    $outPath = Join-Path $root $page.file
    [System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output "Built: $($page.file)"
}

Write-Output 'Done.'