hunspell_link="https://sourceforge.net/projects/ezwinports/files/hunspell-1.3.2-3-w32-bin.zip"
hunspell_zip_file="$emacs_build_zip_dir/hunspell.zip"

function action3_hunspell ()
{
    if curl -L "$hunspell_link" > $hunspell_zip_file; then
        emacs_extensions="$hunspell_zip_file $emacs_extensions"
        return 0
    else
        echo Unable to download Hunspell from
        echo "  $hunspell_link"
        return -1
    fi
}
