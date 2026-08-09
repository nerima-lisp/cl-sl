{
  description = "An original ASCII-art steam locomotive that runs across the terminal.";

  inputs = {
    # nixos-unstable, not nixpkgs-unstable: it advances only after the NixOS
    # release tests pass, so it is less likely to land a broken build.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # The org flake preset. The single `mkPackageFlake` call below generates
    # this repository's entire required-output table, so none of it is
    # spelled out here and none of it can drift from the other repositories.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Sibling packages are ALWAYS pinned to a release tag; a bare
    # `github:nerima-lisp/<pkg>` follows that repo's default branch, which
    # would break this repo's CI without warning the moment upstream pushes
    # to main. `flake = false`: only the source tree is needed (to build a
    # `lispDerivation` below), never these repos' own flake outputs -- see
    # docs/src/project/development.md for the dependency policy.
    cl-tty-kit = {
      url = "github:nerima-lisp/cl-tty-kit/v1.5.0";
      flake = false;
    };

    cl-cli = {
      url = "github:nerima-lisp/cl-cli/v1.3.0";
      flake = false;
    };

    # Transitive sibling dependencies of the two above -- cl-tty-kit.asd
    # depends on cl-codec-kit, cl-cli.asd depends on cl-host-kit. Nix builds
    # each lispDerivation as its own sandboxed derivation, so cl-tty-kit's and
    # cl-cli's OWN :depends-on must be satisfied by giving THEIR
    # lispDerivation calls a lispDependencies list (see `lispDependencies`
    # below) -- flattening every sibling into this repository's own list
    # would not reach a nested build. See the dependency policy in
    # docs/src/project/development.md.
    cl-codec-kit = {
      url = "github:nerima-lisp/cl-codec-kit/v0.5.0";
      flake = false;
    };

    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.3.1";
      flake = false;
    };

    cl-boundary-kit = {
      url = "github:nerima-lisp/cl-boundary-kit/v2.3.0";
      flake = false;
    };

    cl-date-kit = {
      url = "github:nerima-lisp/cl-date-kit/v1.0.0";
      flake = false;
    };

    cl-concurrent-kit = {
      url = "github:nerima-lisp/cl-concurrent-kit/v0.6.1";
      flake = false;
    };

    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.3.0";
      flake = false;
    };

    # Unlike the sibling *packages* above, this is consumed for its `lib`
    # output (`mkLintCheck`), which a `flake = false` source tree cannot
    # provide -- the same reason cl-cli keeps it a real flake input.
    #
    # v1.5.0 publishes the lint library for the development and CI systems
    # declared below.
    paredit-cli = {
      url = "github:nerima-lisp/paredit-cli/v1.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-nix-forge,
      cl-tty-kit,
      cl-cli,
      cl-boundary-kit,
      cl-codec-kit,
      cl-concurrent-kit,
      cl-date-kit,
      cl-host-kit,
      cl-weave,
      paredit-cli,
      treefmt-nix,
    }:
    let
      # x86_64-linux is what CI gates; aarch64-darwin is the development
      # machine. Every per-system output -- packages, checks, apps AND devShells
      # -- comes from this one list, so leaving aarch64-darwin out takes `nix
      # build` and `nix develop` off the development machine as well. See
      # docs/src/reference/architecture.md for the supported system boundary.
      # aarch64-linux and x86_64-darwin are nobody's verification and are not
      # declared.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    cl-nix-forge.lib.${builtins.head systems}.mkPackageFlake {
      inherit self systems nixpkgs;

      pname = "cl-sl";

      # Single source of truth for the version: the `:version` form in
      # cl-sl.asd.
      asd = ./cl-sl.asd;

      root = ./.;

      meta = {
        description = "An original ASCII-art steam locomotive that runs across the terminal.";
        homepage = "https://github.com/nerima-lisp/cl-sl";
        license = nixpkgs.lib.licenses.mit;
        platforms = nixpkgs.lib.platforms.unix;
        mainProgram = "cl-sl";
      };

      # Runtime dependency closure for both the core library and the separate
      # cl-sl/cli executable. These are BUILT DERIVATIONS, not
      # CL_SOURCE_REGISTRY strings -- cl-nix-forge assembles the registry
      # transitively from them. cl-cli is included here for the executable;
      # the core ASDF system itself depends only on cl-tty-kit.
      lispDependencies =
        ctx:
        let
          boundaryKit = ctx.cl.lispDerivation {
            pname = "cl-boundary-kit";
            version = ctx.cl.fromAsdSystem "${cl-boundary-kit}/cl-boundary-kit.asd";
            src = cl-boundary-kit;
            lispSystem = "cl-boundary-kit";
            lispDependencies = [ hostKit ];
          };
          dateKit = ctx.cl.lispDerivation {
            pname = "cl-date-kit";
            version = ctx.cl.fromAsdSystem "${cl-date-kit}/cl-date-kit.asd";
            src = cl-date-kit;
            lispSystem = "cl-date-kit";
          };
          concurrentKit = ctx.cl.lispDerivation {
            pname = "cl-concurrent-kit";
            version = ctx.cl.fromAsdSystem "${cl-concurrent-kit}/cl-concurrent-kit.asd";
            src = cl-concurrent-kit;
            lispSystem = "cl-concurrent-kit";
            lispDependencies = [
              boundaryKit
              dateKit
            ];
          };
          codecKit = ctx.cl.lispDerivation {
            pname = "cl-codec-kit";
            version = ctx.cl.fromAsdSystem "${cl-codec-kit}/cl-codec-kit.asd";
            src = cl-codec-kit;
            lispSystem = "cl-codec-kit";
          };
          hostKit = ctx.cl.lispDerivation {
            pname = "cl-host-kit";
            version = ctx.cl.fromAsdSystem "${cl-host-kit}/cl-host-kit.asd";
            src = cl-host-kit;
            lispSystem = "cl-host-kit";
          };
        in
        [
          (ctx.cl.lispDerivation {
            pname = "cl-tty-kit";
            version = ctx.cl.fromAsdSystem "${cl-tty-kit}/cl-tty-kit.asd";
            src = cl-tty-kit;
            lispSystem = "cl-tty-kit";
            lispDependencies = [
              codecKit
              concurrentKit
            ];
          })
          (ctx.cl.lispDerivation {
            pname = "cl-cli";
            version = ctx.cl.fromAsdSystem "${cl-cli}/cl-cli.asd";
            src = cl-cli;
            lispSystem = "cl-cli";
            lispDependencies = [ hostKit ];
          })
        ];

      # Test-only: cl-weave (the test framework) plus cl-tty-kit again, since
      # t/package.lisp imports cl-tty-kit:decode-input/make-screen/
      # make-renderer/tick-loop-run directly. cl-tty-kit is already a runtime
      # dependency above; ASDF's own :depends-on on cl-sl/test is what makes
      # it visible there too, this just gives the check derivation the same
      # tree.
      lispCheckDependencies = ctx: [
        (ctx.cl.lispDerivation {
          pname = "cl-weave";
          version = ctx.cl.fromAsdSystem "${cl-weave}/cl-weave.asd";
          src = cl-weave;
          lispSystem = "cl-weave";
        })
      ];

      # The delivered binary is owned by the separate CL-SL/CLI ASDF system.
      # installSource lets it find its installed source tree if ASDF needs to
      # re-resolve the system at runtime.
      executable = {
        installSource = true;
        lispSystem = "cl-sl/cli";
      };

      docs.root = ./docs;

      # ONE treefmt evaluation drives both `nix fmt` and `checks.formatting`.
      # Scope stays the preset's default of Nix only.
      treefmt.evalModule = treefmt-nix.lib.evalModule;

      # Granularity lives here, not in an extra GitHub Actions job: `nix flake
      # check` evaluates each attribute as its own derivation, in parallel,
      # with build caching -- see cl-cli's flake.nix, which this follows.
      extraOutputs =
        ctx:
        let
          inherit (ctx.pkgs) lib;

          # The library files sb-cover cannot meaningfully measure: static art
          # tables, declarations, and process/terminal boundaries, whose
          # literal and declaration forms it counts as executable expressions
          # without their standing for runtime behavior.
          #
          # Named once and consumed TWICE -- by the coverage entry point, and
          # by the docs-consistency gate, which asserts every entry still
          # names a file that exists. That second consumer is why this is a
          # binding rather than a literal inside `entryPointText`. A stale
          # entry left behind by a rename or a deletion silently WIDENS the
          # exclusion: the reported figure stays at 100% while the measured
          # surface shrinks, and nothing about the number says so.
          coverageExcludePathnames = [
            "src/art-train-data.lisp"
            "src/package.lisp"
            "src/conditions.lisp"
            "src/constants.lisp"
            "src/state.lisp"
            "src/terminal.lisp"
            "src/cli-package.lisp"
            "src/cli-entry-point.lisp"
          ];
        in
        {
          checks = {
            # Structural parse gate over every Lisp source in the filtered
            # tree: fails if any .lisp/.asd file is not a balanced S-expression
            # document. The test suite would not catch it -- an unbalanced file
            # makes ASDF fail to load the system, which reads like any other
            # build error and points at the wrong cause.
            paredit-lint = paredit-cli.lib.${ctx.system}.mkLintCheck {
              inherit (ctx) src;
              name = "cl-sl-paredit-lint";
            };

            # Documentation/implementation consistency. v0.1.0 shipped a
            # reference that documented eight symbols the package did not
            # export and omitted eighteen that it did, a default value that
            # disagreed with the code, and a provenance claim the source
            # contradicted. Nothing mechanical would have caught any of it: the
            # suite tests behavior, and prose is not behavior. This gate
            # compares the prose against the source directly.
            #
            # It cannot reuse `ctx.src`. `mkLispSource` is an ALLOWLIST of
            # `.asd`/`.lisp`, so the whole `docs/` tree and README.md are
            # absent from it by construction -- a check built on `ctx.src`
            # would find no markdown and pass vacuously. The fileset below is
            # this check's own, and stays narrow in the other direction too: a
            # docs edit must not invalidate the package build, nor a source
            # edit the docs build.
            #
            # `flake.nix` is deliberately NOT in that fileset, and the reason
            # is not oversight: the retired-term list this gate enforces is
            # itself written in this file, a few dozen lines below. Including
            # `flake.nix` in the scan makes the gate match its own vocabulary
            # and fail permanently, with a diagnostic pointing at the gate
            # rather than at any real defect. `cl-sl.asd` IS scanned -- the
            # over-claim about the art's provenance lived there, so the file
            # that caused the problem must not be the one left outside.
            #
            # `LICENSE` is deliberately NOT in that fileset either, and for a
            # different reason: it is the ONE place in the tree where the
            # upstream names are supposed to appear. The published git history
            # carries art transcribed from the upstream program, and satisfying
            # that program's license terms requires naming it and its author
            # verbatim. Scanning `LICENSE` would make the gate reject the very
            # attribution the license obliges us to keep. Nothing else may
            # write those names, which is why the exemption is a whole-file
            # exclusion here rather than a per-line escape hatch in the script:
            # a suppression mechanism inside the scanner would be reusable by
            # any file that wanted one.
            #
            # `src/*.lisp` IS scanned, by the fileset AND by the retired-term
            # pass below. The provenance claim about the art now lives in the
            # header comment of src/art-train-data.lisp, not in prose, so a
            # scan that stopped at markdown would pass an upstream art table
            # reintroduced under an honest attribution comment.
            #
            # RUNNING THIS: verify with `nix build 'path:.#checks...'`, not
            # `.#`. Nix excludes untracked files from a dirty git tree, so a
            # newly added `src/*.lisp` that architecture.md already documents
            # is invisible under `.#` and this gate reports it as missing --
            # a false positive whose cause is git, not the docs. Either use
            # `path:` or get the file tracked.
            docs-consistency =
              let
                checkSource = lib.fileset.toSource {
                  root = ./.;
                  fileset = lib.fileset.unions [
                    (lib.fileset.fileFilter (file: file.hasExt "md") ./docs)
                    (lib.fileset.fileFilter (file: file.hasExt "lisp") ./src)
                    ./README.md
                    ./cl-sl.asd
                  ];
                };

                # The exclusion list handed to the gate as data. A file rather
                # than a splice into the script, so the script does not become
                # a second copy of the list it is supposed to be checking.
                excludeManifest = ctx.pkgs.writeText "cl-sl-coverage-exclusions.txt" (
                  lib.concatLines coverageExcludePathnames
                );

                script = ctx.pkgs.writeText "cl-sl-docs-consistency.pl" ''
                  # Documentation/implementation consistency gate for cl-sl.
                  #
                  # Four independent comparisons, all run before any of them
                  # can fail the build, so one broken thing does not hide the
                  # next:
                  #
                  #   1. the :export clause of src/package.lisp against the
                  #      cl-sl: symbols written in docs/src/reference/api.md,
                  #      in BOTH directions;
                  #   2. the absence of the retired upstream-attribution
                  #      vocabulary from README.md, cl-sl.asd, every page under
                  #      docs/, AND every src/*.lisp -- the source headers are
                  #      where the provenance claim about the art actually
                  #      lives, so leaving them out let an honest-looking
                  #      attribution comment carry upstream art past the gate;
                  #   3. the src/*.lisp files
                  #      docs/src/reference/architecture.md enumerates against
                  #      the files that actually exist;
                  #   4. every entry of coverage-exclude-pathnames against the
                  #      files that actually exist.
                  #
                  # Every comparison asserts its own inputs are non-empty
                  # first. A set comparison between two empty sets passes, and
                  # a gate that passes because it read nothing is worse than no
                  # gate: it is a green light nobody re-examines.
                  use strict;
                  use warnings;
                  use File::Find;

                  $| = 1;

                  my $root = shift @ARGV;
                  my $exclude_manifest = shift @ARGV;
                  die "usage: docs-consistency.pl <source-root> <exclusion-manifest>\n"
                    unless defined $root && defined $exclude_manifest;

                  my $SYMBOL = qr/[A-Za-z0-9!?*+<>=\/-]+/;

                  my @failures;

                  sub fail {
                      push @failures, $_[0];
                  }

                  # A vacuity failure is not the same kind of thing as a
                  # consistency failure: it means the gate could not run, so
                  # reporting "no mismatches" would be a lie. It stops here.
                  sub bail {
                      print STDERR "VACUOUS INPUT: $_[0]\n";
                      print STDERR "The gate could not run against real input, so a pass would prove nothing.\n";
                      exit 2;
                  }

                  sub slurp {
                      my ($path) = @_;
                      open my $fh, '<', $path or bail("cannot read $path: $!");
                      local $/;
                      my $text = <$fh>;
                      close $fh;
                      return $text;
                  }

                  sub rel {
                      my ($path) = @_;
                      $path =~ s/\Q$root\E\/?//;
                      return $path;
                  }

                  # ------------------------------------------------- inputs

                  opendir my $dh, "$root/src" or bail("cannot open $root/src: $!");
                  my @src_lisp = sort grep { /\.lisp\z/ } readdir $dh;
                  closedir $dh;

                  bail("no .lisp files directly under src/") unless @src_lisp;
                  bail("src/ holds only " . scalar(@src_lisp) . " .lisp files; the system has never had fewer than 10")
                    if @src_lisp < 10;

                  # Every prose surface that makes claims about this code:
                  # the docs site, the README, and the .asd's own
                  # :description/:long-description, which is where the art
                  # provenance over-claim actually lived.
                  my @prose;
                  if (-d "$root/docs") {
                      find(
                          {
                              no_chdir => 1,
                              wanted   => sub {
                                  push @prose, $File::Find::name
                                    if -f $File::Find::name && /\.md\z/;
                              },
                          },
                          "$root/docs"
                      );
                  }
                  push @prose, "$root/README.md"  if -f "$root/README.md";
                  push @prose, "$root/cl-sl.asd"  if -f "$root/cl-sl.asd";
                  @prose = sort @prose;

                  bail("no prose files found: no markdown under docs/, no README.md, no cl-sl.asd") unless @prose;
                  bail("only " . scalar(@prose) . " prose files found; docs/ alone has never had fewer than 5")
                    if @prose < 5;
                  bail("README.md is absent from the checked source") unless -f "$root/README.md";
                  bail("cl-sl.asd is absent from the checked source") unless -f "$root/cl-sl.asd";

                  # The retired-vocabulary pass (2) runs over a WIDER set than
                  # the prose: every src/*.lisp as well. A provenance claim is
                  # not confined to prose -- the one this project actually
                  # makes is a header comment in src/art-train-data.lisp -- and
                  # a scan that reads only markdown would wave through an
                  # upstream art table reintroduced with a truthful credit
                  # comment above it. Comparison (1) still reads only
                  # package.lisp and (3) only architecture.md; this widening is
                  # local to (2).
                  my @vocabulary_scan = (@prose, map { "$root/src/$_" } @src_lisp);

                  # The assertion that the src half is genuinely covered is NOT
                  # made here, against this list. It is made after the scan
                  # loop, against a tally the loop itself increments -- see
                  # `$scanned_src` below. Asserting on the list would describe
                  # the surface the gate INTENDED to read, and this exact gate
                  # has already been wrong about that once: the version being
                  # fixed built a perfectly good file list and then iterated a
                  # narrower one. A counter printed from the list would have
                  # reported the wide number either way, so it could not have
                  # revealed the defect -- it would have corroborated it.
                  my @exclusions = grep { length } split /\n/, slurp($exclude_manifest);

                  bail("the coverage exclusion manifest is empty") unless @exclusions;
                  for my $entry (@exclusions) {
                      bail("coverage exclusion entry is not a src/*.lisp pathname: $entry")
                        unless $entry =~ m{\Asrc/[A-Za-z0-9_+.-]+\.lisp\z};
                  }

                  print "scanned: "
                    . scalar(@src_lisp)
                    . " src/*.lisp, "
                    . scalar(@prose)
                    . " prose files, "
                    . scalar(@exclusions)
                    . " coverage exclusions\n";

                  # ----------------------- (1) exported symbols vs. api.md

                  my $pkg_path = "$root/src/package.lisp";
                  bail("src/package.lisp is absent") unless -f $pkg_path;

                  my $pkg = slurp($pkg_path);
                  # Line comments first: the :export clause is annotated, and a
                  # stray parenthesis inside a comment would derail the balance
                  # scan below.
                  $pkg =~ s/;[^\n]*//g;

                  my $start = index($pkg, '(:export');
                  bail("src/package.lisp has no (:export clause") if $start < 0;

                  my ($depth, $end) = (0, undef);
                  for (my $i = $start ; $i < length($pkg) ; $i++) {
                      my $c = substr($pkg, $i, 1);
                      $depth++ if $c eq '(';
                      if ($c eq ')') {
                          $depth--;
                          if ($depth == 0) {
                              $end = $i;
                              last;
                          }
                      }
                  }
                  bail("src/package.lisp: the (:export clause never closes") unless defined $end;

                  my $export_clause = substr($pkg, $start, $end - $start + 1);

                  my %exported;
                  $exported{ lc $1 } = 1 while $export_clause =~ /#:($SYMBOL)/g;

                  bail("src/package.lisp: the (:export clause names no symbols") unless keys %exported;
                  bail("src/package.lisp exports only "
                        . scalar(keys %exported)
                        . " symbols; the public API has never been smaller than 20")
                    if keys %exported < 20;

                  my $api_path = "$root/docs/src/reference/api.md";
                  bail("docs/src/reference/api.md is absent") unless -f $api_path;

                  my $api = slurp($api_path);
                  my %documented;
                  $documented{ lc $1 } = 1 while $api =~ /\bcl-sl:($SYMBOL)/g;

                  bail("docs/src/reference/api.md mentions no cl-sl: symbol at all") unless keys %documented;

                  print "exported symbols: "
                    . scalar(keys %exported)
                    . ", api.md cl-sl: symbols: "
                    . scalar(keys %documented) . "\n";

                  for my $sym (sort keys %exported) {
                      fail("exported but undocumented: cl-sl:$sym is in src/package.lisp :export, "
                            . "absent from docs/src/reference/api.md")
                        unless $documented{$sym};
                  }
                  for my $sym (sort keys %documented) {
                      fail("documented but not exported: docs/src/reference/api.md writes cl-sl:$sym, "
                            . "absent from src/package.lisp :export")
                        unless $exported{$sym};
                  }

                  # ------------------------------- (2) retired vocabulary

                  # The art is original to this project, so any wording that
                  # credits or cites an upstream implementation is now a false
                  # statement about the code. Note that this very list is why
                  # flake.nix is not among the scanned files -- see the
                  # comment on the check above. LICENSE is not scanned either,
                  # and for the opposite reason: it is where these names are
                  # REQUIRED.
                  #
                  # `sl\.c`, `toyoda` and `mtoyoda` are proper nouns: nothing
                  # this project can legitimately say contains any of them. They
                  # are still WORD-BOUNDED, for a reason that has nothing to do
                  # with the `canonical` problem below. Bare `sl\.c` matches
                  # inside `cl-sl.core` -- an SBCL core image, a phrase a Lisp
                  # project has every reason to write -- and bare `toyoda`
                  # matches inside longer tokens. Bounding `toyoda` does lose
                  # the address form `mtoyoda@acm.org`, since the `m` kills the
                  # leading boundary, which is exactly why `mtoyoda` is listed
                  # separately rather than folded in: it is the one place where
                  # dropping the boundary would silently drop coverage.
                  #
                  # `original sl` earns its place for the reverse reason to
                  # `canonical`. It is not a word that might be misread as a
                  # claim; it IS a claim, and one no phrasing of this project
                  # can honestly make -- for its own art, this project is the
                  # original. `sl\b` keeps it off `slide`, `slot` and `cl-sl`.
                  #
                  # `canonical` is different in kind, and the difference is why
                  # a word boundary is NOT the fix. \bcanonical\b matches "the
                  # canonical form of a path" exactly as the bare substring
                  # does: the false positive here is a whole ordinary English
                  # word, not a substring collision, so bounding it changes
                  # nothing. Left as-is the gate fails permanently the first
                  # time any page uses the word in its ordinary sense, with a
                  # diagnostic that reads as a provenance violation and sends
                  # the reader hunting for a defect that does not exist.
                  #
                  # What makes the word a provenance claim is the noun it
                  # qualifies, so it is matched only in the attribution
                  # phrases: an authoritative implementation elsewhere
                  # ("the canonical sl", "canonical upstream"), or this
                  # project's art credited to one ("canonical art", "canonical
                  # steam locomotive glyphs"). Ordinary technical usage --
                  # canonical form, canonical path, canonical ordering,
                  # canonical bundled short flags -- is left alone, because a
                  # gate that fires on correct prose gets disabled rather than
                  # obeyed.
                  #
                  # Each pattern carries the reason it exists, printed with any
                  # match. A diagnostic naming only the regex forces the reader
                  # to reconstruct the rule from the gate's source.
                  my @retired = (
                      [
                          'mtoyoda',
                          'is the upstream author email address. It belongs in LICENSE, which this gate deliberately does not scan, and nowhere else'
                      ],
                      [
                          '\btoyoda\b',
                          'credits the upstream author, whose work this project reuses none of'
                      ],
                      [
                          '\bsl\.c\b',
                          'names the upstream program, which this project derives nothing from'
                      ],
                      [
                          '\boriginal\s+sl\b',
                          'places the original implementation elsewhere. For its own art this project IS the original, so the phrase can only be a provenance claim'
                      ],
                      [
                          'canonical\s+(?:sl\b|upstream|original)',
                          'places the authoritative implementation outside this project. The bare word "canonical" is allowed -- only this attribution phrase is not'
                      ],
                      [
                          'canonical\s+(?:\S+\s+){0,2}(?:art|artwork|glyphs?)\b',
                          'credits the art to an authoritative source outside this project. The bare word "canonical" is allowed -- only this attribution phrase is not'
                      ],
                  );

                  my ($scanned_files, $scanned_src, $scanned_lines) = (0, 0, 0);

                  for my $file (@vocabulary_scan) {
                      my @lines = split /\n/, slurp($file), -1;
                      $scanned_files++;
                      $scanned_src++ if $file =~ m{/src/[^/]+\.lisp\z};
                      $scanned_lines += scalar(@lines);
                      for my $n (0 .. $#lines) {
                          for my $entry (@retired) {
                              my ($pat, $why) = @$entry;
                              next unless $lines[$n] =~ /$pat/i;
                              fail(sprintf("retired term /%s/i at %s:%d -- %s\n      %s",
                                           $pat, rel($file), $n + 1, $why, $lines[$n]));
                          }
                      }
                  }

                  print "retired-vocabulary scan: read $scanned_files files "
                    . "($scanned_src of them src/*.lisp), $scanned_lines lines, "
                    . scalar(@retired)
                    . " patterns\n";

                  # Asserted against the loop's own tally, not against the list
                  # the loop was handed. Every src/*.lisp must have been read:
                  # the src half is where the provenance claim lives, and the
                  # prose half alone clears any threshold on the total, so a
                  # combined count cannot detect the src half going missing.
                  bail("the retired-vocabulary scan read no src/*.lisp file at all")
                    unless $scanned_src;
                  bail("the retired-vocabulary scan read $scanned_src src/*.lisp files, fewer than the "
                        . scalar(@src_lisp)
                        . " present under src/")
                    if $scanned_src < @src_lisp;
                  bail("the retired-vocabulary scan read $scanned_files files, fewer than the "
                        . scalar(@vocabulary_scan)
                        . " it was given")
                    if $scanned_files < @vocabulary_scan;
                  bail("the retired-vocabulary scan matched no patterns because the list is empty")
                    unless @retired;

                  # --------------- (3) architecture.md vs. the real src tree

                  my $arch_path = "$root/docs/src/reference/architecture.md";
                  bail("docs/src/reference/architecture.md is absent") unless -f $arch_path;

                  my $arch = slurp($arch_path);
                  my %listed;
                  $listed{$1} = 1 while $arch =~ m{\bsrc/([A-Za-z0-9_+.-]*\.lisp)}g;

                  bail("docs/src/reference/architecture.md names no src/*.lisp file") unless keys %listed;

                  print "architecture.md lists " . scalar(keys %listed) . " src/*.lisp files\n";

                  my %present = map { $_ => 1 } @src_lisp;

                  for my $file (sort keys %listed) {
                      fail("architecture.md documents src/$file, which does not exist") unless $present{$file};
                  }
                  for my $file (@src_lisp) {
                      fail("src/$file exists but architecture.md does not document it") unless $listed{$file};
                  }

                  # ------------ (4) coverage exclusions vs. the real src tree

                  # Only this direction is meaningful. An entry naming a file
                  # that no longer exists silently widens the exclusion, and
                  # the coverage percentage does not move when it happens. The
                  # converse -- a src file absent from the list -- is just an
                  # ordinary measured file.
                  for my $entry (@exclusions) {
                      my $name = $entry;
                      $name =~ s{\Asrc/}{};
                      fail("coverage-exclude-pathnames lists $entry, which does not exist; "
                            . "the exclusion is dead and the measured surface is narrower than it looks")
                        unless $present{$name};
                  }

                  # ------- (5) the originality declaration must still exist

                  # Comparisons (1) through (4) are all denylist-shaped: they
                  # catch a false claim being ADDED. None of them catches the
                  # true claim being REMOVED, and "delete the header, restore
                  # the upstream tables" is the cheaper route back to the exact
                  # defect this gate exists to prevent -- it leaves behind no
                  # vocabulary for a substring scan to find. A pure denylist is
                  # silent on it. So this comparison is the other shape: the
                  # declaration is REQUIRED to be present.
                  #
                  # This assertion is worded-specific, and unlike the retired
                  # list that brittleness is a FEATURE rather than the bug
                  # fixed above. The two fail in different blast radii. A
                  # denylist false positive fires on innocent prose written
                  # anywhere in the tree, at any time, by someone with no
                  # reason to suspect a gate exists. This one can fire only
                  # when somebody edits this one file header -- and at that
                  # moment "confirm the originality claim survived your edit"
                  # is precisely the review that ought to happen. The failure
                  # message names the remedy so a legitimate rewording costs a
                  # minute, not an investigation.
                  #
                  # Note what this can and cannot establish. It verifies a
                  # claim of originality is PRESENT, not that it is TRUE -- no
                  # regex reads art tables. Its value is that it closes the
                  # quiet path: upstream art can no longer arrive alongside a
                  # deleted claim, and the retired list already blocks it
                  # arriving alongside an honest credit. Both routes now leave
                  # a red build.
                  my $art_path = "$root/src/art-train-data.lisp";
                  bail("src/art-train-data.lisp is absent; it is the file whose provenance this gate exists to protect")
                    unless -f $art_path;

                  my @art_lines = split /\n/, slurp($art_path), -1;
                  bail("src/art-train-data.lisp is empty") unless @art_lines;

                  my $art_head_lines = @art_lines < 40 ? scalar(@art_lines) : 40;
                  my $art_head = join "\n", @art_lines[ 0 .. $art_head_lines - 1 ];

                  bail("src/art-train-data.lisp: the first $art_head_lines lines are blank")
                    unless $art_head =~ /\S/;

                  print "originality declaration: checking the first "
                    . $art_head_lines
                    . " lines of src/art-train-data.lisp\n";

                  fail("src/art-train-data.lisp no longer CLAIMS the art is this project's own work. "
                        . "Expected the header to match /drawn for cl-sl/i within the first "
                        . "$art_head_lines lines. If you reworded the declaration, update this pattern "
                        . "in flake.nix; if you removed it, put it back -- the art provenance is the "
                        . "one claim this gate exists to protect, and a denylist cannot notice its absence")
                    unless $art_head =~ /drawn\s+for\s+cl-sl/i;

                  fail("src/art-train-data.lisp no longer DISCLAIMS transcription from another program. "
                        . "Expected the header to match /transcribed/i within the first "
                        . "$art_head_lines lines, as in \"Nothing here is transcribed from another "
                        . "program art tables\". Same remedy as above")
                    unless $art_head =~ /\btranscribed\b/i;

                  # --------------------------------------------- verdict

                  if (@failures) {
                      print STDERR "\ndocs/implementation consistency: " . scalar(@failures) . " mismatch(es)\n\n";
                      print STDERR "  - $_\n" for @failures;
                      print STDERR "\n";
                      exit 1;
                  }

                  print "docs/implementation consistency: no mismatches\n";
                  exit 0;
                '';
              in
              ctx.pkgs.runCommand "cl-sl-docs-consistency" { } ''
                ${ctx.pkgs.perl}/bin/perl ${script} ${checkSource} ${excludeManifest}
                touch "$out"
              '';

            # An sb-cover HTML coverage report for the library and CLI systems.
            # The entry point below runs the registered suite through
            # cl-weave's public coverage API and fails unless both expression
            # and branch coverage reach 100%. The excluded files contain
            # static art data, declarations, or process/terminal boundaries;
            # SB-COVER counts their literal/declaration forms as executable
            # expressions without representing runtime behavior. The list
            # itself is `coverageExcludePathnames` above, spliced in here so
            # the docs-consistency gate can check the same entries this
            # entry point acts on rather than a second copy of them.
            coverage = ctx.cl.mkCoverageReport {
              drv = ctx.package;
              systems = [
                "cl-sl"
                "cl-sl/cli"
              ];
              entryPointText = ''
                (require "asdf")
                (pushnew :cl-sl-coverage *features*)
                (asdf:load-system "cl-sl/test")
                (uiop:symbol-call
                 :cl-sl/test
                 :run-tests
                 :coverage-minimum-expression 100
                 :coverage-minimum-branch 100
                 :coverage-exclude-pathnames
                 '(${lib.concatMapStringsSep "\n   " (p: "\"" + p + "\"") coverageExcludePathnames}))
              '';
              name = "cl-sl-coverage";
              timeoutSeconds = 900;
            };
          };
        };
    };
}
