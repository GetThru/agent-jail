{
  description = "Claude Code and opencode in a bubblewrap jail";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    {
      nixpkgs,
      jail-nix,
      llm-agents,
      ...
    }:
    let
      # llm-agents.nix builds for these three systems only.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      mkAgents = import ./agents.nix { inherit jail-nix llm-agents; };
    in
    {
      lib = { inherit mkAgents; };

      packages = forAllSystems (
        pkgs:
        let
          agents = mkAgents { inherit pkgs; };
        in
        {
          inherit (agents) claude-code opencode;
          default = agents.claude-code;
        }
      );
    };
}
