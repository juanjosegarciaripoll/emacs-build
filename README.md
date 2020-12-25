# emacs-build v0.1

Scripts to build a distribution of Emacs from sources, using MSYS2 and Mingw64(32)

## Rationale

I wanted a script to build Emacs from sources, package it and install it on
different computers, with the following conditions

- I should be able to build any branch or release from Emacs. This includes
  the last release branch (right now emacs-27), as well as the master branch
  for development. Always using pristine sources from Savannah.
- I want to build emacs with different options from the default, which is to
  use all features available. For instance, I do not care for SVG support.
- The script needs to track all packages that are required by the Emacs build
  even if I change the build options.
- The installation should take as little space as possible, removing useless
  directories or files that come from the dependencies. For instance, headers
  from libraries used by emacs, spurious documentation files, etc.
- The script should be able to build other components I regularly use, such as
  mu, mu4e or pdf-tools, in a way that is not affected by updates to the mingw
  or msys environments.

## Usage

### Before running

1. Install MSYS/Mingw64 as explained [here](https://www.msys2.org/).
2. Open a Mingw64 terminal.
3. Install Git using `pacman -S git`.
4. Upgrade your system if this is not a fresh install.
5. Clone this repository somewhere in your home directory.
6. Enter the repository and use the command line tool as explained below.

### General instructions

````
Usage:

   ./emacs-build.sh [--branch b]
                    [--clone] [--build] [--deps] [--pack-emacs] [--pack-all]
                    [--without-X] [--with-X]
                    [--pdf-tools] [--hunspell] [--mu] [--isync]

Actions:

   --clean       Remove all directories except sources and zip files
   --clone       Download Savannah's git repository for Emacs
   --build       Configure and build Emacs from sources
   --deps        Create a ZIP file with all the Mingw64/32 dependencies
   --pack-emacs  Package an Emacs previously built with the --build option
   --pack-all    Package an Emacs previously built, with all the Mingw64/32
                 dependencies, as well as all extensions (see Extensions below)
   --version     Output emacs-build version number

   Multiple actions can be selected. The default is to run them all in a logical
   order: clone, build, deps and pack-all.

Emacs options:
   --branch b    Select branch 'b' for the remaining operations
   --slim        Remove Cairo, SVG and TIFF support for a slimmer build
                 Remove also documentation files and other support files
                 from the dependencies file
   --with-X      Add requested feature in the dependencies and build
   --without-X   Remove requested feature in the dependencies and build

   X is any of the known features for emacs in Windows/Mingw:
     xpm jpeg tiff gif png rsvg cairo harfbuzz json lcms2 xml2 gnutls zlib

Extensions:

   --pdf-tools   Build and package PDF-TOOLS
   --hunspell    Include Eli Zaretskii's port of Hunspell
   --mu          Mail search system and supporting Emacs mu4e libraries
   --isync       Synchronize email from IMAP/POP to Maildir format (mbsync)
````

### An example

Assume you invoke this script as follows
````
./emacs-build.sh --slim --clone --build --pdf-tools --hunspell --mu --isync --pack-all
````

It will take care of the following tasks

1. Clone the latest emacs repository on the branch emacs-27
2. Ensure that all required packages Mingw64 are installed, or install them.
3. Configure and build Emacs using those packages
4. Pack all the dependencies into a ZIP file.
5. Download and build pdf-tools, hunspell, mu and isync (plus xapian and gmime3). In the process, ensure that the required packages are also installed.
6. Create a ZIP file with Emacs, all the dependencies and all the extensions.

The script, just like its creator, is a bit opinionated. It performs takes some extra steps to reduce the size of the distribution

- It eliminates the manual pages and large documentation files for the libraries
  that are used by Emacs.
- It eliminates the library files (*.a).
- It strips the executable files and DLL's from debugging information.


### Considerations

Regarding versions:

- Upgrade your MSYS/Mingw installation with `pacman -Su` before running this script.
- After every upgrade, it is recommended to do a full clean (`--clean-all`) and
  rebuild. Otherwise different packages may be in an inconsistent state.

There are implicit dependencies in the various actions:

- `--clone` is required to get the sources
- `--deps` is assumed to be run before `--pack-all`

The tool produces zip files that are stored in `./zips` and can be uncompressed wherever you want:

- `emacs-xx-xxxx-deps.zips` is the file with optional libraries (png, jpeg,
  etc) used by Emacs.
- `emacs-xx-xxxx-nodeps.zip` is a bare Emacs installation. It runs even if the
  'deps' file is not used
- `emacs-xx-xxxx-full.zip` is a complete Emacs installation, with the optional
  libraries and all extensions (pdf-tools, mu, etc) you mentioned in the
  command line.
- `pdf-tools-xxxx.zip` and others are the Zip files for the extensions. They
  can be unpacked inside an Emacs installation, but may assume that 'deps' have
  also been unpacked.

Regarding the extensions to Emacs and third-party utilities:

- They can be built separately from Emacs.
- If `c:\emacs` is where you unpacked the full installation, some extensions
  will reside in `c:\emacs\bin` (e.g. pdftools) and some others in
  `c:\emacs\usr\bin` (e.g. mu and mbsync).
- Even though elisp files are provided, it is highly recommended that you
  install pdf-tools and mu4e from Melpa or other repositories, to properly take
  care of dependencies from other elisp libraries.


## TO-DO

- Consider GitHub actions for automated continuous integration and release
  system. References:
  - Setting up an MSYS/MINGW system https://github.com/marketplace/actions/setup-msys2
  - MINGW packages recipes https://github.com/msys2/MINGW-packages/blob/master/.github/workflows/main.yml
  - Uploading artifacts https://github.com/actions/upload-artifact
  - https://github.com/actions/create-release
