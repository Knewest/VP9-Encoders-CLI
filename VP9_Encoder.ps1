# Get the directory where the script is located
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Set the output folder to be the same as the script directory
$outputFolder = $scriptDir

# Set FFmpeg directory path:
$FFmpegDirectory = "C:\Codecs\LibFFmpegv4.2.3\bin\ffmpeg.exe                                                                                              "

# Get all video files in the script directory
$videos = Get-ChildItem -Path $scriptDir -File | Where-Object { $_.Extension -match '\.(mp4|avi|mov|mkv|wmv|flv|webm|av1|m2ts|ts)$' }

# Loop through each video file:
foreach ($video in $videos) {
 # Define output file path and name
    $outputFile = Join-Path -Path $outputFolder -ChildPath ($video.BaseName + "_xVP9_CQP-57_SPD-01_best.webm")

    # Get the number of audio streams:
    $audioStreams = & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffprobe.exe')" -v error -select_streams a -show_entries stream=index -of csv=p=0 $video.FullName | Measure-Object -Line
    $numAudioStreams = $audioStreams.Lines

    # Define the filter_complex option based on the number of audio streams:
    if ($numAudioStreams -gt 1) {
        $filterComplex = & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -filter_complex "[0:a]amerge=inputs=${numAudioStreams}[aout]" -map 0:v -map "[aout]" -vn -c:a pcm_f32le -threads 16 -y ("$outputFile" + "temp_audio" + ".wav")
        $downMixStreams = & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_audio" + ".wav") -vn -c:a pcm_f32le -threads 16 -af "pan=stereo|c0=c0+c2+0.5*c4|c1=c1+c2+0.5*c5" ("$outputFile" + "temp_audio_downmixed" + ".wav")
    Remove-Item -Path ("$outputFile" + "temp_audio" + ".wav")
    } elseif ($numAudioStreams -eq 1) {
        $filterComplex = & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -vn -c:a pcm_f32le -threads 16 -y ("$outputFile" + "temp_audio_downmixed" + ".wav")
        # $downMixStreams = & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_audio" + ".wav") -vn -c:a pcm_f32le -threads 16 ("$outputFile" + "temp_audio_downmixed" + ".wav")
    }

    $filterComplex

    # $downMixStreams
    # Remove-Item -Path ("$outputFile" + "temp_audio" + ".wav")


    # First pass for video encoding:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 1 -b:v 0 -crf 57 -deadline best -threads 16 -cpu-used 1 -tile-columns 6 -frame-parallel 1 -lag-in-frames 25 -aq-mode 3 -g 640 -pix_fmt yuv444p -row-mt 1 -an -f null NUL


    # Compress video without audio using second pass:
    & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 2 -b:v 0 -crf 57 -deadline best -threads 16 -cpu-used 1 -tile-columns 6 -frame-parallel 1 -lag-in-frames 25 -aq-mode 3 -g 640 -pix_fmt yuv444p -row-mt 1 -an -y ("$outputFile" + "temp_video" + ".webm") -passlogfile "ffmpeg2pass-0"

    if ($numAudioStreams -eq 0) {
        Rename-Item -Path ("$outputFile" + "temp_video" + ".webm") -NewName $outputFile
        Write-Host " "
        Write-Host "No audio found, skipping audio/video merge remux."
    }
    elseif ($numAudioStreams -gt 0) {
        # Merge audio and video:
        & "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_video" + ".webm") -i ("$outputFile" + "temp_audio_downmixed" + ".wav") -c:v copy -c:a libopus -b:a 510k -vbr on -threads 16 -y $outputFile
    }

    # Delete temporary files:
    Remove-Item -Path ("$outputFile" + "temp_audio_downmixed" + ".wav") -ErrorAction SilentlyContinue
    Remove-Item -Path ("$outputFile" + "temp_video" + ".webm") -ErrorAction SilentlyContinue
    Remove-Item -Path "ffmpeg2pass-0.log"

    Write-Host " "
    Write-Host " "
    Write-Host "Video '$($video.Name)' encoded to VP9 with CQP 57 and saved as '$($outputFile)'."
    Write-Host " "
    Write-Host "Copyright (Boost Software License 1.0) 2024-2024 Knew"
    Write-Host "https://github.com/Knewest"
    return
}
