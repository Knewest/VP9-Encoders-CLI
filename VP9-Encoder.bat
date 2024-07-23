@echo off

rem Get the count of video files in the script directory:
for /f %%i in ('dir /b /a-d "%~dp0*.mp4" "%~dp0*.avi" "%~dp0*.mov" "%~dp0*.mkv" "%~dp0*.wmv" "%~dp0*.flv" "%~dp0*.webm" "%~dp0*.av1" "%~dp0*.m2ts" "%~dp0*.ts" 2^>nul ^| find /c /v ""') do set "fileCount=%%i"

if %fileCount% gtr 1 (
    echo Multiple video files found in the folder. Please ensure there is only one video file in the folder.
    timeout /t 1800 >nul
    exit /b
)

rem Check if FFmpegLocation.txt exists: (C:\Codecs\LibFFmpegv4.2.3\bin\ffmpeg.exe)
if not exist "%~dp0FFmpegLocation.txt" (
    echo FFmpegLocation.txt not found. Please provide the location of FFmpeg.
    set /p ffmpegLocation=Enter the path of FFmpeg/FFprobe: 
) else (
    rem Read FFmpeg and FFprobe location from FFmpegLocation.txt:
    set /p ffmpegLocation=<"%~dp0FFmpegLocation.txt"
)

rem Check if FFprobeLocation.txt exists: (C:\Codecs\LibFFmpegv4.2.3\bin\ffprobe.exe)
if not exist "%~dp0FFprobeLocation.txt" (
    echo FFprobeLocation.txt not found. Please provide the location of FFprobe.
    set /p ffprobeLocation=Enter the path of FFprobe: 
) else (
    rem Read FFprobe location from FFprobeLocation.txt:
    set /p ffprobeLocation=<"%~dp0FFprobeLocation.txt"
)

echo %ffmpegLocation% > "%~dp0FFmpegLocation.txt"
echo %ffprobeLocation% > "%~dp0FFprobeLocation.txt"
set /p CQP=Enter the CQP number (lower values are higher quality (0-63)): 
set /p DEADLINE=Set the deadline (quality) option (("good" is default) realtime, good, best): 
set /p ENC-SPD=Set the encoding speed (lower values are slower (0-5 (0-8 for realtime))): 
set /p THRDS=Set the amount of CPU threads to use: 

(
echo # Get the directory where the script is located
echo $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
echo.
echo # Set the output folder to be the same as the script directory
echo $outputFolder = $scriptDir
echo.
echo # Set FFmpeg directory path:
echo $FFmpegDirectory = "%ffmpegLocation%"
echo.
echo # Get all video files in the script directory
echo $videos = Get-ChildItem -Path $scriptDir -File ^| Where-Object { $_.Extension -match '\.(mp4^|avi^|mov^|mkv^|wmv^|flv^|webm^|av1^|m2ts^|ts^)$' }
echo.
echo # Loop through each video file:
echo foreach ($video in $videos^) {
echo  # Define output file path and name
echo     $outputFile = Join-Path -Path $outputFolder -ChildPath ($video.BaseName + "_xVP9_CQP-%CQP%_SPD-0%ENC-SPD%_%DEADLINE%.webm"^)
echo.
echo     # Get the number of audio streams:
echo     $audioStreams = ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffprobe.exe')" -v error -select_streams a -show_entries stream=index -of csv=p=0 $video.FullName ^| Measure-Object -Line
echo     $numAudioStreams = $audioStreams.Lines
echo.
echo     # Define the filter_complex option based on the number of audio streams:
echo     if ($numAudioStreams -gt 1^) {
echo         $filterComplex = ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -filter_complex "[0:a]amerge=inputs=${numAudioStreams}[aout]" -map 0:v -map "[aout]" -vn -c:a pcm_f32le -threads %THRDS% -y ("$outputFile" + "temp_audio" + ".wav"^)
echo         $downMixStreams = ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_audio" + ".wav"^) -vn -c:a pcm_f32le -threads %THRDS% -af "pan=stereo|c0=c0+c2+0.5*c4|c1=c1+c2+0.5*c5" ("$outputFile" + "temp_audio_downmixed" + ".wav"^)
echo     Remove-Item -Path ("$outputFile" + "temp_audio" + ".wav"^)
echo     } elseif ($numAudioStreams -eq 1^) {
echo         $filterComplex = ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -vn -c:a pcm_f32le -threads %THRDS% -y ("$outputFile" + "temp_audio_downmixed" + ".wav"^)
echo         # $downMixStreams = ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_audio" + ".wav"^) -vn -c:a pcm_f32le -threads %THRDS% ("$outputFile" + "temp_audio_downmixed" + ".wav"^)
echo     }
echo.
echo     $filterComplex
echo.
echo     # $downMixStreams
echo     # Remove-Item -Path ("$outputFile" + "temp_audio" + ".wav"^)
echo.
echo.
echo     # First pass for video encoding:
echo     ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 1 -b:v 0 -crf %CQP% -deadline best -threads %THRDS% -cpu-used 1 -tile-columns 6 -frame-parallel 1 -lag-in-frames 25 -aq-mode 3 -g 640 -pix_fmt yuv444p -row-mt 1 -an -f null NUL
echo.
echo.
echo     # Compress video without audio using second pass:
echo     ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i $video.FullName -c:v libvpx-vp9 -pass 2 -b:v 0 -crf %CQP% -deadline %DEADLINE% -threads %THRDS% -cpu-used %ENC-SPD% -tile-columns 6 -frame-parallel 1 -lag-in-frames 25 -aq-mode 3 -g 640 -pix_fmt yuv444p -row-mt 1 -an -y ("$outputFile" + "temp_video" + ".webm"^) -passlogfile "ffmpeg2pass-0"
echo.
echo     if ($numAudioStreams -eq 0^) {
echo         Rename-Item -Path ("$outputFile" + "temp_video" + ".webm"^) -NewName $outputFile
echo         Write-Host " "
echo         Write-Host "No audio found, skipping audio/video merge remux."
echo         return
echo     }
echo     elseif ($numAudioStreams -gt 0^) {
echo         # Merge audio and video:
echo         ^& "$(Join-Path $([System.IO.Path]::GetDirectoryName($FFmpegDirectory)) 'ffmpeg.exe')" -i ("$outputFile" + "temp_video" + ".webm"^) -i ("$outputFile" + "temp_audio_downmixed" + ".wav"^) -c:v copy -c:a libopus -b:a 510k -vbr on -threads %THRDS% -y $outputFile
echo     }
echo.
echo     # Delete temporary files:
echo     Remove-Item -Path ("$outputFile" + "temp_audio_downmixed" + ".wav"^) -ErrorAction SilentlyContinue
echo     Remove-Item -Path ("$outputFile" + "temp_video" + ".webm"^) -ErrorAction SilentlyContinue
echo     Remove-Item -Path "ffmpeg2pass-0.log"
echo.
echo     Write-Host " "
echo     Write-Host " "
echo     Write-Host "Video '$($video.Name)' encoded to VP9 with CQP %CQP% and saved as '$($outputFile)'."
echo     Write-Host " "
echo     Write-Host "Copyright (Boost Software License 1.0) 2024-2024 Knew"
echo     Write-Host "https://github.com/Knewest"
echo     return
echo }
) > VP9_Encoder.ps1

echo PowerShell script created: VP9_Encoder.ps1

echo Executing the PowerShell script...

rem Check if PowerShell 7 is installed:
where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    rem PowerShell 7 is installed, use it to execute the script:
    start "" /wait /b pwsh -NoProfile -ExecutionPolicy Bypass -File VP9_Encoder.ps1
) else (
    rem PowerShell 7 is not installed, fall back to PowerShell 5:
    start "" /wait /b powershell -NoProfile -ExecutionPolicy Bypass -File VP9_Encoder.ps1
)

rem After the PowerShell script finishes, continue with the batch script:
echo    

echo The console will close automatically after 30 minutes...

rem Wait for 30 minutes before closing:
timeout /t 1800 >nul

rem Kill the PowerShell process after 30 minutes:
taskkill /f /im powershell.exe >nul 2>&1

del VP9_Encoder.ps1
exit

rem v1.4 of Knew's VP9 encoder.
