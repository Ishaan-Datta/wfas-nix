{
  config,
  lib,
  utils,
  ...
}:

let
  cfg = config.services.wfas;
  args = cfg.args ++ lib.optional cfg.debug "--debug";
in
{
  options.services.wfas = {
    enable = lib.mkEnableOption "WiFi Audio Streaming server";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The WFAS package to use.";
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;

      default = [
        "--server"
        "--persist"
        "--no-mute-render"
      ];

      example = [
        "--server"
        "--persist"
      ];

      description = ''
        Command-line arguments passed to WFAS.
      '';
    };

    debug = lib.mkEnableOption "WFAS debug logging";
  };

  config = lib.mkIf cfg.enable {
    systemd.services.wfas = {
      description = "WiFi Audio Streaming server";

      wantedBy = [
        "multi-user.target"
      ];

      after = [
        "network.target"
      ];

      serviceConfig = {
        Type = "simple";

        ExecStart = utils.escapeSystemdExecArgs ([ (lib.getExe cfg.package) ] ++ args);

        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
