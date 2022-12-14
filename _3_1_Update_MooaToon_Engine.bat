setlocal enabledelayedexpansion

set repoURL=https://github.com/Jason-Ma-0012/MooaToon-Engine.git
set repoName=MooaToon-Engine
set branchName=5.1


if not exist %repoName% mkdir %repoName%
cd %repoName%

git init

:loop
git fetch --depth=1 %repoURL% %branchName%
if not %errorlevel% == 0 (
   echo Fetch failed, retrying in 5 seconds...
   timeout /t 5 /nobreak
   goto loop
)

git reset --hard
git pull origin %branchName%
git checkout %branchName%
git merge origin %branchName%


echo %repoName% successfully update.
timeout /t 5