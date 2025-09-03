{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

let
  panvimdoc = pkgs.stdenv.mkDerivation {
    pname = "panvimdoc";
    version = "4.0.1";

    src = pkgs.fetchFromGitHub {
      owner = "kdheepak";
      repo = "panvimdoc";
      rev = "v4.0.1";
      sha256 = "sha256-HmEBPkNELHC7Xy0v730sQWZyPPwFdIBUcELzNtrWwzQ=";
    };

    nativeBuildInputs = with pkgs; [ makeWrapper ];
    buildInputs = with pkgs; [
      python3
      pandoc
    ];

    installPhase = ''
      mkdir -p $out/bin 
      cp -r scripts/ $out/bin/
      cp panvimdoc.sh $out/bin/panvimdoc
      chmod +x $out/bin/panvimdoc
      wrapProgram $out/bin/panvimdoc \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.pandoc
            pkgs.python3
          ]
        }
    '';
  };
in

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = with pkgs; [
    git
    stylua
    pandoc
    panvimdoc
    pre-commit
    luajitPackages.nlua
    luajitPackages.luacheck
    luajitPackages.vusted
    luajitPackages.luacov
  ];

  # https://devenv.sh/languages/
  languages.lua.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
