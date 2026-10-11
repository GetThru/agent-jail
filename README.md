agent-jail
==========

This flake runs Claude Code and opencode in a [jail.nix](https://git.sr.ht/~alexdavid/jail.nix) bubblewrap jail. The
jail mounts the current directory, the network, the git and `gh` config, and the state directories of each agent. On
macOS, the flake gives the agents without a jail.

## Usage

```nix
{
  inputs.agent-jail.url = "github:GetThru/agent-jail";
  inputs.agent-jail.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixpkgs, agent-jail, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      agents = agent-jail.lib.mkAgents {
        inherit pkgs;
        extraPkgs = [ pkgs.nodejs_22 ];
        extraJailOptions = c: [ (c.try-fwd-env "MIX_HOME") ];
      };
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = [ agents.claude-code agents.opencode ];
      };
    };
}
```

## Options of `mkAgents`

- `pkgs`: the package set. It is required.
- `extraPkgs`: the packages to add to the `PATH` of both agents. The default is `[ ]`.
- `extraJailOptions`: a function from the jail.nix combinators to a list of jail options for both agents. The default is
  `_: [ ]`.
- `claude-code`: the unjailed Claude Code package. The default comes from `llm-agents.nix`.
- `opencode`: the unjailed opencode package. The default comes from `llm-agents.nix`.

Without a flake of your own, run `nix run github:GetThru/agent-jail#claude-code`.
