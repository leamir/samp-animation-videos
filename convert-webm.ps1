# --- CONFIGURATION ---
$inputPath  = "C:\Users\Leamir\Desktop\test-anim-recording\samp-animations"
$outputDir  = "C:\Users\Leamir\Desktop\test-anim-recording\samp-animations-webm"

# Ensure outputDir exists
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# --- PROCESSING ---
Get-ChildItem -Path $inputPath -Recurse -Filter *.mp4 | ForEach-Object {
    $fullInput = $_.FullName

    # Get relative path
    $rel = $fullInput.Substring($inputPath.Length).TrimStart('\')

    # Replace extension with .webm
    $relWebm = [System.IO.Path]::ChangeExtension($rel, ".webm")

    # Final output file path
    $outFile = Join-Path $outputDir $relWebm

    Write-Host "Converting:" $fullInput
    Write-Host "To:" $outFile

    # Ensure output subfolder exists
    $destFolder = Split-Path $outFile
    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null

    # Run ffmpeg (video only, no audio)
    & "D:\yt-dlp\ffmpeg.exe" -i "$fullInput" `
        -c:v libvpx-vp9 `
        -crf 30 `
        -b:v 0 `
        -an `
        -y "$outFile"

    Write-Host "✅ Done:" $outFile
}
