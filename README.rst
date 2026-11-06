Lint
====

**Lint** is a tool that runs linting checks on Nim modules. It checks a module's abstract syntax tree against rules expressed with Nim code and reports what it finds.

Thanks to its modular architecture, Lint allows you to *BYOL—bring your own linter*:
- you can write a standalone Nim module with your linting checks and ship it as part of your project
- or you can publish it as a Nimble package so that anyone could use in in their projects

Lint ships with an accompanying [GitHub action](./action.yml) to make it easy to include linting in the CI process.

Quickstart
----------

1. Install lint with nimble:

  .. code::

    $ nimble install lint

2. Write a linter config (see an example in `tests/linter.nim <tests/linter.nim>`_.

.. include:: ./tests/linter.nim
  :code:

.. note::
  Lint config is a compiled Nim file. This is a bit unorthodox as you usually see configs written in YAML, TOML, or JSON. However, using Nim for configuration allows Lint to employ user-provided linters: the compiled binary has all your checks baked in.

  Also, because it's regular Nim, you never get an incorrect config due to a typo and you can enjoy autocompletions while you edit it.

3. Compile and run your linter:

  .. code::

    $ nim c -d:release linter.nim
    $ ./linter                # lint entire project
    $ ./linter myfile.nim     # or a single file
    $ ./linter dir            # or a directory
    $ ./linter dir/s*.nim     # or a glob pattern

Full docs are at `iftech.github.io/nim-lint <https://iftech.github.io/nim-lint/>`_.

License
-------

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](./LICENSE-MIT) or <http://opensource.org/licenses/MIT>

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](./LICENSE-APACHEv2) or <http://www.apache.org/licenses/LICENSE-2.0>)

at your option. This file may not be copied, modified, or distributed except according to those terms.
