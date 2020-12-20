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

. scripts/tools.sh
. scripts/pdf-tools.sh
. scripts/hunspell.sh

function write_help () {
    cat <<EOF
Usage:

   ./emacs-build.sh [-64] [-32] [--branch b]
                    [--clone] [--build] [--deps] [--pack-emacs] [--pack-all]
                    [--without-X] [--with-X]
                    [--pdf-tools]

Actions:

   --clean       Remove all directories except sources and zip files
   --clone       Download Savannah's git repository for Emacs
   --build       Configure and build Emacs from sources
   --deps        Create a ZIP file with all the Mingw64/32 dependencies
   --pack-emacs  Package an Emacs previously built with the --build option
   --pack-all    Package an Emacs previously built, with all the Mingw64/32
                 dependencies, as well as all extensions (see Extensions below)

   Multiple actions can be selected. The default is to run them all in a logical
   order: clone, build, deps and pack-all.

Emacs options:
   -64           Prepare or build for Mingw64 (default)
   -32           Prepare or build for Mingw32
   --branch b    Select branch 'b' for the remaining operations
   --slim        Remove Cairo, SVG and TIFF support for a slimmer build
                 Remove also documentation files and other support files
                 from the dependencies file
   --with-X      Add requested feature in the dependencies and build
   --without-X   Remove requested feature in the dependencies and build

   X is any of the known features for emacs in Windows/Mingw:
     `echo $all_features | sed -e 's,\n, ,g'`

Extensions:

   --pdf-tools   Build and package PDF-TOOLS
   --hunspell    Include Eli Zaretskii's port of Hunspell

EOF

}

function check_mingw_architecture ()
{
    mingw_prefix="mingw-w64-x86_64"
    mingw_dir="/mingw64/"
    if test $architecture = i686; then
        if test "$MSYSTEM" = MINGW32; then
            mingw_prefix="mingw-w64-i686"
            mignw_dir="/mingw32/"
        else
            # We should fix this by relaunching the script on a
            # different environment
            echo Cannot build 32-bit architecture on a 64-bit MINGW prompt
            echo
            exit -1
        fi
    elif test "$MSYSTEM" = MINGW32; then
        # We should fix this by relaunching the script on a
        # different environment
        echo Cannot build a 64-bit architecture on a 32-bit MINGW prompt
        echo
        exit -1
    fi
}

function emacs_root_packages ()
{
    local feature_selector=`echo $features | sed -e 's, ,|,g'`
    feature_list | grep -E "$feature_selector" | cut -d ' ' -f 2-
}

function emacs_dependencies ()
{
    # Print the list of all mingw/msys packages required for running emacs with
    # the selected features. Cache the result value.
    #
    if test -z "$emacs_dependencies"; then
        errcho Inspecting required packages for build features
        errcho   $features
        local packages=`emacs_root_packages`
        emacs_dependencies=`full_dependency_list "$packages" "glib2" "Emacs"`
        errcho Total packages required:
        for p in $emacs_dependencies; do
            errcho "  $p"
        done
    fi
    echo $emacs_dependencies
}

function emacs_configure_build_dir ()
{
    cd "$emacs_build_dir"
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
    if "$emacs_source_dir/configure" "--prefix=$emacs_install_dir" $options >$log_file 2>&1; then
        echo Emacs configured
    else
        echo Configuration failed
        return -1
    fi
}

function action0_clean ()
{
    rm -rf "$emacs_build_build_dir" "$emacs_build_install_dir"
}

function action0_clone ()
{
    clone_repo "$branch" "$emacs_repo" "$emacs_source_dir"
}

function action1_ensure_packages ()
{
    # Collect the list of packages required for running Emacs, and ensure they
    # have been installed.
    #
    ensure_packages `emacs_dependencies`
}

function action2_build ()
{
    action1_ensure_packages
    if prepare_source_dir $emacs_source_dir \
            && prepare_build_dir $emacs_build_dir && emacs_configure_build_dir; then
        echo Building Emacs in directory $emacs_build_dir
        echo Log file is saved into $log_file
        if make -j 4 -C $emacs_build_dir >>$log_file 2>&1; then
            echo Installing Emacs into directory $emacs_install_dir
            if make -j 4 -C $emacs_build_dir install >>$log_file 2>&1; then
                echo Process succeeded
                return 0
            fi
        fi
    fi
    echo Configuration and build process failed
    echo Please check log file $log_file
    return -1
}

function install_emacs ()
{
    rm -rf "$emacs_install_dir"
    mkdir -p "$emacs_install_dir"
    echo Installing Emacs into directory $emacs_install_dir
    make -j 4 -C $emacs_build_dir install >>$log_file 2>&1
}

function action3_package_deps ()
{
    # Collect the list of packages required for running Emacs, gather the files
    # from those packages and compress them into $emacs_depsfile
    #
    package_dependencies "$emacs_depsfile" "`emacs_dependencies`"
}

function action4_package_emacs ()
{
    # Package a prebuilt emacs with and without the required dependencies, ready
    # for distribution.
    #
    if test ! -f $emacs_depsfile; then
        echo Missing dependency file $emacs_depsfile. Run with --deps first.
        return -1
    fi
    if install_emacs; then
        rm -f "$emacs_install_dir/bin/emacs-*.exe"
        strip "$emacs_install_dir/bin/*.exe" "$emacs_install_dir/libexec/emacs/*/*/*.exe"
        rm -f "$emacs_nodepsfile"
        mkdir -p `dirname "$emacs_nodepsfile"`
        cd "$emacs_install_dir"
        if zip -9vr "$emacs_nodepsfile" *; then
            echo Built $emacs_nodepsfile; echo
        else
            echo Failed to compress distribution file $emacs_nodepsfile; echo
            return -1
        fi
    else
        echo Failed to install Emacs
        return -1
    fi
}

function action5_package_all ()
{
    for zipfile in "$emacs_depsfile" $emacs_extensions; do
        if test ! -f "$zipfile"; then
            echo Missing zip file `basename $zipfile.` Cannot build full distribution.
            echo Please use --deps and --build before --full.
            echo
            return -1
        fi
    done
    if install_emacs; then
        cd "$emacs_install_dir"
        for zipfile in "$emacs_depsfile" $emacs_extensions; do
            echo Unzipping $zipfile
            if unzip -ox $zipfile >> $log_file; then
                echo Done!;
            else
                echo Failed to unzip $zipfile
                return -1
            fi
        done
        find "$emacs_install_dir" -type f -a -name *.exe -o -name *.dll | xargs strip
        find . -type f | sort | dependency_filter | xargs zip -9vr "$emacs_distfile" >> $log_file
    else
        echo Failed to install Emacs
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
lib/python*
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
do_clean=""
debug_dependency_list="false"
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
        --clean) actions="action0_clean $actions";;
        --clone) actions="$actions action0_clone";;
        --ensure) actions="$actions action1_ensure_packages";;
        --build) actions="$actions action2_build";;
        --deps) actions="$actions action3_package_deps";;
        --pack-emacs) actions="$actions action4_package_emacs";;
        --pack-all) actions="$actions action5_package_all";;
        --pdf-tools) actions="$actions action3_pdf_tools";;
        --debug-dependencies) debug_dependency_list="true";;
        --hunspell) actions="$actions action3_hunspell";;
        --help) write_help; exit 0;;
        *) echo Unknown option "$1". Aborting; exit -1;;
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
    actions="action0_clone action2_build action3_package_deps action5_package_all"
fi
features=`for f in $features; do echo $f; done | sort | uniq`

emacs_repo=https://git.savannah.gnu.org/git/emacs.git
emacs_build_root=`pwd`
emacs_build_git_dir="$emacs_build_root/git"
emacs_build_build_dir="$emacs_build_root/build"
emacs_build_install_dir="$emacs_build_root/pkg"
emacs_build_zip_dir="$emacs_build_root/zips"
for architecture in $architectures; do
    check_mingw_architecture
    for branch in $branches; do
        emacs_extensions=""
        emacs_nodepsfile="`pwd`/zips/emacs-${branch}-${architecture}-nodeps.zip"
        emacs_depsfile="`pwd`/zips/emacs-${branch}-${architecture}-deps.zip"
        emacs_distfile="`pwd`/zips/emacs-${branch}-${architecture}-full.zip"
        emacs_dependencies=""
        for action in $actions; do
            emacs_source_dir="$emacs_build_git_dir/$branch"
            emacs_build_dir="$emacs_build_build_dir/$branch-$architecture"
            emacs_install_dir="$emacs_build_install_dir/$branch-$architecture"
            log_file="${emacs_build_dir}.log"
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
