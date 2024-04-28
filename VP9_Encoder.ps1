# Get the directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set the output folder to be the same as the script directory
$outputFolder = $scriptDir

# Set FFmpeg directory path:
$FFmpegDirectory = "C:\Codecs\LIBFFM~1.3\bin\ffmpeg.exe                                                                                                                                                                                                                                                                                                                                                                                                                                 "

# Get all video files in the script directory
$videos = Get-ChildItem -Path $scriptDir -File | Where-Object { $_.Extension -match '\.(mp4|avi|mov|mkv|wmv|flv|webm|av1|m2ts|ts)$' }

# Loop through each video file:
foreach ($video in $videos) {
    # Define output file path and name
    $outputFile = Join-Path -Path $outputFolder -ChildPath ($video.BaseName + "_xVP9_CQP-4_SPD-04_4.webm")

    # Extract audio from video file:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -filter_complex "[0:a]amerge=inputs=4[aout]" -map 0:v -map "[aout]" -vn -c:a pcm_s16le -threads 4 -y ("$outputFile" + "temp_audio" + ".wav")

    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_audio" + ".wav") -vn -c:a pcm_s16le -threads 4 -af "pan=stereo|c0=c0+c2+c4+c6|c1=c0+c2+c4+c6" ("$outputFile" + "temp_audio_downmixed" + ".wav")
    Remove-Item -Path ("$outputFile" + "temp_audio" + ".wav")


    # First pass for video encoding:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 1 -b:v 0 -crf 4 -deadline best -threads 4 -cpu-used 1 -pix_fmt yuv444p -row-mt 1 -an -f null NUL


    # Compress video without audio using second pass:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 2 -b:v 0 -crf 4 -deadline 4 -threads 4 -cpu-used 4 -pix_fmt yuv444p -row-mt 1 -an -y ("$outputFile" + "temp_video" + ".webm")


    # Merge audio and video:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_video" + ".webm") -i ("$outputFile" + "temp_audio_downmixed" + ".wav") -c:v copy -c:a libopus -b:a 510k -threads 4 -y $outputFile

    # Delete temporary files:
    Remove-Item -Path ("$outputFile" + "temp_audio_downmixed" + ".wav")
    Remove-Item -Path ("$outputFile" + "temp_video" + ".webm")
    Remove-Item -Path "ffmpeg2pass-0.log"

    Write-Host " "
    Write-Host " "
    Write-Host "Video '$($video.Name)' encoded to VP9 with CQP 4 and saved as '$($outputFile)'."
    Write-Host " "
    Write-Host "Copyright (Boost Software License 1.0) 2024-2024 Knew"
    Write-Host "https://github.com/Knewest/VP9-Encoders-CLI/"
    return
}
