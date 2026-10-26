param(
	[string]$HostName = "192.168.1.1",
	[string]$User = "root"
)

# Build luci-app-portmanager-1.0.0-r1.apk using the router itself:
#  1) stage <root>\files -> router:/tmp/pkgroot
#  2) upload dev/build-apk.sh -> /tmp/build-apk.sh and dev/post-install.sh -> /tmp/post-install.sh
#  3) run /tmp/build-apk.sh on the router (uses the static apk of Alpine, mkpkg)
#  4) scp the result back to dist\
# Requires: python with paramiko (sh.py), used for transfer (no SFTP conflict).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$files = Join-Path $root "files"
$dist = Join-Path $root "dist"
$dev = Join-Path $root "dev"

New-Item -ItemType Directory -Force -Path $dist | Out-Null

if (-not (Test-Path "$root\sh.py")) {
	Write-Warning "sh.py not found next to dev\. Put sh.py into the repository root first."
}

Write-Host "==> clearing /tmp/pkgroot on the router"
Get-Content (Join-Path $dev "sh-prepare.sh") | python -X utf8 "$root\sh.py" run

Write-Host "==> staging files"
Get-ChildItem -Recurse -File $files | ForEach-Object {
	$rel = $_.FullName.Substring((Get-Item $files).FullName.Length + 1).Replace("\", "/")
	$remote = "/tmp/pkgroot/$rel"
	Write-Host "   $rel"
	python -X utf8 "$root\sh.py" put (Resolve-Path $_.FullName).Path $remote | Out-Null
}

Write-Host "==> uploading build scripts"
python -X utf8 "$root\sh.py" put (Join-Path $dev "build-apk.sh") "/tmp/build-apk.sh" | Out-Null
python -X utf8 "$root\sh.py" put (Join-Path $dev "post-install.sh") "/tmp/post-install.sh" | Out-Null

Write-Host "==> building the package"
$s = @'
sh /tmp/build-apk.sh /tmp/pkgroot /tmp/luci-app-portmanager-1.0.0-r1.apk
'@
$s | python -X utf8 "$root\sh.py" run
if ($LASTEXITCODE -ne 0) { throw "build failed" }

Write-Host "==> downloading the result"
python -X utf8 "$root\sh.py" get "/tmp/luci-app-portmanager-1.0.0-r1.apk" (Join-Path $dist "luci-app-portmanager-1.0.0-r1.apk")

Write-Host "==> done"
Get-Item (Join-Path $dist "luci-app-portmanager-1.0.0-r1.apk") | Select-Object Name, Length, LastWriteTime
