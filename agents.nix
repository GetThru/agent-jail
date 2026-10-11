{ jail-nix, llm-agents }:
{
  pkgs,
  # Packages on the PATH of both agents, on top of basePkgs below.
  extraPkgs ? [ ],
  # A function from jail.nix's combinators to a list of extra jail options for
  # both agents, so a consumer needs no jail-nix input of its own:
  #   extraJailOptions = c: [ (c.try-fwd-env "MIX_HOME") ];
  extraJailOptions ? _: [ ],
  claude-code ? llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code,
  opencode ? llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode,
}:
let
  jail = jail-nix.lib.init pkgs;
  c = jail.combinators;

  basePkgs = with pkgs; [
    bashInteractive
    curl
    wget
    jq
    git
    gh
    which
    ripgrep
    gnugrep
    gnused
    gawkInteractive
    openssh
    ps
    findutils
    gzip
    unzip
    gnutar
    diffutils
    neovim
    ncurses
  ];

  baseJailOptions = with c; [
    network
    time-zone
    mount-cwd
    (try-readwrite (noescape "~/.config/gh"))
    # jail.nix's `base` combinator mounts a tmpfs over $HOME, so git finds no
    # global config and a commit fails with "Committer identity unknown". Bind
    # the config read-only, because an agent has no reason to rewrite it.
    (try-readonly (noescape "~/.gitconfig"))
    # git resolves this path through $XDG_CONFIG_HOME. An unset variable names
    # "/git", which does not exist, so the bind does nothing.
    (try-fwd-env "XDG_CONFIG_HOME")
    (try-readonly (noescape "~/.config/git"))
    (unsafe-add-raw-args "--dev-bind /dev/tty /dev/tty")
    # npm installs a bin shim that opens with `#!/usr/bin/env node`, and bwrap
    # mounts no /usr, so every npx MCP server dies with "bad interpreter". Bind
    # the binary from the store, because a host without /usr/bin/env would
    # otherwise fail the whole jail.
    (unsafe-add-raw-args "--ro-bind ${pkgs.coreutils}/bin/env /usr/bin/env")
    # Without this bind, npx refetches every MCP server package on each launch.
    (try-readwrite (noescape "~/.npm"))
    (try-readwrite (noescape "~/.config/nvim"))
    (try-readwrite (noescape "~/.local/share/nvim"))
    (try-readwrite (noescape "~/.local/state/nvim"))
    (try-readwrite (noescape "~/.cache/nvim"))
    (set-env "EDITOR" "${pkgs.neovim}/bin/nvim")
    (set-env "VISUAL" "${pkgs.neovim}/bin/nvim")
    # bwrap mounts no /usr/lib/locale, so glibc falls back to the C locale.
    # `set-env` writes the path and does not mount it, so glibcLocales needs
    # its own entry.
    (set-env "LOCALE_ARCHIVE" "${pkgs.glibcLocales}/lib/locale/locale-archive")
    (set-env "LANG" "en_US.UTF-8")
    (add-pkg-deps [ pkgs.glibcLocales ])
    (add-pkg-deps basePkgs)
    (add-pkg-deps extraPkgs)
  ];

  # jail.nix's `readwrite` fails on a missing path, so the wrapper creates the
  # state paths of the agent before it enters the jail. The state paths hold
  # auth and history, so a `try-readwrite` that falls back to the tmpfs would
  # lose them.
  makeAgent =
    {
      name,
      package,
      stateDirs,
      stateFiles ? [ ],
    }:
    let
      jailed = jail name package (
        baseJailOptions
        ++ map (path: c.readwrite (c.noescape path)) (stateDirs ++ stateFiles)
        ++ extraJailOptions c
      );
      homePath = path: ''"$HOME/${pkgs.lib.removePrefix "~/" path}"'';
    in
    # bubblewrap is a Linux kernel feature, so macOS gets the agent unjailed.
    if pkgs.stdenv.isDarwin then
      package
    else
      pkgs.writeShellScriptBin name ''
        mkdir -p ${pkgs.lib.concatMapStringsSep " " homePath stateDirs}
        ${pkgs.lib.concatMapStrings (f: "[ -e ${homePath f} ] || echo '{}' > ${homePath f}\n") stateFiles}
        exec ${jailed}/bin/${name} "$@"
      '';
in
{
  claude-code = makeAgent {
    name = "claude";
    package = claude-code;
    stateDirs = [
      "~/.claude"
      "~/.local/share/claude"
      "~/.local/state/claude"
    ];
    stateFiles = [ "~/.claude.json" ];
  };

  opencode = makeAgent {
    name = "opencode";
    package = opencode;
    stateDirs = [
      "~/.config/opencode"
      "~/.local/share/opencode"
      "~/.local/state/opencode"
    ];
  };
}
