@echo off

:: Commands

DOSKEY ls=dir \B %1
DOSKEY subl="%ProgramFiles%\Sublime Text 3\subl.exe"

DOSKEY grevertall=git reset --hard ^& git reset --hard origin/master ^& git clean -f -d
DOSKEY grevertfile=git checkout -- $1
DOSKEY gstat=git status
DOSKEY gpush=git push
DOSKEY gpull=git pull
DOSKEY gpullr=git pull --rebase
DOSKEY gdiff=git difftool $*
DOSKEY gcommit=git add -A :/ ^& git commit -m $*
DOSKEY gtag=git tag -a $1 -m $2 :/ ^& git push --tags
DOSKEY gcln=git clean -fdx
DOSKEY gbra=git checkout -b $*
DOSKEY gdelbra=git push origin -delete $* ^& git branch -d $*
DOSKEY gconf=git diff --name-only --diff-filter=U
DOSKEY gpendingcommits=git log --branches  @{u}..
DOSKEY gmast=git checkout master
DOSKEY gsubmods=git submodule update --init --recursive
DOSKEY gbra=git checkout -b $1
DOSKEY glog=git log --pretty=oneline -10
DOSKEY grem=git remote -v
DOSKEY rmir=robocopy /mir /np /r:0 /w:0 /DCOPY:DAT $1 $2
DOSKEY sshs=ssh shitals@$1 -t tmux new -A -s 0
DOSKEY jnb=jupyter notebook
DOSKEY pu=pushd .
DOSKEY po=popd
:: Common directories

DOSKEY gsrc=cd /d "c:\GitHubSrc\"
DOSKEY bashrt=cd /d "%LOCALAPPDATA%\lxss\rootfs"
