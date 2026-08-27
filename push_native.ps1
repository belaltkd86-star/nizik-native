$ErrorActionPreference = "Stop"

Set-Location "C:\Projects\nizik_native"

Write-Host "Checking Git remote..."
$remote = git remote

if ($remote -notcontains "origin") {
    git remote add origin https://github.com/belaltkd86-star/nizik.git
}

Copy-Item "$PSScriptRoot\codemagic.yaml" ".\codemagic.yaml" -Force

git add codemagic.yaml
git commit -m "Add Codemagic unsigned iOS IPA workflow"

git push -u origin HEAD:native

Write-Host ""
Write-Host "Done. Native branch pushed to GitHub."
