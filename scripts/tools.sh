function errcho ()
{
    echo "$@" >&2
}

function elements_not_in_list ()
{
    output=""
    for element in $1; do
        for other in $2; do
            found=""
            if test "$element" = "$other"; then
                found="$element"
                break
            fi
        done
        if test -z "$found"; then
            output="$element $output"
        fi
    done
    echo $output
}

function git_branch_name_to_file_name ()
{
    echo $1 | sed -e 's,[^-a-zA-Z0-9],_,g'
}

function clone_repo ()
{
    # Download a Git repo
    #
    local branch="$1"
    local repo="$2"
    local source_dir="$3"
    local dirname="$4"
    if test -z $dirname; then
        dirname=`git_branch_name_to_file_name $branch`
    fi
    if test -z `which git 2>/dev/null`; then
        echo Git is not found, installing it.
        pacman -S --noconfirm --needed git || return -1
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
    return $error
}

function full_dependency_list ()
{
    # Given a list of packages, print a list of all dependencies
    #
    # Input
    #  $1 = list of packages without dependencies
    #  $2 = list of packages to skip
    #  $3 = Origin of this list
    #  $4 = If non-empty, add mingw prefix
    #
    # Packages that have to be replaced by others for distribution
    local packages="$1"
    local skip_pkgs="$2"
    local context="$3"
    local avoid_prefix="$4"
    local munge_pgks="
             s, ,\n,g;
             s,$mingw_prefix-libwinpthread\$,$mingw_prefix-libwinpthread-git,g;
             s,$mingw_prefix-libtre\$,$mingw_prefix-libtre-git,g;"
    local oldpackages
    local dependencies
    if "$debug_dependency_list"; then
        local dependencies
        local newpackages
        errcho "Debugging package list for $3"
        while test "$oldpackages" != "$packages" ; do
            oldpackages="$packages"
            for p in $packages; do
                dependencies=`pacman -Qii $p | grep Depends | sed -e 's,[>=][^ ]*,,g;s,Depends[^:]*:,,g;s,None,,g' -e "$munge_pgks"`
                dependencies=`elements_not_in_list "$dependencies" "$skip_pkgs $packages"`
                if test -n "$dependencies"; then
                    errcho "Package $p introduces"
                    for i in $dependencies; do errcho "  $i"; done
                    newpackages="$dependencies $newpackages"
                fi
            done
            packages=`echo $packages $newpackages | sed -e 's, [ ]*,\n,g' | sort | uniq`
        done
    else
        while test "$oldpackages" != "$packages" ; do
            oldpackages="$packages"
            dependencies=`pacman -Qii $oldpackages | grep Depends | sed -e 's,[>=][^ ]*,,g;s,Depends[^:]*:,,g;s,None,,g' -e "$munge_pgks"`
            test -n "$skip_pkgs" && \
                dependencies=`elements_not_in_list "$dependencies" "$skip_pkgs"`
            packages=`echo $oldpackages $dependencies | sed -e 's, ,\n,g' | sort | uniq`
        done
    fi
    echo $packages
}

function ensure_packages ()
{
    local packages=$@
    echo Ensuring packages are installed
    if pacman -Qi $packages >/dev/null 2>&1; then
        echo All packages are installed.
    else
        echo Some packages are missing. Installing them with pacman.
        pacman -S --needed --noconfirm -q $packages
    fi
}

function package_dependencies ()
{
    local zipfile="$1"
    local dependencies="$2"
    rm -f "$zipfile"
    mkdir -p `dirname "$zipfile"`
    cd $mingw_dir
    if test -n "$debug_dependency_list"; then
        echo Files prior to filter
        pacman -Ql $dependencies | cut -d ' ' -f 2 | sort | uniq \
            | grep "^$mingw_dir" | sed -e "s,^$mingw_dir,,g"
        echo Filter
        echo $slim_exclusions
        echo Files to package
        pacman -Ql $dependencies | cut -d ' ' -f 2 | sort | uniq \
            | grep "^$mingw_dir" | sed -e "s,^$mingw_dir,,g" | dependency_filter
    fi
    echo Packing dependency files from root dir $mingw_dir
    pacman -Ql $dependencies | cut -d ' ' -f 2 | sort | uniq \
        | grep "^$mingw_dir" | sed -e "s,^$mingw_dir,,g" | dependency_filter | xargs zip -9v $zipfile
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

function try_download ()
{
    local url="$1"
    local destination="$2"
    local attempts="$3"
    if [ -z "$attempts" ]; then
        attempts=3
    fi
    while [ $attempts -gt 0 ]; then
        curl --progress-bar --retry 3 --output "$destination" "$url" && return 0
        attempts=$(($attempts - 1))
    fi
    return -1
}
