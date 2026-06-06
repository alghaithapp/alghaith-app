Add-Type -AssemblyName System.Drawing
$imageFolder = "C:\New folder\alghaith-app\assets\images"
$files = Get-ChildItem -Path $imageFolder -Filter *.png

foreach ($file in $files) {
    if ($file.Name -eq "logo.png") { continue } # Skip logo

    Write-Host "Processing $($file.Name)..."
    $img = [System.Drawing.Image]::FromFile($file.FullName)

    # Banners get 1024, everything else 600
    $maxSize = 600
    if ($file.Name -like "*banner*") { $maxSize = 1024 }

    $width = $img.Width
    $height = $img.Height

    if ($width -gt $maxSize -or $height -gt $maxSize) {
        if ($width -gt $height) {
            $newWidth = $maxSize
            $newHeight = [int]($height * ($maxSize / $width))
        } else {
            $newHeight = $maxSize
            $newWidth = [int]($width * ($maxSize / $height))
        }

        $newImg = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
        $g = [System.Drawing.Graphics]::FromImage($newImg)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($img, 0, 0, $newWidth, $newHeight)
        $g.Dispose()
        $img.Dispose()

        $tempPath = "$($file.FullName).tmp"
        # Save as PNG
        $newImg.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $newImg.Dispose()

        Move-Item -Path $tempPath -Destination $file.FullName -Force
        $newSize = (Get-Item $file.FullName).Length
        Write-Host "  -> Resized to $($newWidth)x$($newHeight). New size: $([Math]::Round($newSize/1KB, 2)) KB"
    } else {
        $img.Dispose()
        Write-Host "  -> Skipped (already small enough)"
    }
}
