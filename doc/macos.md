Extra setup instructions for MacOS
==

You must have Xcode and CLT installed for Mac to run make setup.

If you're having trouble with the nodejs setup, check out
[this guide](node-setup.md).

You must also have bash version 4.0 or higher. To make this your default shell:
1. Run `brew install bash` or `brew upgrade bash`
2. Go to `/etc/shells` and add `usr/local/bin/bash`
3. Run `chsh -s /usr/local/bin/bash`
4. Close your shell and reopen. To check your bash version, run
    `bash --version`.

Furthermore, some of the scripts (notably `lang-stat`) use `grep -P`.
This flag is not available in MacOS. To solve this problem:
1. Run `brew install grep`
2. Make MacOS run the installed version of grep with:
   `export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"`
