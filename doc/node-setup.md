How to set up Node.js and npm
==

This is a tutorial for Node beginners who need to install the
tree-sitter command-line interface (CLI).

Global vs. local packages
--

Node packages are installed with `npm`, the Node Package Manager.
The idiomatic way of developing with Node is to install a project's
dependencies locally, that is at the root folder of the project.
Only general-purpose development tools should be installed
globally. One such example is `npx`, a wrapper for locating
executables installed locally.

Summary:
* local install: `npm install tree-sitter-cli` installs the
  `tree-sitter-cli` package and its dependencies in `node_modules/`.
* global install: `npm install -g npx` installs the `npx` package and
  its dependencies in a shared location, which is configurable (see below).

Unprivileged global installs
--

It is recommend to install the global packages in your home folder
rather than a location requiring root privileges.

Set your `~/.npmrc` file to:

```
prefix = ~/.node
```

and add the following lines to your `~/.bashrc`:

```
# See also ~/.npmrc
export PATH="$HOME/.node/bin:$PATH"
export NODE_PATH="$HOME/.node/lib/node_modules:$NODE_PATH"
export MANPATH="$HOME/.node/share/man:$MANPATH"
```

Running executables installed by Node packages
--

Executables from local packages are installed in the project's
`node_modules/.bin`, which can be in a parent folder.

A convenient and clean way of calling executables installed by npm is
to use `npx`, which should be installed globally to be useful:

```
npm install -g npx
```

It will look for executables in the local `node_modules/.bin` and then
use the `PATH` variable, so it can be used to call any command e.g.

```
$ npx tree-sitter --version
tree-sitter 0.16.9 (12341dbbc03075e0b3bdcbf05191efbac78731fe)

$ npx whoami
martin
```

Exercise
--

Install the `tree-sitter` and `tree-sitter-cli` packages
locally. Predict the output of `npx which tree-sitter` when called
from inside and from outside your project. Check your predictions.
