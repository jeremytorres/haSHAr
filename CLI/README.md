#CLI Build Target#

##Overview##
The Command Line Interface was the first incarnation of haSHAr.  It was originally designed as a command-line tool to allow for execution via a scheduled job (e.g., CRON job).  However, I'v decided to also create a GUI app.

##Build Requirements##
- Mac OSX 10.7 "Lion"
- XCode 4

Note: Lion is a requirement, as haSHAr is using specific Grand Central Dispatch APIs only provided in 10.7+

##Usage##
1. Select the _CLI_ build target in XCode4
2. Build the _CLI_ target
3. Locate the _CLI_ executable
4. Open _Terminal.app_ and change to the directory containing the _CLI_ executable
5. For Help, just execute the _CLI_ executable; it will display a list of required command-line switches

###Example###
The following example would verify all .NEF files in the directory, processing up to 5 files concurrently.

    ./CLI -m v -d /Volumes/Photo/tmp/raw_files -e NEF -n 5

> where

>> m = _mode

>> d = _directory_

>> e = _file extension(s)_

>> n = number of files to open and process _concurrently_






