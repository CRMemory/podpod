
#  Podpod - A command line podcast client

# License

Meh, haven't yet decided. As long as nothing else is stated: MIT-License

# Introduction 
Podpod is a simple podcast client for the command line. Its intended use is
for highly automated podcast processing. Podpod allows it to make
postprocessions steps during updating your podcasts. This will hopefully come
in very handy in connection with cron and similar stuff


Podpod seeks to be a replacement for Mashpodder which is no longer updated or
maintained. If there's a feature you'd like to see or an error you found, feel
free to drop me a message.

# Usage

You'll need two files:

* `podpod.conf` - Configuration file.
* `podcastList.txt` - List of podcast URLs to check

The latter one is set in the first one as variable `RSS_FILE`, see below.

## Configuration

The file `podpod.conf` is the central configuration file. It can provide
options to control how podcasts are downloaded. All possible options are
explained in the sample configuration filed.
You need to at least specify `RSS_FILE` the format of which is explained below

The file `podpod.conf` must be provided as parameter when calling `podpod.sh`.

    ./podpod.sh podpod.conf

If no configuration file is given, the default location ~/.podpod.conf will
be used. If not present processing stops.

## RSS file

This file (podpodList.txt in the example) specifies which podcasts should be
checked and in which way they should be downloaded.

The file contains one entry per line. Empty lines and lines starting with '#'
are not read. The general format for an entry entry is as follows:
    
    <title> <url> <mode>

where

- `title` - Title of the podcast, will be the name of the directory under
            `PODCAST_DIR`
- `url`   - Url to the xml of the podcast feed
- `mode`  - Either sim, all, latest or <n> (see below)

The possible modes are

- `sim`    - Simulate the download. This will log the according podcast as
             'was downloaded' but neither download something nor create a file.
             This basically keeps a log of all URLs of all files that could've
             been downloaded.
             Note that once an episode was 'was downloaded' it will not be
             checked again unless the according entry from the logfile is removed.
             Note that using the 'sim' mode also allows giving a number as argument.

- `all`    - Check and download all episodes/files that have not been acquired yet.

- `latest` - Check and download the latest episode only and don't check for any
             other. This is equivalent to setting the mode to the number 1

- `<n>`    - A non-negative integer value. Check and download the newest <n>
             episodes only. A value of 1 is equivalent to setting 'latest'

## Hooks

Hooks are small scripts that add further postprocessing. There are four kinds of
hooks enabled. A hook can be set by providing `--hook <type> <script>` as option
to `podpod.sh` (Later there will be the option to set these values in the config
directly)
Any number of hooks can be provided. If the same hook is present multiple times,
the last one provided will be used. If set in the config file and the command
line, the command line parameters are preferred.

- `start` - Executed before any podcasts are processed. No argument.
- `file`  - Executed after any file has been downloaded. Argument: Full path to
            the file just processed
- `cast`  - Executed after a podcast is finished. Argument: Full path to the
            directory corresponding to the finished podcast. Note that this means
- `end`   - Executed after all podcasts are processed. Argument: Full path to
            the podcast directory

# Ideas for the future aka ToDos
- LICENSE
- DELETE-OLD
  - Only if the podcast updated to the last <n> entries
  - Remove entries before the <n> entries
  - easy t.b. done 
- something with renaming xml things
  - e.g. custom sed commands for renaming (see for example the guardian file format and others)
- Create daily playlist of fresh casts
- LOG_LIMIT for the logfile in lines (default to something like 10k)
- TRY_INTERPRETATION
  - try interpretation of names and such
  - use itunes-tags if present (maybe also for renaming)
- Also allow settings Hooks via config script
- Set a default location to search for the config like ~/.podpod.conf or something alike
