#!/bin/bash
# Copyright 2020 Juan Jose Garcia-Ripoll
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
########################################
#
# EMACS-BUILD
#
# Standalone script to build Emacs from a running copy of Mingw64. It immitates
# the steps that Emacs developers can take to build the standard distributions.
# See write_help below for all options.
#

function write_help () {
    cat <<EOF
Usage:

   ./emacs-build.sh [-64] [-32] [--clone] [--build] [--deps] [--without-X] [--with-X]

Actions:

   --clone       Download Savannah's git repository for Emacs
   --ensure      Ensure that required packages are installed
   --build       Configure and build Emacs from sources
   --deps        Create a ZIP file with all the Mingw64/32 dependencies
   --package     Package an Emacs previously built with the --build option

   Multiple actions can be selected. The default is to run them all in a logical
   order: clone, ensure, build, deps and package.

Options:
   -64           Prepare or build for Mingw64 (default)
   -32           Prepare or build for Mingw32
   --slim        Remove Cairo, SVG and TIFF support for a slimmer build
                 Remove also documentation files and other support files
                 from the dependencies file
   --with-X      Add requested feature in the dependencies and build
   --without-X   Remove requested feature in the dependencies and build

   X is any of the known features for emacs in Windows/Mingw:
     $all_features
EOF

}

function errcho ()
{
    echo $@ >&2
}


function full_dependency_list ()
{
    # Given a list of packages, print a list of all dependencies
    #
    # Input
    #  $1 = list of packages without dependencies
    #
    # Packages we do not want to distribute (spurious dependencies)
    local skip_pkgs="glib2"
    # Packages that have to be replaced by others for distribution
    local munge_pgks="
        s,$mingw_prefix-libwinpthread,$mingw_prefix-libwinpthread-git,g;
        s,$mingw_prefix-libtre,$mingw_prefix-libtre-git,g;"

    local packages=`for i in $packages; do echo $mingw_prefix-$i; done`
    local skip_pkgs=`for p in $skip_pkgs; do echo s,$mingw_prefix-$p,,g; done`

    local oldpackages=""
    local dependencies=""
    while test "$oldpackages" != "$packages" ; do
        oldpackages="$packages"
        dependencies=`pacman -Qii $oldpackages | grep Depends | sed -e 's,>=[^ ]*,,g;s,Depends[^:]*:,,g;s,None,,g;' -e "$skip_pkgs" -e "$munge_pgks"`
        packages=`echo $oldpackages $dependencies | sed -e 's, ,\n,g' | sort | uniq`
    done
    echo $packages
}

function emacs_dependencies ()
{
    # Print the list of all mingw/msys packages required for running emacs with
    # the selected features. Cache the result value.
    #
    if test -z "$emacs_dependencies"; then
        errcho Inspecting required packages for build features
        errcho   $features
        local feature_selector=`echo $features | sed -e 's, ,|,g'`
        local packages=`feature_list | grep -E "$feature_selector" | cut -d ' ' -f 2-`
        emacs_dependencies=`full_dependency_list $packages`
        errcho Total packages required:
        errcho   `echo $emacs_dependencies | sed -e 's, ,\n,g' -`
    fi
    echo $emacs_dependencies
}

function prepare_source_dir ()
{
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

function configure_build_dir ()
{
    cd "$build_dir"
    options="--without-compress-install --without-dbus"
    for f in $all_features; do
        if echo $features | grep f > /dev/null; then
            options="--with-$f $options"
        else
            options="--without-$f $options"
        fi
    done
    echo Configuring Emacs with options
    echo   $options
    if "$source_dir/configure" "--prefix=$install_dir" $options >$log_file 2>&1; then
        echo Emacs configured
    else
        echo Configuration failed
        return -1
    fi
}

function action0_clone ()
{
    # Download the Emacs source files using Git.
    #
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
        echo Cloning Emacs repository from Savannah at $emacs_repo.
        git clone --depth 1 -b $branch "$emacs_repo" "$source_dir" && \
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

function action1_ensure_packages ()
{
    # Collect the list of packages required for running Emacs, and ensure they
    # have been installed.
    #
    echo Ensuring packages are installed
    if pacman -Qi `emacs_dependencies` >/dev/null; then
        echo All packages are installed.
    else
        echo Some packages are missing. Installing them with pacman.
        pacman -S --noconfirm -q `emacs_dependencies`
    fi
}

function action2_build ()
{
    if prepare_source_dir && prepare_build_dir && configure_build_dir; then
        echo Building Emacs in directory $build_dir
        echo Log file is saved into $log_file
        if make -j 4 -C $build_dir $build_dir >>$log_file 2>&1; then
            echo Installing Emacs into directory $install_dir
            if make -j 4 -C $build_dir install >>$log_file 2>&1; then
                echo Process succeeded
                return 0
            fi
        fi
    fi
    echo Configuration and build process failed
    echo Please check log file $log_file
    return -1
}

function action3_package_deps ()
{
    # Collect the list of packages required for running Emacs, gather the files
    # from those packages and compress them into $emacs_depsfile
    #
    rm -f "$emacs_depsfile"
    mkdir -p `dirname "$emacs_depsfile"`
    cd $mingw_dir
    pacman -Ql `emacs_dependencies` | cut -d ' ' -f 2 | sort | uniq \
        | sed "s,^$mingw_dir,,g" | dependency_filter | xargs zip -9 "$emacs_depsfile"
}

function action4_package ()
{
    # Package a prebuilt emacs with and without the required dependencies, ready
    # for distribution.
    #
    if test ! -f $emacs_depsfile; then
        echo Missing dependency file $emacs_depsfile. Run with --deps first.
    fi
    rm -f "$install_dir/bin/emacs-*.exe"
    strip "$install_dir/bin/*.exe" "$install_dir/libexec/emacs/*/*/*.exe"
    rm -f "$emacs_nodepsfile"
    mkdir -p `dirname "$emacs_nodepsfile"`
    cd "$install_dir"
    if zip -9vr "$emacs_nodepsfile" *; then
        echo Built $emacs_nodepsfile; echo
    else
        echo Failed to compress distribution file $emacs_nodepsfile; echo
        return -1
    fi
    cp $emacs_depsfile $emacs_distfile
    cd "$install_dir"
    if zip -9vr "$emacs_distfile" *; then
        echo Built $emacs_distfile; echo
    else
        echo Failed to compress distribution file $emacs_distfile; echo
        return -1
    fi
}

function feature_list () {
    cat <<EOF
xpm xpm-nox
jpeg libjpeg-turbo
tiff libtiff
gif giflib
png libpng
rsvg librsvg
cairo cairo
harfbuzz harfbuzz
json jansson
lcms2 lcms2
xml2 libxml2
gnutls gnutls
zlib zlib
EOF

}

function delete_feature () {
    features=`echo $features | sed -e "s,$1,,"`
}

function add_feature () {
    features=`echo $features $1 | sort | uniq`
}

function dependency_filter () {
    if test -z "$dependency_exclusions"; then
        cat -
    else
        grep -E -v "^(`echo $slim_exclusions | sed 's, ,|,g'`)" -
    fi
}

slim_exclusions="
include/
lib/.*.a
lib/cmake
lib/gettext/intl
lib/pkgconfig
lib/python3.8
share/aclocal
share/doc/gettext
share/doc/libasprintf
share/doc/libiconv
share/doc/libjpeg-turbo
share/doc/libunistring
share/doc/libxml2
share/doc/mpfr
share/doc/tiff
share/doc/xz
share/gettext/intl
share/gtk-doc/html/libxml2
share/man/man3
share/man/man5
"
dependency_exclusions=""
all_features=`feature_list | cut -f 1 -d ' '`
features="$all_features"
branches=""
architectures=""
actions=""
while test -n "$*"; do
    case $1 in
        -64) architectures="$architectures x86_64";;
        -32) architectures="$architectures i686";;
        --branch) shift; branches="$branches $1";;
        --without-*) delete_feature `echo $1 | sed -e 's,--without-,,'`;;
        --with-*) add_feature `echo $1 | sed -e 's,--without-,,'`;;
        --slim)
            delete_feature cairo
            delete_feature rsvg
            delete_feature tiff
            dependency_exclusions="$slim_exclusions"
            ;;
        --clone) actions="$actions action0_clone";;
        --ensure) actions="$actions action1_ensure_packages";;
        --build) actions="$actions action2_build";;
        --deps) actions="$actions action3_package_deps";;
        --package) actions="$actions action4_package";;
        --help) write_help; exit 0;;
    esac
    shift
done
if test -z $architectures; then
    architectures="x86_64"
fi
if test -z "$branches"; then
    branches="emacs-27"
fi
actions=`for a in $actions; do echo $a; done|sort`
if test -z "$actions"; then
    actions="action0_clone action1_ensure_packages action2_build action3_package_deps action4_package"
fi
features=`for f in $features; do echo $f; done | sort | uniq`

emacs_repo=https://git.savannah.gnu.org/git/emacs.git
for branch in $branches; do
    for architecture in $architectures; do
        mingw_prefix="mingw-w64-x86_64"
        mingw_dir="/mingw64/"
        if test $architecture = i686; then
            mingw_prefix="mingw-w64-i686"
            mignw_dir="/mingw32/"
        fi
        emacs_nodepsfile="`pwd`/zips/emacs-${branch}-${architecture}-nodeps.zip"
        emacs_depsfile="`pwd`/zips/emacs-${branch}-${architecture}-deps.zip"
        emacs_distfile="`pwd`/zips/emacs-${branch}-${architecture}-full.zip"
        emacs_dependencies=""
        for action in $actions; do
            source_dir="`pwd`/git/$branch"
            build_dir="`pwd`/build/$branch-$architecture"
            install_dir="`pwd`/pkg/$branch-$architecture"
            log_file="${build_dir}.log"
            if $action ; then
                echo Action $action succeeded.
            else
                echo Action $action failed.
                echo Aborting builds for branch $branch and architecture $architecture
                break
            fi
        done
    done
done
