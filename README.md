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

## Notes

Set `ZK_NOTEBOOK_DIR` to the root of a [zk](https://github.com/zk-org/zk) notebook before you start an agent. The jail
then binds the notebook read-write, forwards the variable, and binds `~/.config/zk` read-only. The `zk` command is on
the `PATH` of both agents. When `ZK_NOTEBOOK_DIR` is not set, the jail binds no notebook. A missing directory stops the
jail.

Tell the agent about the notebook in your own `~/.claude/CLAUDE.md` or `~/.config/opencode/AGENTS.md`, because the jail
gives the agent only the variable.

Without a flake of your own, run `nix run github:GetThru/agent-jail#claude-code`.
