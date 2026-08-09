# Roadmap

v1.0.0 is the first release whose art and motion are entirely original to
this project, and it covers the behaviors the classic `sl` is known for: the
default run, `-a`/`--accident`, `-l`/`--little`, `-c`/`--c51`, `-F`/`--fly`,
`--fps`, `--help`/`--version`, and an early-quit `q` key for consistency with
the org's other real-time terminal programs. It also drops the collision
feature v0.1.0 carried, along with the public symbols that supported it --
see [Migrating to v1.0.0](migration-v1.md).

The public API is now settled, and the intent is to keep it that way: a
removal or rename after this point is a major-version change with a migration
note, not a patch.

Nothing further is currently planned; issues are welcome at
<https://github.com/nerima-lisp/cl-sl/issues>.
