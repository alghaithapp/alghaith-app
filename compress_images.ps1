Add-Type -AssemblyName System.Drawing
$imageFolder = "C:\New folder\alghaith-app\assets\images"
$files = Get-ChildItem -Path $imageFolder -Filter *.png

foreach ($file in $files) {
    if ($file.Length -gt 500KB) {
        Write-Host "Compressing $($file.Name)..."
        $img = [System.Drawing.Image]::FromFile($file.FullName)

        $maxSize = 1024
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

            # Save to a temporary file first
            $tempPath = "$($file.FullName).tmp"
            $newImg.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $newImg.Dispose()

            # Replace original
            Move-Item -Path $tempPath -Destination $file.FullName -Force
            Write-Host "Resized and compressed $($file.Name)"
        } else {
            # Just re-save to compress if dimensions are okay but file is large
            $tempPath = "$($file.FullName).tmp"
            $img.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $img.Dispose()
            Move-Item -Path $tempPath -Destination $file.FullName -Force
            Write-Host "Re-saved $($file.Name)"
        }
    }
}
