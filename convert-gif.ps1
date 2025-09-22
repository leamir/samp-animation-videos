$inputPath = (Resolve-Path "C:\Users\Leamir\Desktop\test-anim-recording\samp-animations").Path
$outputDir = "C:\Users\Leamir\Desktop\test-anim-recording\samp-animations-gifs"

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Get-ChildItem -Path $inputPath -Recurse -Filter *.mp4 | ForEach-Object {
    # Full path of the .mp4
    $full = $_.FullName

    # Remove the inputPath plus a backslash from the front of full
    $rel = $full.Substring($inputPath.Length + 1)

    # Change the extension to .gif
    $relGif = [System.IO.Path]::ChangeExtension($rel, ".gif")

    # Build output file path
    $outFile = Join-Path $outputDir $relGif

    Write-Host "Input: $full"
    Write-Host "Output: $outFile"

    # Make sure dest folder exists
    $destFolder = Split-Path $outFile
    New-Item -ItemType Directory -Path $destFolder -Force | Out-Null

    # Run ffmpeg
    & "D:\yt-dlp\ffmpeg.exe" -i "$full" -vf "fps=30" -y "$outFile"
}
