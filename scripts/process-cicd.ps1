param (
    [string] $branchName="refs/heads/main",
    [string[]] $tags="",
    [string] $message="Commit Message"
)

$shortBranchName = $branchName.Replace("refs/heads/", "")
$commitMessagePrefix = "TEST"

$environment = "stage"
if ($shortBranchName -match 'feature/(.*)') {
    $environment = "test"
    $featureName = $Matches[1]
    
    Write-Host "Processing Feature $featureName"
    $helmBranch = "feature/$featureName"
    $branchExists = ((git ls-remote origin "refs/heads/$helmBranch" | Measure-Object -line).Lines -gt 0)

    if ($branchExists) {
        Write-Host "Using existing branch -> $helmBranch"
        git checkout "$helmBranch"
        git branch --set-upstream-to="origin/$helmBranch" "$helmBranch"
    }
    else {
        Write-Host "Creating new local branch -> $helmBranch"
        git checkout -b "$helmBranch"

        Copy-Item ./environments/stage/images.yaml ./environments/test/images.yaml -Force
    }
    $commitMessagePrefix = $featureName
}
else {
    $helmBranch = "main"
    Write-Host "Processing $shortBranchName -> Modifying Helm Branch $helmBranch"
    Invoke-Expression "git checkout $helmBranch"
}
$imageFile = "./environments/$environment/images.yaml"

Invoke-Expression "git pull --rebase"

Write-Host "Replacing tags in $imageFile"
$imagePath = (Resolve-Path $imageFile).Path
Push-Location ./scripts

foreach ($tag in $tags) {
    $tagSplit = $tag.Split("=")
    $imageArgs += "--value imageTags.$($tagSplit[0])=$($tagSplit[1])"
}

Invoke-Expression "python ./edit-value.py $imageArgs $imagePath"
Pop-Location

Invoke-Expression "git add $imageFile"

Invoke-Expression "git commit -m '$commitMessagePrefix - $message'"
Invoke-Expression "git push origin $helmBranch"