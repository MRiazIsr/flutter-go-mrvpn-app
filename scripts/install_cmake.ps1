$setup = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
$installPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"

Write-Host "Installing CMake for Visual Studio..."
$process = Start-Process -FilePath $setup -ArgumentList @(
    "modify"
    "--installPath", "`"$installPath`""
    "--add", "Microsoft.VisualStudio.Component.VC.CMake.Project"
    "--quiet"
    "--norestart"
) -Verb RunAs -PassThru -Wait

Write-Host "Exit code: $($process.ExitCode)"

# Verify
$cmakePath = Join-Path $installPath "Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if (Test-Path $cmakePath) {
    Write-Host "CMake installed successfully!"
} else {
    Write-Host "CMake not found yet - installer may need more time"
}
