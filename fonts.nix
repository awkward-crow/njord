{ pkgs }: pkgs.writeText "fonts.conf" ''
  <?xml version="1.0"?>
  <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
  <fontconfig>
    <dir>${pkgs.noto-fonts}/share/fonts</dir>
    <cachedir>/tmp/fontconfig-cache-njord</cachedir>

    <alias><family>sans-serif</family><prefer><family>Noto Sans</family></prefer></alias>
    <alias><family>serif</family><prefer><family>Noto Serif</family></prefer></alias>
    <alias><family>monospace</family><prefer><family>Noto Sans Mono</family></prefer></alias>
    <alias><family>Helvetica</family><prefer><family>Noto Sans</family></prefer></alias>
    <alias><family>Times</family><prefer><family>Noto Serif</family></prefer></alias>
    <alias><family>Courier</family><prefer><family>Noto Sans Mono</family></prefer></alias>

    <match target="pattern">
      <test qual="any" name="family"><string>sans</string></test>
      <edit name="family" mode="assign" binding="strong"><string>Noto Sans</string></edit>
    </match>
    <match target="pattern">
      <test qual="any" name="family"><string>Helvetica</string></test>
      <edit name="family" mode="assign" binding="strong"><string>Noto Sans</string></edit>
    </match>
  </fontconfig>
''
