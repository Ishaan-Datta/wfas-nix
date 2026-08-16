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

Add the flake as an input:

```nix
  inputs = {
    wfas.url = "github:Ishaan-Datta/wfas-nix";
  };
```

And import its default NixOS module:

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

## Binary cache

Pre-built packages are published to a Nix binary cache backed by GitHub Pages and GitHub Releases. Using the binary cache avoids rebuilding WFAS and its Gradle dependencies locally when a matching build is available.

### Flake configuration

Add the cache to your flake's `nixConfig`:

```nix
{
  nixConfig = {
    extra-substituters = [
      "https://ishaan-datta.github.io/wfas-nix/"
    ];

    extra-trusted-public-keys = [
      "wfas-nix-1:l/9zkf4IPGRlgOdd+Q1/mRrNgLiZ8Nnw89txoApBMbc="
    ];
  };
}
```

Nix may prompt you to accept these flake-provided configuration options the first time you use the flake.

### NixOS configuration

To configure the cache system-wide on NixOS:

```nix
{
  nix.settings = {
    extra-substituters = [
      "https://ishaan-datta.github.io/wfas-nix/"
    ];

    extra-trusted-public-keys = [
      "wfas-nix-1:l/9zkf4IPGRlgOdd+Q1/mRrNgLiZ8Nnw89txoApBMbc="
    ];
  };
}
```

After rebuilding your system, Nix will automatically use the cache whenever a matching store path is available. You can also test the cache without changing your system configuration:

```sh
nix build github:Ishaan-Datta/wfas-nix \
  --option extra-substituters https://ishaan-datta.github.io/wfas-nix/ \
  --option extra-trusted-public-keys \
    'wfas-nix-1:l/9zkf4IPGRlgOdd+Q1/mRrNgLiZ8Nnw89txoApBMbc='
```

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
