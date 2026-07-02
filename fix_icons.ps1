$file = "c:\Users\user\OneDrive\Desktop\Riri\lib\screens\manager\home_manager_screen.dart"
$content = Get-Content $file -Raw

$replacements = @{
    'Icons.personCheck'        = 'Icons.how_to_reg'
    'Icons.personX'            = 'Icons.person_off'
    'Icons.calendar_todayCheck' = 'Icons.event_available'
    'Icons.calendar_todayClock' = 'Icons.event'
    'Icons.searchX'            = 'Icons.search_off'
    'Icons.personCog'          = 'Icons.manage_accounts'
}

foreach ($key in $replacements.Keys) {
    $content = $content.Replace($key, $replacements[$key])
}

Set-Content $file $content -NoNewline
Write-Host "Done! Fixed compound icon names."
