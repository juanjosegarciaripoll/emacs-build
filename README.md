# emacs-build

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
- Eventually, the script should be able to build other components I regularly
  use, such as mu, mu4e or pdf-tools.

## Usage

````
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

   X is any of the known features for emacs in Windows/Mingw (png, gif, etc)

Extensions:

   --pdf-tools   Build and package PDF-TOOLS
   --hunspell    Include Eli Zaretskii's port of Hunspell
````

## What this does

Assume you invoke this script as follows
````
./emacs-build.sh --slim --clone --ensure --build --deps --pdf-tools --hunspell --pack-all
````

It will take care of the following tasks

1. Clone the latest emacs repository on the branch emacs-27
2. Ensure that all required packages Mingw64 are installed, or install them.
3. Configure and build Emacs using those packages
4. Pack all the dependencies into a ZIP file.
5. Download and build pdf-tools, hunspell or other extensions mentioned above. In the process, ensure that the required packages are also installed.
6. Create a ZIP file with Emacs, all the dependencies and all the extensions.

The script, just like its creator, is a bit opinionated. It performs takes some extra steps to reduce the size of the distribution

- It eliminates the manual pages and large documentation files for the libraries
  that are used by Emacs.
- It eliminates the library files (*.a).
- It strips the executable files and DLL's from debugging information.
