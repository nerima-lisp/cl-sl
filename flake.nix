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
      extraOutputs = ctx: {
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

          # An sb-cover HTML coverage report for the library and CLI systems.
          # The entry point below runs the registered suite through
          # cl-weave's public coverage API and fails unless both expression
          # and branch coverage reach 100%. The excluded files contain
          # static art data, declarations, or process/terminal boundaries;
          # SB-COVER counts their literal/declaration forms as executable
          # expressions without representing runtime behavior.
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
               '("src/art-train-data.lisp"
                 "src/package.lisp"
                 "src/conditions.lisp"
                 "src/constants.lisp"
                 "src/state.lisp"
                 "src/terminal.lisp"
                 "src/cli-package.lisp"
                 "src/cli-entry-point.lisp"))
            '';
            name = "cl-sl-coverage";
            timeoutSeconds = 900;
          };
        };
      };
    };
}
