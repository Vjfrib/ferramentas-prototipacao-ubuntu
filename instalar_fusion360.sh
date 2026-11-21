#!/usr/bin/env bash
# =============================================================================
#  instalar_fusion360.sh  -  Autodesk Fusion (Fusion 360) pelo Wine  [EXPERIMENTAL]
#
#  Uso:   bash instalar_fusion360.sh            instala
#         bash instalar_fusion360.sh --remover  apaga tudo que este script criou
#
#  O Fusion não tem versão para Linux e a Autodesk não dá suporte a ele no Wine.
#  Este script segue os passos do projeto da comunidade cryinkfly
#  (https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux), mas:
#    - usa o Wine do apt do Ubuntu (não troca pelo da WineHQ, não roda
#      "apt remove wine*" nem "apt autoremove", que o script original roda);
#    - deixa tudo numa pasta só: ~/.local/share/fusion360-wine
#  Variáveis:  FUSION_GPU=opengl|dxvk   (padrão: dxvk se houver Vulkan)
#              FUSION_SIM=1             (não pergunta antes de começar)
#  Log: ~/fusion360-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"

BASE="$HOME/.local/share/fusion360-wine"
PFX="$BASE/prefixo"
BIN="$HOME/.local/bin/fusion360"
BIN_LOGIN="$HOME/.local/bin/fusion360-login"
APPS="$HOME/.local/share/applications"
DESKTOP="$APPS/fusion360.desktop"
DESKTOP_LOGIN="$APPS/fusion360-login.desktop"
ICONE="$HOME/.local/share/icons/hicolor/256x256/apps/fusion360.png"
URL_FUSION="https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Admin%20Install.exe"
URL_WINETRICKS="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
# DLLs corrigidas pelo projeto da comunidade (login e painéis web do Fusion)
REPOS_DLL=(
    "https://codeberg.org/cryinkfly/Autodesk-Fusion-360-on-Linux/raw/branch/main/files/extras/patched-dlls"
    "https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/extras/patched-dlls"
)

if [ "${1:-}" = "--remover" ]; then
    WINEPREFIX="$PFX" wineserver -k 2>/dev/null || true
    rm -rf "$BASE" "$BIN" "$BIN_LOGIN" "$DESKTOP" "$DESKTOP_LOGIN" "$ICONE"
    echo "Fusion removido (o Wine continua instalado)."
    exit 0
fi

inicio fusion360-install.log
export WINEPREFIX="$PFX" WINEARCH=win64 WINEDEBUG=-all

# ----------------------------- 0. aviso -------------------------------------
cat <<EOF

${c_warn}${c_b}  Fusion 360 no Wine é EXPERIMENTAL.${c_0} Antes de continuar, saiba que:

  - A Autodesk não dá suporte ao Fusion no Linux. Ele se atualiza sozinho e
    uma atualização pode quebrar o que funcionava ontem.
  - O projeto da comunidade testa no Ubuntu 20.04 a 25.04; o 26.04 ainda não
    está na lista dele.
  - O login na conta Autodesk às vezes não volta para o programa. O script
    registra o "fusion360-login" para isso, mas pode precisar de tentativas.
  - Precisa de placa de vídeo com OpenGL 3.3+ ou Vulkan. Em vídeo integrado
    funciona, mas fica lento em modelos grandes.
  - Baixa uns 3 a 4 GB e leva de 30 min a 1 h. Precisa de ~15 GB livres.
  - Painéis que usam o navegador interno (Data Panel, extensões, renderização
    na nuvem) são os que mais falham.

  Para CAD no Linux sem surpresas: o FreeCAD (deste menu) ou o Onshape no
  navegador. Tudo deste script fica em $BASE e sai com
  "bash $0 --remover", sem mexer no resto do sistema.

EOF
if [ "${FUSION_SIM:-0}" != 1 ]; then
    [ -r /dev/tty ] || die "sem terminal para confirmar. Rode com FUSION_SIM=1 para pular a pergunta."
    r=""; read -r -p "  Continuar com a instalação? [s/N] " r </dev/tty || true
    case "$r" in s|S|sim|y|Y) ;; *) echo "  Cancelado."; exit 0 ;; esac
fi

# ----------------------------- 1. verificações ------------------------------
step "1/7  Verificando o computador"
[ "$(uname -m)" = "x86_64" ] || die "o Fusion só roda em x86_64."
. /etc/os-release 2>/dev/null || true
ok "sistema: ${PRETTY_NAME:-?}"
RAM_GB=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 / 1024 ))
if [ "$RAM_GB" -lt 7 ]; then warn "RAM: ${RAM_GB} GB. O Fusion pede pelo menos 8 GB."; else ok "RAM: ${RAM_GB} GB"; fi
mkdir -p "$BASE"
LIVRE_GB=$(( $(df -Pk "$BASE" | awk 'NR==2{print $4}') / 1024 / 1024 ))
[ "$LIVRE_GB" -ge 15 ] || die "só ${LIVRE_GB} GB livres em $BASE; o Fusion precisa de ~15 GB."
ok "espaço livre: ${LIVRE_GB} GB"

step "2/7  Wine e utilitários (apt do Ubuntu)"
wine_instalar 32
apt_instalar curl cabextract p7zip-full winbind xdg-utils mesa-utils icoutils
wine_versao_ok 9 8 || die "o Fusion precisa do Wine 9.8 ou mais novo, e o do apt é $(wine --version).
    Este script não troca o Wine do sistema. Alternativa: Bottles (Flathub) com o runner mais novo."
ok "versão do Wine serve (>= 9.8)"

if command -v glxinfo >/dev/null && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    glxinfo -B 2>/dev/null | grep -E 'OpenGL renderer|OpenGL core profile version|OpenGL version' | sed 's/^/    /'
fi
GPU="${FUSION_GPU:-}"
if [ -z "$GPU" ]; then
    if ls /usr/share/vulkan/icd.d/*.json /etc/vulkan/icd.d/*.json >/dev/null 2>&1; then GPU=dxvk; else GPU=opengl; fi
fi
ok "modo gráfico: $GPU   (troque com FUSION_GPU=opengl ou FUSION_GPU=dxvk)"

# ----------------------------- 3. winetricks --------------------------------
step "3/7  winetricks (versão mais nova, em $BASE/bin)"
mkdir -p "$BASE/bin" "$BASE/downloads"
WT="$BASE/bin/winetricks"
if curl -fsSL -o "$WT.novo" "$URL_WINETRICKS"; then
    mv "$WT.novo" "$WT"; chmod +x "$WT"; ok "winetricks $(sh "$WT" --version 2>/dev/null | head -1)"
else
    rm -f "$WT.novo"
    [ -x "$WT" ] || { apt_instalar winetricks; WT="$(command -v winetricks)"; }
    warn "não baixei o winetricks novo; usando $WT"
fi
wt() { echo "  winetricks $*"; sh "$WT" -q "$@"; }

# ----------------------------- 4. prefixo -----------------------------------
step "4/7  Preparando o prefixo do Wine ($PFX)"
if [ -f "$BASE/.prefixo_pronto" ]; then
    ok "prefixo já preparado (pulando)"
else
    wineboot -i >/dev/null 2>&1 || true
    wineserver -w
    echo "  Instalando os componentes do Windows (demora: .NET, fontes, Visual C++)..."
    wt sandbox || warn "sandbox falhou"
    wt atmlib gdiplus arial corefonts cjkfonts dotnet452 msxml4 msxml6 vcrun2017 fontsmooth=rgb winhttp win10 \
        || die "o winetricks falhou (veja acima qual componente). Rode o script de novo; ele continua de onde parou."
    wt win11 || warn "não consegui trocar para Windows 11 (seguindo)"
    if [ "$GPU" = dxvk ]; then wt dxvk || { warn "DXVK falhou; usando OpenGL"; GPU=opengl; }; fi
    for o in "adpclientservice.exe=" "AdCefWebBrowser.exe=builtin" "msvcp140=native" "mfc140u=native" "bcp47langs="; do
        wine reg add 'HKCU\Software\Wine\DllOverrides' /v "${o%%=*}" /t REG_SZ /d "${o#*=}" /f >/dev/null 2>&1
    done
    wineserver -w
    echo "$GPU" > "$BASE/.prefixo_pronto"
    ok "prefixo pronto"
fi

# ----------------------------- 5. Fusion ------------------------------------
achar_fusion() {
    find "$PFX/drive_c" -type f -name Fusion360.exe -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}
step "5/7  Baixando e instalando o Fusion"
if [ -n "$(achar_fusion)" ]; then
    ok "Fusion já instalado (ele se atualiza sozinho ao abrir)"
else
    INST="$BASE/downloads/FusionClientInstaller.exe"
    if [ ! -s "$INST" ]; then
        curl -fL --progress-bar -o "$INST.part" "$URL_FUSION" && mv "$INST.part" "$INST" \
            || die "não consegui baixar o instalador do Fusion ($URL_FUSION)."
    fi
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    echo "  Instalando (o instalador baixa o resto, ~3 GB; pode passar de 20 min sem mostrar nada)..."
    timeout -k 5m 45m wine "$INST" --quiet >>"$BASE/instalador_1.log" 2>&1 || true
    wineserver -k 2>/dev/null || true
    # segunda passada: o instalador às vezes para no meio e termina na segunda vez
    timeout -k 2m 5m wine "$INST" --quiet >>"$BASE/instalador_2.log" 2>&1 || true
    wineserver -k 2>/dev/null || true
    unset WINEDLLOVERRIDES
    [ -n "$(achar_fusion)" ] || die "o Fusion360.exe não apareceu no prefixo. Logs do instalador:
    $BASE/instalador_1.log e instalador_2.log. Rode de novo para tentar outra vez."
fi
FUSION_EXE="$(achar_fusion)"
ok "Fusion360.exe: ${FUSION_EXE#"$PFX/drive_c/"}"

# ----------------------------- 6. correções ---------------------------------
step "6/7  DLLs corrigidas da comunidade (login e painéis web)"
baixar_dll() {   # baixar_dll <arquivo> <destino>
    local r
    for r in "${REPOS_DLL[@]}"; do
        curl -fsSL -o "$2" "$r/$1" 2>/dev/null && [ -s "$2" ] && { echo "    de $r"; return 0; }
    done
    return 1
}
trocar_dll() {   # trocar_dll <nome.dll> <arquivo novo>: troca a cópia mais recente, guardando .bak
    local alvo
    alvo="$(find "$PFX/drive_c" -type f -name "$1" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
    [ -n "$alvo" ] || { warn "não achei $1 no prefixo"; return 1; }
    [ -f "$alvo.bak" ] || cp "$alvo" "$alvo.bak"
    cp "$2" "$alvo" && ok "$1 trocada (original em $(basename "$alvo").bak)"
}
T="$(mktemp -d)"
if baixar_dll Qt6WebEngineCore-06-2025.7z "$T/qt.7z" && 7z x -y -o"$T/qt" "$T/qt.7z" >/dev/null; then
    NOVA="$(find "$T/qt" -name Qt6WebEngineCore.dll | head -1)"
    [ -n "$NOVA" ] && trocar_dll Qt6WebEngineCore.dll "$NOVA"
else
    warn "não consegui baixar a Qt6WebEngineCore corrigida; o login pode não abrir."
fi
if baixar_dll siappdll.dll "$T/siappdll.dll"; then
    trocar_dll siappdll.dll "$T/siappdll.dll" || true
else
    warn "não consegui baixar a siappdll.dll corrigida (só afeta o SpaceMouse)."
fi
rm -rf "$T"

# ----------------------------- 7. atalhos -----------------------------------
step "7/7  Comandos e atalhos"
mkdir -p "$(dirname "$BIN")" "$APPS"
cat > "$BIN" <<EOS
#!/usr/bin/env bash
# Abre o Autodesk Fusion (Wine). Procura sempre a versão mais nova, porque ele se atualiza sozinho.
export WINEPREFIX="$PFX" WINEDEBUG=-all
EXE="\$(find "\$WINEPREFIX/drive_c" -type f -name Fusion360.exe -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
[ -n "\$EXE" ] || { echo "Fusion não encontrado em \$WINEPREFIX. Rode o instalar_fusion360.sh de novo."; exit 1; }
cd "\$(dirname "\$EXE")" && exec wine "\$EXE" "\$@"
EOS
cat > "$BIN_LOGIN" <<EOS
#!/usr/bin/env bash
# Recebe o link adskidmgr:// do navegador depois do login e entrega ao Fusion.
export WINEPREFIX="$PFX" WINEDEBUG=-all
EXE="\$(find "\$WINEPREFIX/drive_c" -type f -name AdskIdentityManager.exe 2>/dev/null | head -1)"
[ -n "\$EXE" ] || { echo "AdskIdentityManager.exe não encontrado."; exit 1; }
exec wine "\$EXE" "\$@"
EOS
chmod +x "$BIN" "$BIN_LOGIN"
icone_do_exe "$FUSION_EXE" "$ICONE" && ok "ícone extraído" || ICONE="applications-engineering"
cat > "$DESKTOP" <<EOS
[Desktop Entry]
Type=Application
Name=Autodesk Fusion (Wine)
Comment=CAD/CAM 3D - experimental, via Wine
Exec=$BIN
Icon=$ICONE
Terminal=false
Categories=Graphics;Engineering;3DGraphics;
StartupWMClass=fusion360.exe
EOS
cat > "$DESKTOP_LOGIN" <<EOS
[Desktop Entry]
Type=Application
Name=Autodesk Fusion - login
Exec=$BIN_LOGIN %u
Terminal=false
NoDisplay=true
MimeType=x-scheme-handler/adskidmgr;
EOS
update-desktop-database "$APPS" >/dev/null 2>&1 || true
xdg-mime default fusion360-login.desktop x-scheme-handler/adskidmgr 2>/dev/null \
    && ok "links de login (adskidmgr://) vão para o Fusion" \
    || warn "não consegui registrar o adskidmgr://; o login pelo navegador pode não voltar."
touch "$BASE/.instalado"

echo
echo "${c_ok}${c_b}Instalado.${c_0} Abra \"Autodesk Fusion (Wine)\" no menu ou rode:  fusion360"
cat <<EOF
  Na primeira vez:
   - Ele abre o navegador para entrar na conta Autodesk. Depois de entrar,
     se o navegador perguntar, aceite abrir o link no "Autodesk Fusion - login".
   - Se a área de desenho ficar preta ou piscando: Preferências > Geral >
     Gráficos > Driver gráfico = OpenGL, e reabra.
  Remover tudo:  bash $0 --remover
EOF
