# This file contains all values that do not need to be set at runtime. For example `env` must be a variable because you need to set the environment
# when you run terraform apply however despite `simeon_domain_name` depending on the value of `env`, it does not need to be set when you run
# terraform apply as it is an expression that is evaluated based on `env` etc.
locals {
  project = "zerepoch_playground"

  # By default domain names are structured by environment and type e.g. env.zerepoch.bcccoindev.io but we can override those e.g. prodzerepoch.bcccoin.io
  simeon_domain_name      = "${var.simeon_full_domain != "" ? var.simeon_full_domain : "${var.env}.${var.simeon_tld}"}"
  zerepoch_domain_name       = "${var.zerepoch_full_domain != "" ? var.zerepoch_full_domain : "${var.env}.${var.zerepoch_tld}"}"
  simeon_dash_domain_name = "${var.env}.${var.simeon_dash_tld}"
  simeon_web_domain_name  = "${var.env}.${var.simeon_web_tld}"

  simeon_web_port        = 8181
  zerepoch_playground_port  = 8080
  simeon_playground_port = 9080
  pab_port                = 9080

  # SSH Keys
  ssh_keys = {
    ci-deployer = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlPr/5Pbz8yf1j+1G6tOKacQSsX4A9w4SM7MvXij21V deployer@ci"
    pablo       = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCeNj/ZQL+nynseTe42O4G5rs4WqyJKEOMcuiVBki2XT/UuoLz40Lw4b54HtwFTaUQQa3zmSJN5u/5KC8TW8nIKF/7fYChqypX3KKBSqBJe0Gul9ncTqHmzpzrwERlh5GkYSH+nr5t8cUK1pBilscKbCxh5x6irOnUmosoKJDv68WKq8WLsjpRslV5/1VztBanFFOZdD3tfIph1Yn7j1DQP4NcT1cQGoBhO0b0vwHtz6vTY4SpHnYuwB1K4dQ3k+gYJUspn03byi/8KVvcerLKfXYFKR5uvRkHihlIwjlxL2FoXIkGhtlkFVFOx76CvEv8LU5AT1ueJ34C/qP6PSD//pezXkk3e4UGeQMLOUu507FjfjHjD4luxIInzBb1KLAjzxb+2B4JTHy2uUu1dpHXarqSyR3DAPcLqUjZajZ+6mQh7zNRgkwXyZqg9p2TOdfiH9dvrqPowocGJgfjsYnd9rfdQVc10h1zk4pP4pP/YhgMVzYYc/ytCqUP41zSsrtJI592PUS9/quDGfrUcuG4t06DJgevky5AGX2og+sR4e83UpgId/DdV/m1OIvuoS4iMrzN2XmZ7IaFxH03nWQPrndDJ3j9ZHiaZ9IyW0XwthJFXcaslL5w3c0+1y8blxhC0vHT4NUsf5vcY3pFrBsMbTt1yNIGcitnLhXC1k99JbQ=="
    hernan      = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDR3qtsMDFjfMFBn+Xgic3cFLv5+wnKPTFV8ps3tlLnmJLPSVbhhXRYsn0ZDZtSbfSFyGWIEDLIBDp61DjkrO/qObv0hu9BOT54YSEUel89fTWHX2dEqUd0zEU9YvwHTVfIeuNOg3T7pcwtFSDCND/CE1o1rpYWWXshF10qrBVUuWJJxpJJF6LVVHD6xn6Yf6qR5PJ1WKJyR/+LL18FZuS4j0V0PJP1Kv1hHmlWM5v8N6IX+HQY/SdoB0e9xrOMbwFRTBxjpt2qeRVB7nskHnXEEBCm16aXi41XqdV+II1rkdY9oFPzjdNBTz7QHrf+1TIGiBIlhdC8tkbBtUPDZB/ywRtthM3o46dddxaVJnp1lqeVCDVckej4IYnRJTWYaFoG13peaIh+SXLGfLrdlWnjfzHx/4VmDfhpgi5Jmmfoel8S1n3cn4woEmbCK2aKWP1p8FCpY4QFICT5aJY3nkk0ciglbC58Q4sm3Pm3Hr3Stfe0RxZhQwosLAWX6kqr+EU= hrajchert@MacBook-Pro-de-Hernan.local"
    bozhidar    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCjoAB+Z1YyhKMV8tRqSTfkt4BYcYU2Y97WrVGOALOU6m5AGA/fHIq23ELalovG1Im1UWCDA/uMd7Avl9nUB2CxMhm33K2whUA62A6iUp6HdlxQg4C5c2uhxiJzhwLT8dUj5ACmxCGDVuy5o/2fQXyPXii/IjJnJv0Os39u1jipqRTeWfittZBVeIlu6e23H8HHuUmMvHyDPZZ6z1lER7ZaJh/fYN357mw5oJq7jee1SRsgu056v1550lhjWcKvKvaC4osvGBoxRDuPmlFaC/TBBld+kEaSV8GX+FsqCDTaezY+EpcDfLwpp+OsRvth48/8Bxx73e8izUdd/regbzUb boko@boko"
    dimitar     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/GZjyhqoOMCbCEANAqpXOzVZsKnnAXkaZQICSSibk2AZxokgplHi9CpAX63M5fRhxy8YfA5v7iOUTYt8OYQEYm1EFlPWkf9CtUWIKp89uT5618SC6vbrFDY5qHXrgZRPSoyhO0/XNQSiGB34JwBQ5rvD1SAXSnoCNT6SvbgNuJfcCRVrIPdn60qmwNfyJmrHDyqbyENhDlYBdrBgncpki0SW51pJ0Q4OwC+686Mjo0I3IJcw9BHIrNoCxc84vR6o4IhjdSOs8lDej5iBccYQ833jI/EAnbhVbTKphPUzbnAeQnPcKV9DH/uv6J0c2jKcMXsSTSGsb2cLLt4xUy9I5 dimitar@dimitar-HP-ProBook-450-G4"
    shlevy      = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID/fJqgjwPG7b5SRPtCovFmtjmAksUSNg3xHWyqBM4Cs shlevy@shlevy-laptop"
  }

  # Anyone who wants ssh access to a machine needs ssh access to the bastion hosts
  bastion_ssh_keys_ks = {
    alpha      = ["pablo", "shlevy", "ci-deployer"]
    pablo      = ["pablo"]
    production = ["pablo", "shlevy", "ci-deployer"]
    playground = ["pablo", "shlevy"]
    testing    = ["pablo", "shlevy", "bozhidar", "dimitar"]
    hernan     = ["hernan"]
    staging    = ["pablo", "shlevy", "ci-deployer"]
    bitte_match = ["shlevy", "ci-deployer"]
  }
  bastion_ssh_keys = [for k in local.bastion_ssh_keys_ks[var.env] : local.ssh_keys[k]]

  # root users are able to deploy to the machines using morph
  root_ssh_keys_ks = {
    alpha      = ["pablo", "shlevy", "ci-deployer"]
    pablo      = ["pablo"]
    production = ["pablo", "shlevy", "ci-deployer"]
    testing    = ["pablo", "shlevy", "bozhidar", "dimitar"]
    hernan     = ["hernan"]
    staging    = ["pablo", "shlevy", "ci-deployer"]
    bitte_match = ["shlevy", "ci-deployer"]
  }
  root_ssh_keys = [for k in local.root_ssh_keys_ks[var.env] : local.ssh_keys[k]]

}

module "nixos_image" {
  source  = "git::https://github.com/tweag/terraform-nixos.git//aws_image_nixos?ref=5f5a0408b299874d6a29d1271e9bffeee4c9ca71"
  release = "20.09"
}
