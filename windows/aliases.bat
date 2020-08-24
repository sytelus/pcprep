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
DOSKEY gdelbra=git push origin -delete $* ^& git branch -d $*
DOSKEY gconf=git diff --name-only --diff-filter=U
DOSKEY gviewcommits=git log --pretty=oneline  -n 10
DOSKEY gclean=git clean -fdx
DOSKEY gcreatebranch=git checkout -b $*
DOSKEY gdeletebranch=git push origin -delete $* ^& git branch -d $*
DOSKEY gpendingconf=git diff --name-only --diff-filter=U
DOSKEY gpendingcommits=git log --branches  @{u}..
DOSKEY gmaster=git checkout master
DOSKEY gsubmods=git submodule update --init --recursive
DOSKEY gbra=git checkout -b $1
DOSKEY glog=git log --pretty=oneline -10
DOSKEY grem=git remote -v
DOSKEY gbranch=git checkout -b $1
DOSKEY gcommithistory=git log --pretty=oneline -10
DOSKEY rmir=robocopy /mir /np /r:0 /w:0 /DCOPY:DAT $1 $2
DOSKEY sshs=ssh shitals@$1 -t tmux new -A -s 0
DOSKEY jnb=jupyter notebook
DOSKEY pu=pushd .
DOSKEY po=popd
DOSKEY copynewfiles=robocopy $1 $2 /E /DCOPY:DAT /R:0
DOSKEY mirfiles=robocopy $1 $2 /MIR /DCOPY:DAT /R:0

:: Common directories

DOSKEY gsrc=cd /d "c:\GitHubSrc\"
DOSKEY bashrt=cd /d "%LOCALAPPDATA%\lxss\rootfs"
