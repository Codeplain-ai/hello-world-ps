# PowerShell equivalent of run_unittests_java.sh
# On Windows, ensure JAVA_HOME is set to Java 21 (or set it below / in your environment)
if (-not $env:JAVA_HOME) {
  $java21Paths = @(
    "C:\Program Files\Java\jdk-21",
    "C:\Program Files\Eclipse Adoptium\jdk-21*",
    "C:\Program Files\Microsoft\jdk-21*"
  )
  foreach ($p in $java21Paths) {
    $resolved = Get-Item $p -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($resolved) { $env:JAVA_HOME = $resolved.FullName; break }
  }
}
java --version

# Check if subfolder name is provided
if ([string]::IsNullOrWhiteSpace($args[0])) {
  Write-Host "Error: No subfolder name provided."
  Write-Host "Usage: $MyInvocation.MyCommand.Name <subfolder_name>"
  exit 1
}

$JAVA_SUBFOLDER = ".tmp/java_$($args[0])"
$buildFolder = $args[0]

# Check if the java subfolder exists
if (Test-Path $JAVA_SUBFOLDER -PathType Container) {
  Get-ChildItem -Path $JAVA_SUBFOLDER | Remove-Item -Recurse -Force
} else {
  Write-Host "Error: Subfolder '$JAVA_SUBFOLDER' does not exist. Creating it now..."
  New-Item -ItemType Directory -Path $JAVA_SUBFOLDER -Force | Out-Null
}

# Check for conflicts before copying build files
# If any file from the build folder would overwrite a file already in the target, fail with an error
$buildFolderFull = (Resolve-Path -Path $buildFolder -ErrorAction Stop).Path
$hasConflict = $false

Get-ChildItem -Path $buildFolder -Recurse -File | Where-Object { $_.Name -ne ".DS_Store" } | ForEach-Object {
  $relativePath = $_.FullName.Substring($buildFolderFull.Length).TrimStart('\', '/')
  $targetPath = Join-Path $JAVA_SUBFOLDER $relativePath
  if (Test-Path $targetPath) {
    Write-Host "Error: Implementation of the file '$relativePath' should not be changed as it is used by the other parts of the system."
    $script:hasConflict = $true
  }
}

if ($hasConflict) {
  exit 2
}

Write-Host "No conflicts found, proceeding with copy..."

# Copy all folders and files from the build folder to the subfolder
Copy-Item -Path "$buildFolder\*" -Destination $JAVA_SUBFOLDER -Recurse -Force
Write-Host "Copied from $buildFolder to $JAVA_SUBFOLDER..."

# Move to the subfolder
try {
  Set-Location $JAVA_SUBFOLDER
  Write-Host "Moved to $JAVA_SUBFOLDER..."
} catch {
  Write-Host "Error: Subfolder '$JAVA_SUBFOLDER' does not exist."
  exit 2
}

# Execute all Java unittests in the subfolder (INFO level to avoid DEBUG verbosity)
$MAVEN_LOG_OPTS = "-Dlogging.level.root=INFO -Dlogging.level.org.springframework=WARN -Dlogging.level.org.apache=WARN"
Write-Host "Running Java unittests in $(Get-Location)..."
& mvn test --no-transfer-progress $MAVEN_LOG_OPTS.Split()
exit $LASTEXITCODE
