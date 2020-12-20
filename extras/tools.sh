function errcho ()
{
    echo $@ >&2
}

function clone_repo ()
{
    # Download a Git repo
    #
    local branch="$1"
    local repo="$2"
    local source_dir="$3"
    if which git >/dev/null 2>&1; then
        echo Found git, nothing to install.
    else
        echo Git is not found, installing it.
        pacman -S --noconfirm git
    fi
    pushd . >/dev/null
    local error
    if test -d "$source_dir"; then
        echo Updating repository
        cd "$source_dir"
        git pull && git reset --hard && git checkout
        error=$?
        if test $? != 0; then
            echo Source repository update failed.
        fi
    else
        echo Cloning Emacs repository $repo.
        git clone --depth 1 -b $branch "$repo" "$source_dir" && \
            cd "$source_dir" && git config pull.rebase false
        error=$?
        if test $? != 0; then
            echo Git clone failed. Deleting source directory.
            rm -rf "$source_dir"
        fi
    fi
    #
    # If there was a 'configure' script, remove it, to force running autoreconf
    # again before builds.
    rm -f "$source_dir/configure"
    popd >/dev/null
    return $?
}


function full_dependency_list ()
{
    # Given a list of packages, print a list of all dependencies
    #
    # Input
    #  $1 = list of packages without dependencies
    #  $2 = list of packages to skip
    #
    # Packages that have to be replaced by others for distribution
    local munge_pgks="
        s,$mingw_prefix-libwinpthread,$mingw_prefix-libwinpthread-git,g;
        s,$mingw_prefix-libtre,$mingw_prefix-libtre-git,g;"

    local packages=`for p in $1; do echo $mingw_prefix-$p; done`
    local skip_pkgs=`for p in $2; do echo s,$mingw_prefix-$p,,g; done`
    local oldpackages=""
    local dependencies=""
    while test "$oldpackages" != "$packages" ; do
        oldpackages="$packages"
        dependencies=`pacman -Qii $oldpackages | grep Depends | sed -e 's,>=[^ ]*,,g;s,Depends[^:]*:,,g;s,None,,g;' -e "$skip_pkgs" -e "$munge_pgks"`
        packages=`echo $oldpackages $dependencies | sed -e 's, ,\n,g' | sort | uniq`
    done
    echo $packages
}

function ensure_packages ()
{
    local packages=$@
    echo Ensuring packages are installed
    if pacman -Qi $packages >/dev/null; then
        echo All packages are installed.
    else
        echo Some packages are missing. Installing them with pacman.
        pacman -S --noconfirm -q $packages
    fi
}

function prepare_source_dir ()
{
    local source_dir="$1"
    if test -d "$source_dir"; then
        if test -f "$source_dir/configure"; then
            echo Configure script exists. Nothing to do in source directory $source_dir
            echo
            return 0
        fi
        cd "$source_dir" && ./autogen.sh && return 0
        echo Unable to prepare source directory. Autoreconf failed.
    else
        echo Source directory $source_dir missing
        echo Run script with --clone first
        echo
    fi
    return -1
}

function prepare_build_dir ()
{
    local build_dir="$1"
    if test -d "$build_dir"; then
        if test -f "$build_dir/config.log"; then
            rm -rf "$build_dir/*"
        else
            echo Cannot rebuild on existing directory $build_dir
            return -1
        fi
    else
        mkdir -p "$build_dir"
    fi
}
