$setup = "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
$installPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"

Write-Host "Installing Desktop development with C++ workload..."
$process = Start-Process -FilePath $setup -ArgumentList @(
    "modify"
    "--installPath", "`"$installPath`""
    "--add", "Microsoft.VisualStudio.Workload.NativeDesktop"
    "--includeRecommended"
    "--quiet"
    "--norestart"
) -Verb RunAs -PassThru -Wait

Write-Host "Exit code: $($process.ExitCode)"
Write-Host "Done! Please re-run flutter doctor to verify."
