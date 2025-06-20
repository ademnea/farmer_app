$files = Get-ChildItem -Path "D:\farmer_app\lib\" -Recurse -Include "*.dart"
foreach ($file in $files) {
    Write-Host "Processing: $($file.FullName)"
    $content = Get-Content $file.FullName -Raw
    $updatedContent = $content -replace 'package:HPGM/', 'package:farmer_app/'
    if ($content -ne $updatedContent) {
        Write-Host "Updating imports in $($file.Name)"
        Set-Content -Path $file.FullName -Value $updatedContent
    }
}
Write-Host "Import update complete."
