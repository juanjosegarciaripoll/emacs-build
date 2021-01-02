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
# PDF-TOOLS
#
# Extra components to build and configure PDF-TOOLS in MSYS2/Mingw64
#

function action3_pdf_tools ()
{
    local pdf_tools_repo="https://github.com/politza/pdf-tools"
    local pdf_tools_branch="master"
    local pdf_tools_packages="${mingw_prefix}-poppler ${mingw_prefix}-glib2"

    local pdf_tools_source_dir="$emacs_build_git_dir/pdf-tools"
    local pdf_tools_server_dir="$pdf_tools_source_dir/server"
    local pdf_tools_build_dir="$emacs_build_build_dir/pdf-tools-$architecture"
    local pdf_tools_install_dir="$emacs_build_install_dir/pdf-tools-$architecture"
    local pdf_tools_zip_file="$emacs_build_zip_dir/pdf-tools-${architecture}.zip"
    local pdf_tools_skip_packages="${mingw_prefix}-python ${mingw_prefix}-tk ${mingw_prefix}-tcl"

    pdf_tools_dependencies=""

    if test -f $pdf_tools_zip_file; then
        echo File $pdf_tools_zip_file already exists. Refusing to rebuild.
        return 0
    fi

    pdf_tools_ensure_packages \
        && pdf_tools_clone \
        && prepare_source_dir "$pdf_tools_server_dir" \
        && rm -rf "$pdf_tools_build_dir" \
        && prepare_build_dir "$pdf_tools_build_dir" \
        && pdf_tools_configure \
        && pdf_tools_build \
        && pdf_tools_install \
        && pdf_tools_package \
        && emacs_extensions="$pdf_tools_zip_file $emacs_extensions"
}

function pdf_tools_ensure_packages ()
{
    ensure_packages `pdf_tools_dependencies`
}

function pdf_tools_clone ()
{
    clone_repo $pdf_tools_branch $pdf_tools_repo $pdf_tools_source_dir
    if test "$?" = 0; then
        echo Prepping the PDF-TOOLS server for running
        cd $pdf_tools_server_dir
        ./autogen.sh
    fi
    return $?
}

function pdf_tools_dependencies ()
{
    # Print the list of all mingw/msys packages required for running emacs with
    # the selected features. Cache the result value.
    #
    if test -z "$pdf_tools_dependencies"; then
        errcho "Inspecting required packages for PDF-TOOLS: $pdf_tools_packages"
        local pdf_tools_all_dependencies=`full_dependency_list "$pdf_tools_packages" "$pdf_tools_skip_packages" "pdf-tools"`
        local emacs_all_dependencies=`emacs_dependencies`
        pdf_tools_dependencies=`elements_not_in_list "$pdf_tools_all_dependencies" "$emacs_all_dependencies"`
        errcho Total packages required:
        errcho   `echo $pdf_tools_dependencies | sed -e 's, ,\n,g' -`
    fi
    echo $pdf_tools_dependencies
}

function pdf_tools_configure ()
{
    cd $pdf_tools_build_dir && "$pdf_tools_server_dir/configure" "--prefix=$pdf_tools_install_dir"
}

function pdf_tools_build ()
{
    echo Building PDF-TOOLS into directory $pdf_tools_build_dir
    make -C $pdf_tools_build_dir
}

function pdf_tools_byte_compile ()
{
    local lispdir="$pdf_tools_install_dir/share/emacs/site-lisp/"
    cd $lispdir
    $emacs_install_dir/bin/emacs -Q -batch -L . -f batch-byte-compile *.el || echo Failed
}

function pdf_tools_install ()
{
    local lispdir="$pdf_tools_install_dir/share/emacs/site-lisp/pdf-tools"
    local bindir="$pdf_tools_install_dir/bin"
    local docdir="$pdf_tools_install_dir/share/doc/pdf-tools"
    echo Installing PDF-TOOLS into directory $pdf_tools_install_dir
    mkdir -p $bindir  $lispdir $docdir \
        && cp $pdf_tools_source_dir/{README*,COPYING*,NEWS} $docdir/ \
        && cp -rf $pdf_tools_source_dir/lisp/* $lispdir \
        && cp $pdf_tools_build_dir/epdfinfo.exe $bindir
}

function pdf_tools_package ()
{
    package_dependencies "$pdf_tools_zip_file" "`pdf_tools_dependencies`" \
        && cd "$pdf_tools_install_dir" \
        && zip -9r "$pdf_tools_zip_file" *
}


function test_epdfinfo ()
{
    local empty_page="$emacs_build_root/tmp/empty.pdf"
    local epdfinfo="$emacs_full_install_dir/bin/epdfinfo.exe"
    test -x $epdfinfo \
        && mkdir -p `dirname "$empty_page"` \
        && pdf_tools_empty_page > "$empty_page" \
        && (echo renderpage:$empty_page:1:100; echo quit) | $epdfinfo >/dev/null 2>&1
}

function pdf_tools_empty_page ()
{
    cat <<\EOF
%PDF-1.0\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 3 3]>>endobj\nxref\n0 4\n000000000065535 f\n0000000010 00000 n\n0000000053 00000 n\n0000000102 00000 n\ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n149\n%EOF
EOF
}
