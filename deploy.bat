@echo off
echo ====================================
echo نشر التطبيق على النطاقين
echo ====================================

echo.
echo [1/4] تنظيف المجلدات القديمة...
if exist build\web\app rmdir /s /q build\web\app
if exist build\web\shoping rmdir /s /q build\web\shoping

echo.
echo [2/4] بناء التطبيق الرئيسي...
call flutter build web --release -t lib/main.dart
mkdir build\web\app
xcopy build\web\* build\web\app\ /E /Y /EXCLUDE:exclude.txt 2>nul
echo تم نسخ التطبيق الرئيسي

echo.
echo [3/4] بناء Sales Screen...
call flutter build web --release -t lib/main_shoping.dart
mkdir build\web\shoping
xcopy build\web\* build\web\shoping\ /E /Y /EXCLUDE:exclude.txt 2>nul
echo تم نسخ Sales Screen

echo.
echo [4/4] رفع إلى Firebase...
call firebase deploy --only hosting

echo.
echo ====================================
echo تم النشر بنجاح!
echo app.nithamsoft.com
echo shoping.nithamsoft.com
echo ====================================
pause