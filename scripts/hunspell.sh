function action3_hunspell ()
{
    hunspell_link="https://sourceforge.net/projects/ezwinports/files/hunspell-1.3.2-3-w32-bin.zip"
    hunspell_zip_file="$emacs_build_zip_dir/hunspell.zip"

    if test -f "$hunspell_zip_file"; then
        echo File $hunspell_zip_file already exists.
    else
        curl -L "$hunspell_link" > $hunspell_zip_file
        if test "$?" != 0; then
            echo Unable to download Hunspell from
            echo "  $hunspell_link"
            return -1
        fi
    fi
    emacs_extensions="$hunspell_zip_file $emacs_extensions"
}
