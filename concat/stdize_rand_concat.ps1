# This shuffles and combines multiple media files (until output exceeds custom total duration or file count) into single file
# Duration field should always be available with standardized media files!

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

$limitMinutes = 60
$MaxRandFileCount = 360
$MediaExtStr = "*.ts","*.mp4","*.wmv","*.mkv"

# Define Input and Output directories
$InputDir = "..\*"
$OutputDir = "standardized"
$FFmpegPath = "ffmpeg.exe"

# Create the output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# Get all media files in the input directory and loop through them
Get-ChildItem -Path $InputDir -Include $MediaExtStr | ForEach-Object {

    # re-encode to a common container!
    $OutputExtension = ".mp4"
    
    # remove single quotes from filename
    $BaseNameNoQuote = $_.BaseName.Replace("'", "")

    # Construct the full path of the potential destination file
    $DestinationPath = Join-Path -Path $OutputDir -ChildPath $($BaseNameNoQuote + $OutputExtension)

    # Check if the file already exists in the destination
    if (Test-Path -Path $DestinationPath -PathType Leaf) {
        Write-Host "File '$($_.Name)' already exists in $OutputDir. Skipping..."
        return # Skip the rest of the code in this iteration and move to the next file
          # To skip current iteration and continue in a ForEach-Object, use return instead of continue!
    }

    $InputFile = $_.FullName
    $OutputFile = Join-Path -Path $OutputDir -ChildPath $($BaseNameNoQuote + $OutputExtension)

    # Build the full FFmpeg command arguments
    # Note: Use backticks (`) to escape quotes within the string, as required by PowerShell for external commands.
    # Optional stream mapping (?) syntax doesn't seem to work. Reprocess with null audio later
    $Arguments = "-init_hw_device d3d11va=hw -filter_hw_device hw -i `"$InputFile`" -/filter_complex filter_complex_fhd.txt -map `"[vout]`" -map `"[aout]`"? -c:v hevc_qsv -global_quality 20 -c:a aac `"$OutputFile`""
    # $Arguments = "-i `"$InputFile`" -/filter_complex filter_complex_vr.txt -map `"[vout]`" -map `"[aout]`" -c:v libx264 -preset medium -crf 20 -c:a aac `"$OutputFile`""

    Write-Host "Processing: $InputFile"
    Write-Host "Output to: $OutputFile"

    # Execute the FFmpeg command
    # The -NoNewWindow and -Wait parameters ensure the script runs smoothly and waits for each file to finish
    Start-Process -FilePath $FFmpegPath -ArgumentList $Arguments -NoNewWindow -Wait
    
    # fix 0 byte output (add null audio track)
    if ((Get-Item $OutputFile).length -eq 0) {
        Write-Host "File $OutputFile has 0 bytes. Reprocessing source with null audio!"
        # -f lavfi -i anullsrc: create input stream from anullsrc filter, which produces infinite silence
        # -shortest: finish encoding when shortest input stream ends
        $Arguments = "-y -init_hw_device d3d11va=hw -filter_hw_device hw -i `"$InputFile`" -f lavfi -i anullsrc -/filter_complex filter_complex_fhd_nula.txt -map `"[vout]`" -map `"[aout]`"? -c:v hevc_qsv -global_quality 20 -c:a aac -shortest `"$OutputFile`""
        Start-Process -FilePath $FFmpegPath -ArgumentList $Arguments -NoNewWindow -Wait
    }
}

Write-Host "Batch standardization complete"
Write-Host "Randomizing + concatenating media upto total of >60 mins or $MaxRandFileCount files, whichever hits earlier!"


# Get files and initialize
$files = Get-ChildItem -Path $OutputDir -Include $MediaExtStr -Recurse | Get-Random -Count $MaxRandFileCount    # Randomize order
$selectedFiles = @()
$totalSeconds = 0
$limitSeconds = $limitMinutes * 60

# Add shell object to get file duration
$shell = New-Object -ComObject Shell.Application

foreach ($file in $files) {
    if ($totalSeconds -ge $limitSeconds) { break }
    
    # Get Duration
    $folderObject = $shell.Namespace($file.DirectoryName)
    $fileObject = $folderObject.ParseName($file.Name)
    $durationStr = $folderObject.GetDetailsOf($fileObject, 27)    # 27 is duration for media
    
    if (-not [string]::IsNullOrWhiteSpace($durationStr)) {
        $durationParts = $durationStr -split ':'
        if ($durationParts.Count -eq 3) {
            $secs = ([int]$durationParts[0] * 3600) + ([int]$durationParts[1] * 60) + [int]$durationParts[2]
        } elseif ($durationParts.Count -eq 2) {
            $secs = ([int]$durationParts[0] * 60) + [int]$durationParts[1]
        } else { $secs = 0 }
        
        $selectedFiles += $file.FullName
        $totalSeconds += $secs
    }
}

# Output Results
# $selectedFiles
Write-Host "Total randomized duration: $([Math]::Round($totalSeconds / 60, 2)) minutes"


$PlaySeqFile = "stdzd_file_seq.txt"
Clear-Content -Path $PlaySeqFile -ErrorAction SilentlyContinue
foreach ($i in $selectedFiles) {"file '$i'" | Out-File $PlaySeqFile -Encoding utf8 -Append}

# ffmpeg -y -f concat -safe 0 -i $PlaySeqFile -c copy -r 30 merged_tmp.mp4
$grandparentDir = (Get-Item "..").Name
ffmpeg -y -f concat -safe 0 -i $PlaySeqFile -c copy "$grandparentDir`_rand_combo.mkv"
