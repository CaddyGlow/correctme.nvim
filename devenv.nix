{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    stylua
    luajitPackages.luacheck
    luajitPackages.vusted
    luajitPackages.luacov
  ];

  # https://devenv.sh/languages/
  languages.lua.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
