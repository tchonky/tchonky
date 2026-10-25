<#
.SYNOPSIS
    Measures the total size of a folder, and its size when duplicate files are counted only once.

.DESCRIPTION
    Scans the folder and all its subfolders (hidden and system files included) and adds up the
    size of every file. Duplicates are files with identical content, whatever their names.

    To stay fast, files are first grouped by size: only files that share their size with another
    file are read and hashed (SHA-256), so most files are never opened.

    Notes:
    - Junctions and symbolic links to folders are not followed, so nothing is counted twice
      through a link and the scan cannot loop.
    - OneDrive and other cloud "online-only" files count toward the total but are not compared,
      because reading them would download them.
    - Hard links to the same file are reported as duplicates, although on disk they share the
      same data.

    Works with Windows PowerShell 5.1 and PowerShell 7.

.PARAMETER Path
    The folder to measure. Defaults to the current folder.

.PARAMETER Top
    How many groups of duplicates to list, the ones taking the most space first. 0 lists none.

.PARAMETER CsvPath
    Optional. Saves every duplicate file, with its group, to this CSV file (opens in Excel).

.PARAMETER PassThru
    Returns the results as an object instead of printing a report, for use in other scripts.

.EXAMPLE
    .\Measure-FolderSize.ps1 "D:\Projects"

.EXAMPLE
    .\Measure-FolderSize.ps1 "D:\Photos" -Top 25 -CsvPath "$HOME\Desktop\duplicates.csv"

.EXAMPLE
    (.\Measure-FolderSize.ps1 "D:\Projects" -PassThru).DuplicateBytes
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = '.',

    [ValidateRange(0, [int]::MaxValue)]
    [int]$Top = 10,

    [string]$CsvPath,

    [switch]$PassThru
)

$ErrorActionPreference = 'Stop'

function Format-Size([long]$Bytes) {
    if ($Bytes -lt 1024) { return '{0:N0} bytes' -f $Bytes }
    $units = 'KB', 'MB', 'GB', 'TB', 'PB'
    $size = $Bytes / 1024.0
    $unit = 0
    while ($size -ge 1024 -and $unit -lt $units.Count - 1) { $size /= 1024; $unit++ }
    '{0:N2} {1}' -f $size, $units[$unit]
}

# Turns an internal long path (\\?\C:\... or \\?\UNC\server\...) back into a normal one.
function Get-DisplayPath([string]$LongPath) {
    $LongPath -replace '^\\\\\?\\UNC\\', '\\' -replace '^\\\\\?\\', ''
}

$clock = [System.Diagnostics.Stopwatch]::StartNew()
$nextProgress = 0

$root = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).ProviderPath)

# The \\?\ prefix lifts the 260-character path limit on Windows. Fall back to the plain path
# on systems that don't support it.
$scanRoot = $root
if ($env:OS -eq 'Windows_NT' -and -not $root.StartsWith('\\?\')) {
    if ($root.StartsWith('\\')) { $scanRoot = '\\?\UNC\' + $root.Substring(2) }
    else { $scanRoot = '\\?\' + $root }
}
try {
    $rootDir = [System.IO.DirectoryInfo]::new($scanRoot)
    if (-not $rootDir.Exists) { throw }
}
catch {
    $rootDir = [System.IO.DirectoryInfo]::new($root)
}
if (-not $rootDir.Exists) { throw "'$root' is not a folder." }

# --- 1. Find every file -------------------------------------------------------------------

$files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$skippedFolders = [System.Collections.Generic.List[string]]::new()
$linkedFolders = 0
$pending = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
$pending.Push($rootDir)

while ($pending.Count -gt 0) {
    $dir = $pending.Pop()
    try {
        foreach ($item in $dir.EnumerateFileSystemInfos()) {
            if ($item -isnot [System.IO.DirectoryInfo]) {
                $files.Add($item)
            }
            elseif (([int]$item.Attributes -band 0x400) -and $item.LinkType) {
                # Junction or symbolic link. Other reparse points, such as OneDrive folders,
                # have no LinkType and are scanned normally.
                $linkedFolders++
            }
            else {
                $pending.Push($item)
            }
        }
    }
    catch {
        $skippedFolders.Add((Get-DisplayPath $dir.FullName))
    }

    if ($clock.ElapsedMilliseconds -ge $nextProgress) {
        Write-Progress -Activity 'Scanning folders' -Status ('{0:N0} files found' -f $files.Count)
        $nextProgress = $clock.ElapsedMilliseconds + 250
    }
}

# --- 2. Group files by size: only files of equal size can be duplicates -------------------

$totalBytes = [long]0
$bySize = [System.Collections.Generic.Dictionary[long, System.Collections.Generic.List[System.IO.FileInfo]]]::new()
foreach ($file in $files) {
    $totalBytes += $file.Length
    if ($file.Length -eq 0) { continue }
    $sameSize = $null
    if (-not $bySize.TryGetValue($file.Length, [ref]$sameSize)) {
        $sameSize = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        $bySize.Add($file.Length, $sameSize)
    }
    $sameSize.Add($file)
}

$toCompare = 0
foreach ($sameSize in $bySize.Values) {
    if ($sameSize.Count -gt 1) { $toCompare += $sameSize.Count }
}

# --- 3. Hash files that share a size, and group identical ones ----------------------------

$onlineOnlyMask = 0x1000 -bor 0x40000 -bor 0x400000   # Offline, RecallOnOpen, RecallOnDataAccess
$sha256 = [System.Security.Cryptography.SHA256]::Create()
$groups = [System.Collections.Generic.List[object]]::new()
$unreadableFiles = [System.Collections.Generic.List[string]]::new()
$onlineOnlyFiles = 0
$duplicateBytes = [long]0
$extraCopies = 0
$compared = 0

foreach ($sameSize in $bySize.Values) {
    if ($sameSize.Count -lt 2) { continue }

    $byHash = @{}
    foreach ($file in $sameSize) {
        $compared++
        if ($clock.ElapsedMilliseconds -ge $nextProgress) {
            Write-Progress -Activity 'Comparing files of the same size' `
                -Status ('{0:N0} of {1:N0} files' -f $compared, $toCompare) `
                -PercentComplete ([int](100 * $compared / $toCompare))
            $nextProgress = $clock.ElapsedMilliseconds + 250
        }

        if ([int]$file.Attributes -band $onlineOnlyMask) {
            $onlineOnlyFiles++
            continue
        }
        try {
            $stream = [System.IO.File]::Open($file.FullName, [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read, [System.IO.FileShare]'ReadWrite, Delete')
            try { $hash = [System.BitConverter]::ToString($sha256.ComputeHash($stream)) -replace '-', '' }
            finally { $stream.Dispose() }
        }
        catch {
            $unreadableFiles.Add((Get-DisplayPath $file.FullName))
            continue
        }
        if (-not $byHash.ContainsKey($hash)) {
            $byHash[$hash] = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        }
        $byHash[$hash].Add($file)
    }

    foreach ($entry in $byHash.GetEnumerator()) {
        $copies = $entry.Value
        if ($copies.Count -lt 2) { continue }
        $extraBytes = $copies[0].Length * ($copies.Count - 1)
        $duplicateBytes += $extraBytes
        $extraCopies += $copies.Count - 1
        $groups.Add([pscustomobject]@{
            Size       = $copies[0].Length
            Copies     = $copies.Count
            ExtraBytes = $extraBytes
            Hash       = $entry.Key
            Paths      = @($copies | ForEach-Object { Get-DisplayPath $_.FullName } | Sort-Object)
        })
    }
}
$sha256.Dispose()
Write-Progress -Activity 'Comparing files of the same size' -Completed

$duplicates = @($groups | Sort-Object ExtraBytes -Descending)
$uniqueBytes = $totalBytes - $duplicateBytes

# --- 4. Report ----------------------------------------------------------------------------

if ($CsvPath -and $duplicates.Count -gt 0) {
    $encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }   # BOM so Excel shows accents
    $group = 0
    $rows = foreach ($dup in $duplicates) {
        $group++
        foreach ($p in $dup.Paths) {
            [pscustomobject]@{
                Group     = $group
                Copies    = $dup.Copies
                SizeBytes = $dup.Size
                Size      = Format-Size $dup.Size
                Hash      = $dup.Hash
                Path      = $p
            }
        }
    }
    $rows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -UseCulture -Encoding $encoding
}

foreach ($folder in $skippedFolders) { Write-Verbose "Could not open folder: $folder" }
foreach ($file in $unreadableFiles) { Write-Verbose "Could not read file: $file" }

if ($PassThru) {
    return [pscustomobject]@{
        Folder          = $root
        Files           = $files.Count
        TotalBytes      = $totalBytes
        UniqueBytes     = $uniqueBytes
        DuplicateBytes  = $duplicateBytes
        ExtraCopies     = $extraCopies
        Duplicates      = $duplicates
        SkippedFolders  = $skippedFolders.ToArray()
        UnreadableFiles = $unreadableFiles.ToArray()
        OnlineOnlyFiles = $onlineOnlyFiles
        Elapsed         = $clock.Elapsed
    }
}

Write-Host ''
Write-Host "Folder: $root"
Write-Host ('Files:  {0:N0}' -f $files.Count)
Write-Host ''
Write-Host ('Total size                {0,12}   ({1:N0} bytes)' -f (Format-Size $totalBytes), $totalBytes)
Write-Host ('Duplicates counted once   {0,12}   ({1:N0} bytes)' -f (Format-Size $uniqueBytes), $uniqueBytes) -ForegroundColor Green
Write-Host ('Taken by duplicates       {0,12}   ({1:N0} extra copies in {2:N0} groups)' -f (Format-Size $duplicateBytes), $extraCopies, $duplicates.Count) -ForegroundColor Yellow

if ($Top -gt 0 -and $duplicates.Count -gt 0) {
    $shown = [Math]::Min($Top, $duplicates.Count)
    Write-Host ''
    Write-Host "Duplicates taking the most space ($shown of $($duplicates.Count) groups):"
    $rank = 0
    foreach ($dup in $duplicates | Select-Object -First $Top) {
        $rank++
        Write-Host ''
        Write-Host ('{0,3}. {1} copies of {2}  ->  {3} extra' -f $rank, $dup.Copies, (Format-Size $dup.Size), (Format-Size $dup.ExtraBytes)) -ForegroundColor Cyan
        foreach ($p in $dup.Paths) { Write-Host "       $p" }
    }
}

Write-Host ''
if ($skippedFolders.Count -gt 0) {
    Write-Warning ('{0:N0} folder(s) could not be opened (access denied or path too long) and were left out. Run with -Verbose to list them, or as administrator to include them.' -f $skippedFolders.Count)
}
if ($unreadableFiles.Count -gt 0) {
    Write-Warning ('{0:N0} file(s) could not be read (in use or access denied) and were counted as unique. Run with -Verbose to list them.' -f $unreadableFiles.Count)
}
if ($onlineOnlyFiles -gt 0) {
    Write-Warning ('{0:N0} online-only cloud file(s) were not compared, to avoid downloading them, and were counted as unique.' -f $onlineOnlyFiles)
}
if ($linkedFolders -gt 0) {
    Write-Host ('Skipped {0:N0} linked folder(s) (junctions or symbolic links).' -f $linkedFolders) -ForegroundColor DarkGray
}
if ($CsvPath) {
    if ($duplicates.Count -gt 0) { Write-Host "Duplicate list saved to $CsvPath" -ForegroundColor DarkGray }
    else { Write-Host 'No duplicates found, so no CSV was written.' -ForegroundColor DarkGray }
}
Write-Host ('Done in {0:N1} s' -f $clock.Elapsed.TotalSeconds) -ForegroundColor DarkGray
