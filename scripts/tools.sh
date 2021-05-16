function errcho ()
{
    echo "$@" >&2
}

function unique_list ()
{
    echo $* | sed -e 's,[[:space:]][[:space:]]*,\n,g' | sort | uniq | sed -e '/^$/d'
}

function elements_not_in_list ()
{
    local listb=`echo $2 | sed 's,[[:space:]][[:space:]]*,|,g'`
    echo $1 | sed 's,[[:space:]],\n,g' | sort | uniq | grep -E -v "($listb)"
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

function apply_patches ()
{
	pushd . >/dev/null
	local error
	local source_dir="$1"
	shift
	cd "$source_dir"
	for patch_file in $*; do
		echo Applying patch ${patch_file} to repository at ${destination}
		git apply --ignore-space-change --ignore-whitespace -v "${patch_file}"
		error=$?
		if test "$error" != 0; then
			echo Failed to apply patch ${patch_file}
			git reset --hard
		fi
	done
	popd > /dev/null
	return $error
}

function raw_dependencies_wo_versions ()
{
    local munge_pgks="
             s,$mingw_prefix-libwinpthread\$,$mingw_prefix-libwinpthread-git,g;
             s,$mingw_prefix-libtre\$,$mingw_prefix-libtre-git,g;"
    pacman -Qii $* | grep Depends | sed -e 's,[>=][^ ]*,,g;s,Depends[^:]*:,,g;s,None,,g' -e "$munge_pgks"
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
    local oldpackages
    local dependencies
    if "$debug_dependency_list"; then
        local newpackages
        errcho "Debugging package list for $3"
        newpackages="$1"
        packages=""
        while [ -n "$newpackages" ]; do
            oldpackages=`unique_list $newpackages`
            packages=`unique_list $newpackages $packages`
            newpackages=""
            for p in $oldpackages; do
                dependencies=`raw_dependencies_wo_versions $p`
                dependencies=`elements_not_in_list "$dependencies" "$skip_pkgs $packages"`
                if [ -n "$dependencies" ]; then
                    errcho "Package $p introduces"
                    for i in $dependencies; do errcho "  $i"; done
                    newpackages="$dependencies $newpackages"
                fi
            done
        done
    else
        while test "$oldpackages" != "$packages" ; do
            oldpackages="$packages"
            dependencies=`raw_dependencies_wo_versions $oldpackages`
            test -n "$skip_pkgs" && \
                dependencies=`elements_not_in_list "$dependencies" "$skip_pkgs"`
            packages=`unique_list $oldpackages $dependencies`
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
    while [ $attempts -gt 0 ]; do
        curl --progress-bar --retry 3 --output "$destination" "$url" && return 0
        attempts=$(($attempts - 1))
    done
    return -1
}
