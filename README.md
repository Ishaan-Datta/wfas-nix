# wfas-nix

Nix package and NixOS service module for the CLI portion of **WiFiAudioStreaming-Desktop**.

This package intentionally targets the headless `wfas` CLI rather than the Compose desktop GUI.

Currently supported:

* `x86_64-linux`
* Nix package / flake
* NixOS systemd service
* Offline Gradle dependency builds

## Usage

Run the CLI directly:

```sh
nix run .
```

For example:

```sh
nix run . -- --server --persist --no-mute-render
```

Build the package:

```sh
nix build
./result/bin/wfas --help
```

## NixOS module

Add the flake as an input and import its default NixOS module:

```nix
{
  inputs,
  ...
}:

{
  imports = [
    inputs.wfas.nixosModules.default
  ];

  services.wfas = {
    enable = true;
    args = [
      "--server"
      "--persist"
      "--no-mute-render"
    ];
    debug = false;
  };
}
```

The package defaults to the WFAS revision pinned by this flake.

## Updating

```bash
# Move the pinned WFAS master commit forward
nix flake update wfas-src

# Refresh Gradle dependencies if upstream changed them
nix run .#update-deps

# Verify the new pinned commit builds
nix build

# Test the CLI
./result/bin/wfas --version
./result/bin/wfas --help
```
