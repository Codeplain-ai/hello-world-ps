# PowerShell equivalent of run_conformance_tests_java.sh
# On Windows, ensure JAVA_HOME is set to Java 21 (or set it below / in your environment)
if (-not $env:JAVA_HOME) {
  # Optional: try to use Java 21 from common Windows locations
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

# Check if build folder name is provided
if ([string]::IsNullOrWhiteSpace($args[0])) {
  Write-Host "Error: No build folder name provided."
  Write-Host "Usage: $MyInvocation.MyCommand.Name <build_folder_name> <conformance_tests_folder>"
  exit 1
}

# Check if conformance tests folder name is provided
if ([string]::IsNullOrWhiteSpace($args[1])) {
  Write-Host "Error: No conformance tests folder name provided."
  Write-Host "Usage: $MyInvocation.MyCommand.Name <build_folder_name> <conformance_tests_folder>"
  exit 1
}

$current_dir = Get-Location
Write-Host "Current directory: $current_dir"

tree $args[1]

$JAVA_BUILD_SUBFOLDER = ".tmp/java_$($args[0])"

$CONFORMANCE_TESTS_FOLDER = ".tmp/java_conformance"

Set-Location $current_dir
Write-Host "Moved to $current_dir..."
Write-Host "Preparing Java conformance tests subfolder: $CONFORMANCE_TESTS_FOLDER"

# Check if the conformance tests subfolder exists
if (Test-Path $CONFORMANCE_TESTS_FOLDER -PathType Container) {
  # Find and delete all files and folders (empty the folder)
  Get-ChildItem -Path $CONFORMANCE_TESTS_FOLDER | Remove-Item -Recurse -Force

  if ($env:VERBOSE -eq 1) {
    Write-Host "Cleanup completed."
  }
} else {
  Write-Host "Current directory: $(Get-Location)"

  Write-Host "Subfolder does not exist. Creating it..."
  New-Item -ItemType Directory -Path $CONFORMANCE_TESTS_FOLDER -Force | Out-Null
}

Copy-Item -Path "$($args[1])\*" -Destination $CONFORMANCE_TESTS_FOLDER -Recurse -Force
Write-Host "Copied from $($args[1]) to $CONFORMANCE_TESTS_FOLDER..."

# Move to the subfolder
try {
  Set-Location $CONFORMANCE_TESTS_FOLDER
  Write-Host "Moved to $CONFORMANCE_TESTS_FOLDER..."
} catch {
  Write-Host "Error: Java conformance tests folder '$CONFORMANCE_TESTS_FOLDER' does not exist."
  exit 2
}

$MAVEN_LOG_OPTS = "-Dlogging.level.root=INFO -Dlogging.level.org.springframework=WARN -Dlogging.level.org.apache=WARN"
Write-Host "Runinng maven install in $(Get-Location)..."
& mvn clean install -DskipTests --no-transfer-progress $MAVEN_LOG_OPTS.Split()

Write-Host "Running Java unittests in $(Get-Location)..."
& mvn test --no-transfer-progress $MAVEN_LOG_OPTS.Split()
exit $LASTEXITCODE
