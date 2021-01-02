function action3_aspell ()
{
    local aspell_zip_file="$emacs_build_zip_dir/aspell-${architecture}.zip"
    if test -f "$aspell_zip_file"; then
        echo File $aspell_zip_file already exists.
    else
        local packages="${mingw_prefix}-aspell ${mingw_prefix}-aspell-en"
        ensure_packages "$packages" \
            && msys2_extra_package "$packages" "$mingw_dir" "" "$aspell_zip_file" \
            && emacs_extensions="$aspell_zip_file $emacs_extensions" \
            && return 0
        return -1
    fi
}

function test_aspell ()
{
    local aspell="$emacs_full_install_dir/bin/aspell.exe"
    test -x "$aspell" \
         && "$aspell" dicts | grep en_US >/dev/null 2>&1
}
