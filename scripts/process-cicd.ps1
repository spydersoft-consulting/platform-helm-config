param (
    [string] $branchName="refs/heads/main",
    # Comma-joined, e.g. "audit_api=1.2.3,audit_processor=1.2.3". Split here
    # rather than relying on the CLI to bind a [string[]] from
    # whitespace-separated tokens -- that approach silently only ever
    # captured the first tag once this script started receiving more than
    # one (confirmed: passing a space-joined string through unquoted still
    # bound as one element, not two, for reasons not fully understood --
    # quoting the whole comma-joined string and splitting it here sidesteps
    # CLI binding entirely and is easy to reason about).
    [string] $tagsCollection="",
    [string] $message="Commit Message"
)

$tags = $tagsCollection.Split(",")

# Every build shape (main-branch push, feature-branch push, or tag push)
# always updates environments/test/images.yaml. Nothing ever writes to
# production directly from here. Promotion onward (test -> production,
# gated on the tag actually being an unlabeled release) happens in
# deploy.yml, based on this commit's BETA/RELEASE prefix below -- that
# keeps the promotion decision declarative and independent of this script.
$environment = "test"
# Classify by the actual tag value, not by branch: GitVersion emits a clean
# X.Y.Z for real releases and an X.Y.Z-something prerelease for everything
# else. Branch name only approximates this and mislabels feature-branch
# prerelease builds (e.g. tag 3.1.6-terraform-provider-api-fixes.3, pushed
# from a branch other than main) as RELEASE, which then gets promoted
# straight to production by deploy.yml. Semver's hyphen marks a prerelease
# unambiguously regardless of which branch produced it.
$isPrerelease = $tags | Where-Object { $_.Contains("=") -and $_.Split("=")[1].Contains("-") } | Select-Object -First 1
$commitMessagePrefix = if ($isPrerelease) { "BETA" } else { "RELEASE" }

Write-Host "Processing $branchName -> environment $environment"
# fetch+hard-reset-to-origin instead of pull --rebase: this job's workspace
# is reused across runs on self-hosted agents, and a prior run's leftover
# rebase-merge state blocks every subsequent rebase attempt (confirmed live
# via deploy.yml's promotion steps hitting this exact failure). This step
# only ever needs the latest origin/main plus one new commit, not to
# preserve any local history, so resetting to origin/main is both simpler
# and self-healing against any stuck local state.
Invoke-Expression "git rebase --abort" 2>$null
Invoke-Expression "git fetch origin"
Invoke-Expression "git checkout main"
Invoke-Expression "git reset --hard origin/main"
$imageFile = "./environments/$environment/images.yaml"

Write-Host "Replacing tags in $imageFile"
$imagePath = (Resolve-Path $imageFile).Path
Push-Location ./scripts

# Must start as an explicit array: $imageArgs += "..." on an uninitialized
# ($null) variable does string concatenation, not array-append, so a
# second tag lands glued directly onto the first with no separating space
# (e.g. "--value imageTags.audit_api=1--value imageTags.audit_processor=1"),
# which edit-value.py's argparse then rejects as one unrecognized
# argument.
$imageArgs = @()
foreach ($tag in $tags) {
    $tagSplit = $tag.Split("=")
    $imageArgs += "--value imageTags.$($tagSplit[0])=$($tagSplit[1])"
}

Invoke-Expression "python ./edit-value.py $imageArgs $imagePath"
Pop-Location

Invoke-Expression "git add $imageFile"

Invoke-Expression "git commit -m '$commitMessagePrefix - $message'"
Invoke-Expression "git push origin main"
