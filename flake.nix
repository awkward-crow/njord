{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs { system = "x86_64-linux"; };
    fontsConf = import ./fonts.nix { inherit pkgs; };
  in {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [ 
        R
        git
        
        rPackages.usethis
        rPackages.testthat
        rPackages.devtools
        rPackages.roxygen2
        rPackages.codetools
        rPackages.terra
        rPackages.ecmwfr
        rPackages.readxl
        rPackages.MASS
        rPackages.evd

        netcdf
        glibcLocales
      ];
      shellHook = ''
        export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive
        export LANG=en_GB.UTF-8
        export PROMPT_COMMAND='PS1="[nix-dev] \w \$ "'
        unset R_LIBS
        export R_LIBS_USER=$PWD/.nix-Rlibs
        mkdir -p "$R_LIBS_USER"
        export FONTCONFIG_FILE=${fontsConf}
      '';
    };
  };
}
