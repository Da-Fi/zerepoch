{ pkgs, config, lib, tfinfo, ... }:
{
  imports = [
    ./std.nix
    ../../../nix/modules/pab.nix
  ];

  networking = {
    firewall.allowedTCPPorts = [ 22 80 9080 ];
  };

  services.pab = {
    enable = true;
    pab-setup = pkgs.zerepoch-pab.pab-exes.zerepoch-pab-setup;
    pab-executable = "${pkgs.simeon-pab}/bin/simeon-pab";
    staticContent = pkgs.simeon-dashboard.client;
    dbFile = "/var/lib/pab/pab-core.db";
    defaultWallet = 1;
    webserverPort = 9080;
    walletPort = 8081;
    nodePort = 8082;
    chainIndexPort = 8083;
    signingProcessPort = 8084;
    slotZeroTime = 1591566291000; # POSIX time of 2020-06-07T21:44:51Z (Sunday, June 7, 2020 21:44:51)
    slotLength = 1000; # In milliseconds
    constantFee = 10; # Constant fee per transaction in entropic
    scriptsFeeFactor = 1.0; # Factor by which to multiply the size-dependent scripts fee in entropic
  };

}
