@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ====================================================
REM 路径配置
REM ====================================================
set SRC=E:\FDUSHMC\MICCAI\GBM_OS\original_data\GBM_OS\supply2
set DST=C:\Users\fqy\Desktop\supply2
set SLICER="D:\Slicer 5.8.1\Slicer.exe"
set ZIP="C:\Program Files\7-Zip\7z.exe"
set PY_APPLY=apply_mat.py
set PY_DICOM2NII=dicom2nii.py

echo ========================================
echo 批量处理开始
echo ========================================

REM 遍历病例文件夹
for /d %%I in ("%SRC%\*") do (
    echo.
    echo ----------------------------------------
    echo 处理病例: %%~nI
    echo ----------------------------------------
    set "ID=%%~nI"

    REM 创建目标目录
    if not exist "%DST%\!ID!" mkdir "%DST%\!ID!"
    if not exist "%DST%\!ID!\start_reg" mkdir "%DST%\!ID!\start_reg"
    if not exist "%DST%\!ID!\mid_reg" mkdir "%DST%\!ID!\mid_reg"

    REM 压缩原始 NII 文件
    for %%F in (11 12 21 22) do (
        if exist "%%I\%%F.nii" (
            echo 压缩 %%I\%%F.nii ...
            %ZIP% a -tgzip "%%I\%%F.gz" "%%I\%%F.nii" >nul
            move "%%I\%%F.gz" "%%I\%%F.nii.gz" >nul
            del "%%I\%%F.nii" >nul
        )
    )

    call :ProcessStage "%%I" "!ID!" "1" "start_reg"
    call :ProcessStage "%%I" "!ID!" "2" "mid_reg"

    echo 病例 !ID! 处理完成。
)

echo ========================================
echo 全部病例完成！
echo ========================================
pause
exit /b


:ProcessStage
REM 参数: 1=CASE_DIR  2=CASE_ID  3=阶段号(1或2)  4=输出子文件夹名
set "CASE_DIR=%~1"
set "CASE_ID=%~2"
set "STAGE=%~3"
set "OUTNAME=%~4"

echo [阶段 %STAGE%] 正在处理...

set "FIXED="
set "MOVING="

if exist "%CASE_DIR%\%STAGE%" (
    for /d %%a in ("%CASE_DIR%\%STAGE%\*") do (
        echo %%~na | find /I "T2" >nul && set "MOVING=%%a"
        echo %%~na | find /I "T1" >nul && set "FIXED=%%a"
    )
)

if "%FIXED%"=="" (
    echo [警告] 未找到 T1 文件夹，跳过 %CASE_ID% 阶段 %STAGE%
    exit /b
)
if "%MOVING%"=="" (
    echo [警告] 未找到 T2 文件夹，跳过 %CASE_ID% 阶段 %STAGE%
    exit /b
)

REM ----------------------------------------
REM 1. DICOM → NIfTI
REM ----------------------------------------
echo 转换 T1 和 T2 为 NIfTI...
python "%PY_DICOM2NII%" "%FIXED%" "%DST%\%CASE_ID%\%OUTNAME%\T1_C.nii.gz"
python "%PY_DICOM2NII%" "%MOVING%" "%DST%\%CASE_ID%\%OUTNAME%\T2.nii.gz"

REM ----------------------------------------
REM 2. 配准
REM ----------------------------------------
echo 执行 BRAINSFit 配准...
%SLICER% --launch BRAINSFit ^
    --fixedVolume "%DST%\%CASE_ID%\%OUTNAME%\T1_C.nii.gz" ^
    --movingVolume "%DST%\%CASE_ID%\%OUTNAME%\T2.nii.gz" ^
    --outputTransform "%DST%\%CASE_ID%\%OUTNAME%\T2_to_T1C.mat" ^
    --outputVolume "%DST%\%CASE_ID%\%OUTNAME%\T2_reg.nii.gz" ^
    --useRigid --useAffine

del "%DST%\%CASE_ID%\%OUTNAME%\T2.nii.gz" >nul

REM ----------------------------------------
REM 3. 复制 ROI 并应用矩阵
REM ----------------------------------------
if "%STAGE%"=="1" (
    if exist "%CASE_DIR%\11.nii.gz" (
        echo 解压并复制 11.nii.gz 为 M1.nii...
        %ZIP% x "%CASE_DIR%\11.nii.gz" -o"%TEMP%\" >nul
        move "%TEMP%\11.nii" "%DST%\%CASE_ID%\M1.nii" >nul
    )
    if exist "%CASE_DIR%\12.nii.gz" (
        echo 应用变换到 ROI 12...
        %ZIP% x "%CASE_DIR%\12.nii.gz" -o"%TEMP%\" >nul
        python "%PY_APPLY%" "%DST%\%CASE_ID%\%OUTNAME%\T1_C.nii.gz" "%TEMP%\12.nii" "%DST%\%CASE_ID%\%OUTNAME%\T2_to_T1C.mat" "%DST%\%CASE_ID%\1.nii"
        del "%TEMP%\12.nii" >nul
    )
)
if "%STAGE%"=="2" (
    if exist "%CASE_DIR%\21.nii.gz" (
        echo 解压并复制 21.nii.gz 为 M2.nii...
        %ZIP% x "%CASE_DIR%\21.nii.gz" -o"%TEMP%\" >nul
        move "%TEMP%\21.nii" "%DST%\%CASE_ID%\M2.nii" >nul
    )
    if exist "%CASE_DIR%\22.nii.gz" (
        echo 应用变换到 ROI 22...
        %ZIP% x "%CASE_DIR%\22.nii.gz" -o"%TEMP%\" >nul
        python "%PY_APPLY%" "%DST%\%CASE_ID%\%OUTNAME%\T1_C.nii.gz" "%TEMP%\22.nii" "%DST%\%CASE_ID%\%OUTNAME%\T2_to_T1C.mat" "%DST%\%CASE_ID%\2.nii"
        del "%TEMP%\22.nii" >nul
    )
)

del "%DST%\%CASE_ID%\%OUTNAME%\T2_to_T1C.mat" >nul
del "%DST%\%CASE_ID%\%OUTNAME%\T2_to_T1C_Inverse.h5" >nul

exit /b
