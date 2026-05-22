#!/usr/bin/env pwsh
# Rename: arcane -> missions, package -> me.ihjas.missions
$ErrorActionPreference = 'Stop'
$repo = Resolve-Path "$PSScriptRoot\.."
Set-Location $repo

function ReplaceInFile($path, $pairs) {
    if (-not (Test-Path $path)) { return }
    $orig = Get-Content -Raw -LiteralPath $path
    $new = $orig
    foreach ($p in $pairs) {
        $new = $new.Replace($p[0], $p[1])
    }
    if ($new -ne $orig) {
        # Preserve original encoding for plist/json/xml -> utf8 no bom
        [System.IO.File]::WriteAllText($path, $new, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  patched $path"
    }
}

# 1. Bulk replace package:arcane/ -> package:missions/ in all .dart files
Write-Host "== Dart imports =="
Get-ChildItem -Recurse -File -Include *.dart -Path lib,test | ForEach-Object {
    ReplaceInFile $_.FullName @(,@('package:arcane/','package:missions/'))
}

# 2. pubspec.yaml: name + description (keep description text otherwise unchanged)
Write-Host "== pubspec.yaml =="
ReplaceInFile "pubspec.yaml" @(
    ,@("name: arcane","name: missions")
)

# 3. Android: build.gradle.kts namespace + applicationId
Write-Host "== Android gradle =="
ReplaceInFile "android/app/build.gradle.kts" @(
    ,@('"com.example.arcane"','"me.ihjas.missions"')
)

# 4. Android: move MainActivity.kt to new package path
Write-Host "== Android MainActivity =="
$oldKt = "android/app/src/main/kotlin/com/example/arcane/MainActivity.kt"
$newDir = "android/app/src/main/kotlin/me/ihjas/missions"
$newKt = "$newDir/MainActivity.kt"
if (Test-Path $oldKt) {
    New-Item -ItemType Directory -Force -Path $newDir | Out-Null
    $content = Get-Content -Raw -LiteralPath $oldKt
    $content = $content.Replace('package com.example.arcane','package me.ihjas.missions')
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath ".").Path + "\" + $newKt.Replace('/','\'), $content, [System.Text.UTF8Encoding]::new($false))
    Remove-Item $oldKt
    # Clean up empty old dirs
    $p = Split-Path $oldKt -Parent
    while ($p -and (Test-Path $p) -and -not (Get-ChildItem $p -Force)) {
        Remove-Item $p
        $p = Split-Path $p -Parent
    }
    Write-Host "  moved $oldKt -> $newKt"
}

# 5. Android: google-services.json package_name
Write-Host "== google-services.json =="
ReplaceInFile "android/app/google-services.json" @(
    ,@('"com.example.arcane"','"me.ihjas.missions"')
)

# 6. iOS: pbxproj bundle id + Info.plist display name
Write-Host "== iOS =="
ReplaceInFile "ios/Runner.xcodeproj/project.pbxproj" @(
    ,@('me.ihjas.arcane','me.ihjas.missions')
)
ReplaceInFile "ios/Runner/Info.plist" @(
    ,@('<string>Arcane</string>','<string>Missions</string>')
)

# 7. macOS: AppInfo.xcconfig + pbxproj
Write-Host "== macOS =="
ReplaceInFile "macos/Runner/Configs/AppInfo.xcconfig" @(
    ,@('PRODUCT_BUNDLE_IDENTIFIER = me.ihjas.myapp','PRODUCT_BUNDLE_IDENTIFIER = me.ihjas.missions')
)
ReplaceInFile "macos/Runner.xcodeproj/project.pbxproj" @(
    ,@('me.ihjas.myapp.RunnerTests','me.ihjas.missions.RunnerTests'),
    @('me.ihjas.myapp','me.ihjas.missions')
)

# 8. Windows: CMakeLists + Runner.rc
Write-Host "== Windows =="
ReplaceInFile "windows/CMakeLists.txt" @(
    ,@('project(arcane LANGUAGES CXX)','project(missions LANGUAGES CXX)'),
    @('set(BINARY_NAME "arcane")','set(BINARY_NAME "missions")')
)
ReplaceInFile "windows/runner/Runner.rc" @(
    ,@('"FileDescription", "arcane"','"FileDescription", "Missions"'),
    @('"InternalName", "arcane"','"InternalName", "missions"'),
    @('"OriginalFilename", "arcane.exe"','"OriginalFilename", "missions.exe"'),
    @('"ProductName", "arcane"','"ProductName", "Missions"')
)

# 9. Linux: CMakeLists + my_application.cc
Write-Host "== Linux =="
ReplaceInFile "linux/CMakeLists.txt" @(
    ,@('set(BINARY_NAME "arcane")','set(BINARY_NAME "missions")'),
    @('set(APPLICATION_ID "me.ihjas.arcane")','set(APPLICATION_ID "me.ihjas.missions")')
)
ReplaceInFile "linux/runner/my_application.cc" @(
    ,@('gtk_header_bar_set_title(header_bar, "arcane")','gtk_header_bar_set_title(header_bar, "Missions")'),
    @('gtk_window_set_title(window, "arcane")','gtk_window_set_title(window, "Missions")')
)

# 10. Dart strings referring to "Arcane" as app brand
Write-Host "== Dart brand strings =="
ReplaceInFile "lib/src/widgets/views/chatbot_view.dart" @(
    ,@('Arcane Advisor','Missions Advisor')
)
ReplaceInFile "lib/src/services/data_export_service.dart" @(
    ,@('Arcane Database Export','Missions Database Export')
)

Write-Host "`nDone."
