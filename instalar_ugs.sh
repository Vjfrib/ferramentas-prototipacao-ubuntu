#!/usr/bin/env bash
# =============================================================================
#  instalar_ugs.sh  -  UGS Platform (Universal Gcode Sender) para CNC / GRBL
#
#  Uso:   bash instalar_ugs.sh
#  Baixa a última versão do GitHub (winder/Universal-G-Code-Sender), com o Java
#  já embutido, instala em ~/.local/opt/ugs, cria o comando "ugs" e o atalho no
#  menu, e coloca você no grupo "dialout" para acessar a porta serial (USB) da CNC.
#  Log: ~/ugs-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"
inicio ugs-install.log
DEST="$HOME/.local/opt/ugs"
DESKTOP="$HOME/.local/share/applications/ugs.desktop"
API=https://api.github.com/repos/winder/Universal-G-Code-Sender/releases/latest

step "1/4  Procurando a última versão"
apt_instalar curl python3
JSON="$(curl -fsSL "$API")" || die "não consegui consultar $API (sem internet?)."
read -r TAG URL < <(printf '%s' "$JSON" | python3 -I -c '
import json, re, sys
d = json.load(sys.stdin)
assets = [a["browser_download_url"] for a in d.get("assets", [])]
# 1º: pacote Linux x64 da UGS Platform (traz o Java junto)
for pat in (r"linux.*x64.*platform.*\.tar\.gz$", r"platform.*linux.*x64.*\.tar\.gz$",
            r"linux.*platform.*\.tar\.gz$"):
    m = [u for u in assets if re.search(pat, u.rsplit("/", 1)[-1], re.I)]
    if m:
        print(d.get("tag_name", "?"), m[0]); break
else:
    print(d.get("tag_name", "?"), "")
')
[ -n "${URL:-}" ] || die "não achei o pacote Linux x64 na versão $TAG. Baixe manualmente em
    https://github.com/winder/Universal-G-Code-Sender/releases"
ok "versão $TAG: $(basename "$URL")"

step "2/4  Baixando e instalando em $DEST"
if [ "$(cat "$DEST/.versao" 2>/dev/null)" = "$TAG" ]; then
    ok "UGS $TAG já instalado (pulando)"
else
    T="$(mktemp -d)"
    curl -fL --progress-bar -o "$T/ugs.tar.gz" "$URL" || { rm -rf "$T"; die "download falhou."; }
    mkdir -p "$T/x"
    tar -xzf "$T/ugs.tar.gz" -C "$T/x" || { rm -rf "$T"; die "o arquivo baixado não abriu."; }
    BIN="$(find "$T/x" -maxdepth 3 -type f -path '*/bin/ugsplatform' | head -1)"
    [ -n "$BIN" ] || { rm -rf "$T"; die "não achei bin/ugsplatform dentro do pacote."; }
    rm -rf "$DEST"; mkdir -p "$(dirname "$DEST")"
    mv "$(dirname "$(dirname "$BIN")")" "$DEST"
    echo "$TAG" > "$DEST/.versao"
    rm -rf "$T"
    ok "instalado em $DEST"
fi
chmod +x "$DEST/bin/ugsplatform"
mkdir -p "$HOME/.local/bin"
ln -sfn "$DEST/bin/ugsplatform" "$HOME/.local/bin/ugs"

step "3/4  Atalho no menu"
ICON="$(find "$DEST" -maxdepth 4 -iname '*ugs*.png' 2>/dev/null | sort | tail -1)"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" <<EOT
[Desktop Entry]
Type=Application
Name=Universal Gcode Sender
Comment=Controle de CNC (GRBL e outros)
Exec=$DEST/bin/ugsplatform
Icon=${ICON:-applications-engineering}
Terminal=false
Categories=Development;Electronics;
EOT
update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true
ok "Atalho: 'Universal Gcode Sender'"

step "4/4  Acesso à porta serial (grupo dialout)"
if id -nG "$USER" | tr ' ' '\n' | grep -qx dialout; then
    ok "você já está no grupo dialout"
else
    sudo usermod -aG dialout "$USER" || die "não consegui adicionar você ao grupo dialout."
    ok "adicionado ao grupo dialout"
    warn "saia e entre de novo na sessão (ou reinicie) para valer o acesso à porta serial."
fi
# O brltty (leitor braille) costuma "roubar" adaptadores USB-serial CH340 no Ubuntu.
if dpkg -s brltty >/dev/null 2>&1; then
    warn "o pacote brltty está instalado; ele pode tomar a porta de placas com CH340."
    echo "    Se a CNC não aparecer em /dev/ttyUSB*, rode:  sudo apt remove brltty"
fi

echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra pelo menu 'Universal Gcode Sender' ou rode:  ugs"
echo "(Se 'ugs' não for encontrado, feche e abra o terminal de novo.)"
