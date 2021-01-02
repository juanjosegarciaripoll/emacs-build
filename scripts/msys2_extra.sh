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
# MU + XAPIAN + ISYNC
#
# Mail synchronization and mail indexing
#

function msys2_extra_environment ()
{
    msys2_extra_repo="https://github.com/msys2-unofficial/MSYS2-packages.git"
    msys2_extra_source_dir="$emacs_build_git_dir/MSYS2-packages"
}

function action3_mu ()
{
    local mu_zip_file="$emacs_build_zip_dir/mu-${architecture}.zip"
    msys2_extra_environment
    ensure_msys2_devel \
        && msys2_extra_clone \
        && msys2_extra_build_and_install_package gmime3 \
        && msys2_extra_build_and_install_package xapian-core \
        && msys2_extra_build_and_install_package mu \
        && emacs_extensions="$mu_zip_file $emacs_extensions" \
        && msys2_extra_package mu-git "/" "glib2 xapian-core gmime3" "$mu_zip_file"
}

function test_mu ()
{
    local mu="$emacs_full_install_dir/usr/bin/mu.exe"
    test -x "$mu" \
         && "$mu" --help | grep "mu general options" >/dev/null 2>&1
}

function action3_isync ()
{
    local isync_zip_file="$emacs_build_zip_dir/isync-${architecture}.zip"
    msys2_extra_environment
    ensure_msys2_devel \
        && msys2_extra_clone \
        && msys2_extra_build_and_install_package isync \
        && emacs_extensions="$isync_zip_file $emacs_extensions" \
        && msys2_extra_package isync-git "/" "gcc-libs ca-certificates" "$isync_zip_file" "$isync_zip_file"
}

function test_isync ()
{
    local mbsync="$emacs_full_install_dir/usr/bin/mbsync.exe"
    test -x "$mbsync" \
         && "$mbsync" --help | grep "mailbox synchronizer" >/dev/null 2>&1
}

function ensure_msys2_devel ()
{
    local required_packages="base-devel msys2-devel"
    pacman -S --noconfirm --needed $required_packages >/dev/null 2>&1
    if test "$?" != 0; then
        echo Unable to install MSYS2 packages $required_packages
        echo Giving up
        return -1
    fi
}

function msys2_makepkg ()
{
    $SHELL -c "source shell msys; makepkg $* EMACS=$emacs_install_dir/bin/emacs.exe"
}

function msys2_extra_build_and_install_package ()
{
    #set -x
    local package_name="$1"
    local package_dir="$msys2_extra_source_dir/$package_name"
    local package_file=`ls "${package_dir}/"*.zst 2>/dev/null`
    if test ! -f "$emacs_install_dir/bin/emacs.exe"; then
        echo Please build and package Emacs before the extensions
        exit -1
    fi
    if test ! -f "$package_file"; then
        echo Building package $package_dir on directory $package_dir
        (cd "$package_dir" && rm -f *.zst && msys2_makepkg --noconfirm -rsf -p PKGBUILD)
        if test "$?" != 0; then
            echo Unable to build package. Aborting.
            return -1
        fi
        package_file=`ls "${package_dir}/"*.zst`
    fi
    if test -f "$package_file" && pacman -U --noconfirm "$package_file"; then
        echo Installed $package_name
        return 0
    else
        echo Failed to build and install package $package_name
        return -1
    fi
}

function msys2_extra_package ()
{
    local base="$1"
    local prefix="$2"
    local dependencies="$3"
    local zip_file="$4"
    # List all dependencies
    local all_dependencies=`full_dependency_list "$base $dependencies gcc-libs" "sh coreutils" "$base" "msys2-no-prefix"`
    echo Packaging $base and dependencies into $zip_file
    (mingw_dir="$prefix"; package_dependencies "$zip_file" "$all_dependencies") \
        && zip -9r "$zip_file" /etc/fstab
}

function msys2_extra_clone ()
{
    echo Cloning repository $msys2_extra_repo
    clone_repo "master" "$msys2_extra_repo" "$msys2_extra_source_dir" \
        && (cd "$msys2_extra_source_dir" && git reset --hard && git checkout . ) \
        && msys2_extra_mu_pkg_description \
        && msys2_extra_gmime3_pkg_description \
        && msys2_extra_xapian_pkg_description \
        && msys2_extra_isync_pkg_description

}

function msys2_build_isync ()
{
    cd "$msys2_extra_source_dir/isync" \
        && makepkg -sf
}

function msys2_extra_mu_pkg_description ()
{
    cat > "$msys2_extra_source_dir/mu/PKGBUILD" <<\EOF
# Maintainer: damon-kwok <damon-kwok@outlook.com>
# Modification by Juan Jose Garcia Ripoll to fix dependencies

_realname=mu
# _date="`date +%Y-%m-%d@%H-%M-%S`"
pkgname=${_realname}-git #-${_date}
pkgver=20201202
pkgrel=1
pkgdesc="'mu' is a tool for dealing with e-mail messages stored in the Maildir-format."
arch=('i686' 'x86_64')
groups=('net-utils')
license=('GPL-3.0')
url="https://www.djcbsoftware.nl/code/mu/"
# depends=(xapian-core libiconv libguile guile gmp libgc libcrypt)
# makedepends=(git glib2-devel libiconv-devel libguile-devel gmp-devel libgc-devel libcrypt-devel xapian-core gmime3)
depends=(glib2 xapian-core libiconv )
makedepends=(git glib2-devel libiconv-devel xapian-core gmime3 diffutils)
source=("git+https://github.com/djcb/mu")
sha256sums=('SKIP')

pkgver() {
  cd "${srcdir}"/${_realname}
  # printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
  git log -1 --format="%cd" --date=short | sed 's|-||g'
}

build() {
    cd "${srcdir}"/${_realname}
    if grep '^AX_LIB_READLINE' configure.ac; then
       patch -p1 < ../../mu-readline.patch
    fi
    if test -f Makefile; then
       make distclean
    fi
    chmod +x ./autogen.sh
    echo Using EMACS=$EMACS
    ./autogen.sh --disable-gtk --disable-webkit --disable-guile --disable-readline
    make
}

package() {
    cd "${srcdir}"/${_realname}
    make DESTDIR="${pkgdir}" install
    install -Dm644 COPYING "${pkgdir}"/usr/share/licenses/${pkgname}/LICENSE
}

EOF
    cat > "$msys2_extra_source_dir/mu/mu-readline.patch" <<\EOF
diff --git a/configure.ac b/configure.ac
index 9d8ebf2f..cbeb2e19 100644
--- a/configure.ac
+++ b/configure.ac
@@ -246,10 +246,13 @@ AM_COND_IF([BUILD_GUILE],[AC_DEFINE(BUILD_GUILE,[1], [Do we support Guile?])])

 ###############################################################################
 # optional readline
-saved_libs=$LIBS
-AX_LIB_READLINE
-AC_SUBST(READLINE_LIBS,${LIBS})
-LIBS=$saved_libs
+AC_ARG_ENABLE([readline], AS_HELP_STRING([--disable-readline],[Disable readline]))
+AS_IF([test "x$enable_readline" != "xno"], [
+  saved_libs=$LIBS
+  AX_LIB_READLINE
+  AC_SUBST(READLINE_LIBS,${LIBS})
+  LIBS=$saved_libs
+])
 ###############################################################################

 ###############################################################################
EOF
}

function msys2_extra_gmime3_pkg_description ()
{
    cat > "$msys2_extra_source_dir/gmime3/PKGBUILD" <<\EOF
# Maintainer: damon-kwok <damon-kwok@outlook.com>

pkgname=gmime3
pkgver=3.2.7
pkgrel=1
pkgdesc="The GMime package contains a set of utilities for parsing and creating messages using the Multipurpose Internet Mail Extension (MIME) as defined by the applicable RFCs."
arch=('i686' 'x86_64')
groups=('libraries')
license=('GPL')
url="https://github.com/jstedfast/gmime"
depends=(glib2 libiconv zlib libgpg-error)
makedepends=(gcc gcc-libs make libtool autoconf automake pkg-config glib2-devel libiconv-devel zlib-devel libgpg-error-devel)
provides=(libgmime-3.0.so)
source=(http://ftp.gnome.org/pub/gnome/sources/gmime/3.2/gmime-${pkgver}.tar.xz)
sha256sums=('2aea96647a468ba2160a64e17c6dc6afe674ed9ac86070624a3f584c10737d44')

# depends=(glib2 gpgme zlib libidn2)
# makedepends=(gobject-introspection gtk-doc git vala docbook-utils)
# provides=(libgmime-3.0.so)
# _commit=6546ed5e2935e5f99e99e0311ea6cec6d6101aaf  # tags/3.2.6^0
# source=("git+https://github.com/jstedfast/gmime#commit=$_commit")
# sha256sums=('SKIP')


build() {
    cd "gmime-${pkgver}"
    patch -p0 < ../../install.patch
    autoreconf --install -f --verbose
    ./configure --prefix=/usr --disable-static --enable-shared
    make
}

package() {
    cd "${srcdir}/gmime-${pkgver}"
    make DESTDIR="${pkgdir}" install
    install -Dm644 COPYING "${pkgdir}"/usr/share/licenses/${pkgname}/LICENSE
}
EOF

}

function msys2_extra_xapian_pkg_description ()
{
    cat > "$msys2_extra_source_dir/xapian-core/PKGBUILD" <<\EOF
# Maintainer: damon-kwok <damon-kwok@outlook.com>

pkgname=xapian-core
# epoch=1
pkgver=1.4.15
pkgrel=1
pkgdesc='Open source search engine library.'
arch=('i686' 'x86_64')
url='https://www.xapian.org/'
license=('GPL')
depends=('libutil-linux' zlib)
makedepends=(gcc gcc-libs make libtool autoconf automake 'libutil-linux-devel' 'zlib-devel')
# xapian config requires libxapian.la
options=('libtool')
source=("https://oligarchy.co.uk/xapian/${pkgver}/${pkgname}-${pkgver}.tar.xz")
#{,.asc})
sha512sums=('f28209acae12a42a345382668f7f7da7a2ce5a08362d0e2af63c9f94cb2adca95366499a7afa0bd9008fbfcca4fd1f2c9221e594fc2a2c740f5899e9f03ecad3')

# 1.4.14 sha512sums=('c08c9abe87e08491566b7cfa8cda9e2a80e4959a647428b6d82bce7af1c967b4cb463607ffb8976372a980c163923ced36117a66e0b5a1f35659393def3d371b')
            # 'SKIP')
# validpgpkeys=('08E2400FF7FE8FEDE3ACB52818147B073BAD2B07') # Olly Betts <olly@debian.org>

build() {
    cd ${pkgname}-${pkgver}
    autoreconf --install -f --verbose
    ./configure --prefix=/usr --disable-dependency-tracking
    make
}

package() {
    cd ${pkgname}-${pkgver}
    make DESTDIR="${pkgdir}" install
}
EOF

}


function msys2_extra_isync_pkg_description ()
{
    cat > "$msys2_extra_source_dir/isync/PKGBUILD" <<\EOF
# Maintainer: damon-kwok <damon-kwok@outlook.com>

_realname=isync
# _date="`date +%Y-%m-%d`"
pkgname=${_realname}-git #-${_date}
pkgver=20200804
pkgrel=1
pkgdesc="isync is a command line application which synchronizes mailboxes."
arch=('i686' 'x86_64')
groups=('net-utils')
license=('GPL-2.0')
url="http://isync.sourceforge.net/"
depends=('openssl' 'libsasl' 'zlib' 'libdb')
makedepends=('openssl-devel' 'libsasl-devel' 'zlib-devel' 'libdb')
source=("git+https://git.code.sf.net/p/isync/isync")
sha256sums=('SKIP')

pkgver() {
  cd "${srcdir}"/${_realname}
  # printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
  git log -1 --format="%cd" --date=short | sed 's|-||g'
}

build() {
    cd "${srcdir}"/${_realname}
    chmod +x ./autogen.sh
    ./autogen.sh
     ./configure --prefix=/usr
    make
}

package() {
    cd "${srcdir}"/${_realname}
    make DESTDIR="${pkgdir}" install
    install -Dm644 COPYING "${pkgdir}"/usr/share/licenses/${pkgname}/LICENSE
}
EOF

}
