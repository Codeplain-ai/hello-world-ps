# PowerShell equivalent of prepare_environment_java.sh
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

# Check if build folder name is provided
if ([string]::IsNullOrWhiteSpace($args[0])) {
  Write-Host "Error: No build folder name provided."
  Write-Host "Usage: $MyInvocation.MyCommand.Name <build_folder_name>"
  exit 1
}

$JAVA_BUILD_SUBFOLDER = ".tmp/java_$($args[0])"
$buildFolder = $args[0]

if ($env:VERBOSE -eq 1) {
  Write-Host "Copying generated code to main project folder: $JAVA_BUILD_SUBFOLDER"
}

# Check if the main project folder exists
if (-not (Test-Path $JAVA_BUILD_SUBFOLDER -PathType Container)) {
  Write-Host "Error: Main project folder '$JAVA_BUILD_SUBFOLDER' does not exist."
  exit 2
}

Copy-Item -Path "$buildFolder\*" -Destination $JAVA_BUILD_SUBFOLDER -Recurse -Force
Write-Host "Copied from $buildFolder to $JAVA_BUILD_SUBFOLDER..."

# Move to the subfolder
try {
  Set-Location $JAVA_BUILD_SUBFOLDER
  Write-Host "Moved to $JAVA_BUILD_SUBFOLDER..."
} catch {
  Write-Host "Error: Java build folder '$JAVA_BUILD_SUBFOLDER' does not exist."
  exit 2
}

# Use INFO logging so build/output is not overly verbose
$MAVEN_LOG_OPTS = "-Dlogging.level.root=INFO -Dlogging.level.org.springframework=WARN -Dlogging.level.org.apache=WARN"
Write-Host "Runinng maven install in the build folder..."
& mvn clean install -DskipTests --no-transfer-progress $MAVEN_LOG_OPTS.Split()
exit $LASTEXITCODE
