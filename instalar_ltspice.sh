#!/usr/bin/env bash
# =============================================================================
#  instalar_ltspice.sh  -  LTspice (Analog Devices) pelo Wine
#
#  Uso:   bash instalar_ltspice.sh            instala (ou atualiza)
#         bash instalar_ltspice.sh --remover  apaga o LTspice e o prefixo do Wine
#
#  Usa o Wine do apt do Ubuntu, num prefixo só dele (~/.local/share/wineprefixes/ltspice),
#  baixa o LTspice64.msi do site da Analog Devices (ou usa o que estiver em
#  ~/Downloads), cria o comando "ltspice" e o atalho no menu.
#  Log: ~/ltspice-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"

PFX="$HOME/.local/share/wineprefixes/ltspice"
BIN="$HOME/.local/bin/ltspice"
DESKTOP="$HOME/.local/share/applications/ltspice.desktop"
ICONE="$HOME/.local/share/icons/hicolor/256x256/apps/ltspice.png"
URL_MSI="https://ltspice.analog.com/software/LTspice64.msi"
PAGINA="https://www.analog.com/en/resources/design-tools-and-calculators/ltspice-simulator.html"

if [ "${1:-}" = "--remover" ]; then
    rm -rf "$PFX" "$BIN" "$DESKTOP" "$ICONE"
    echo "LTspice removido (o Wine continua instalado)."
    exit 0
fi

inicio ltspice-install.log
export WINEPREFIX="$PFX" WINEARCH=win64 WINEDEBUG=-all
DL="$(pasta_downloads)"

achar_exe() { find "$PFX/drive_c" -type f -iname 'LTspice.exe' 2>/dev/null | head -1; }
achar_msi() { find "$DL" -maxdepth 1 -type f \( -iname 'LTspice*.msi' -o -iname 'LTspice*.exe' \) 2>/dev/null | sort | tail -1; }

step "1/4  Wine e utilitários"
wine_instalar
apt_instalar curl icoutils

step "2/4  Instalador do LTspice"
MSI="$(achar_msi)"
if [ -n "$MSI" ]; then
    ok "usando o que já está em Downloads: $MSI"
else
    MSI="$HOME/.cache/ltspice/LTspice64.msi"
    mkdir -p "$(dirname "$MSI")"
    echo "  Baixando $URL_MSI"
    if curl -fL --progress-bar -o "$MSI.part" "$URL_MSI" && mv "$MSI.part" "$MSI"; then
        ok "baixado: $MSI ($(du -h "$MSI" | cut -f1))"
    else
        rm -f "$MSI.part"
        warn "o download automático falhou (o site pode ter mudado o endereço)."
        esperar_download "LTspice para Windows 64 bits" "$PAGINA" \
            "LTspice64.msi (botão 'Download for Windows 64-bit')" achar_msi \
            || die "Sem o instalador não dá para continuar. Baixe em $PAGINA e rode de novo."
        MSI="$ACHADO"
    fi
fi

step "3/4  Instalando no prefixo do Wine ($PFX)"
if [ ! -d "$PFX/drive_c" ]; then
    echo "  Criando o prefixo (primeira vez demora ~1 min)..."
    # sem Mono/Gecko: o LTspice não usa .NET nem o navegador do Wine
    WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -i >/dev/null 2>&1 || true
    wineserver -w
fi
[ -d "$PFX/drive_c" ] || die "o Wine não conseguiu criar o prefixo em $PFX."
# winemenubuilder desligado para o Wine não criar atalhos duplicados no menu
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
case "$MSI" in
    *.msi|*.MSI)
        echo "  Rodando o instalador (aparece uma janela de progresso)..."
        wine msiexec /i "$MSI" /qb ALLUSERS=1 || {
            warn "a instalação silenciosa falhou; abrindo o instalador normal (aceite o padrão)."
            wine msiexec /i "$MSI"
        } ;;
    *)
        echo "  Abrindo o instalador .exe (aceite as opções padrão)..."
        wine "$MSI" ;;
esac
wineserver -w
EXE="$(achar_exe)"
[ -n "$EXE" ] || die "não achei o LTspice.exe dentro de $PFX depois da instalação."
ok "LTspice instalado: ${EXE#"$PFX/"}"

step "4/4  Comando 'ltspice' e atalho no menu"
mkdir -p "$(dirname "$BIN")" "$(dirname "$DESKTOP")"
cat > "$BIN" <<EOS
#!/usr/bin/env bash
# Abre o LTspice (Wine). Aceita arquivos: ltspice circuito.asc
export WINEPREFIX="$PFX" WINEDEBUG=-all
EXE="\$(find "\$WINEPREFIX/drive_c" -type f -iname LTspice.exe 2>/dev/null | head -1)"
[ -n "\$EXE" ] || { echo "LTspice não encontrado em \$WINEPREFIX. Rode o instalar_ltspice.sh de novo."; exit 1; }
args=()
for a in "\$@"; do
    if [ -e "\$a" ]; then args+=("\$(winepath -w "\$a" 2>/dev/null)"); else args+=("\$a"); fi
done
exec wine "\$EXE" "\${args[@]}"
EOS
chmod +x "$BIN"
icone_do_exe "$EXE" "$ICONE" && ok "ícone extraído" || ICONE="applications-science"
cat > "$DESKTOP" <<EOS
[Desktop Entry]
Type=Application
Name=LTspice
Comment=Simulador de circuitos (Analog Devices, via Wine)
Exec=$BIN %f
Icon=$ICONE
Terminal=false
Categories=Electronics;Engineering;Science;
MimeType=application/x-ltspice;
StartupWMClass=ltspice.exe
EOS
update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true
ok "comando: $BIN"
ok "atalho: LTspice (no menu de aplicativos)"

# Teste em modo batch (-b): simula um RC sem abrir janela. Só avisa se falhar.
T="$(mktemp -d)"
cat > "$T/teste_rc.net" <<'EOS'
* teste do instalador: circuito RC
V1 in 0 PULSE(0 1 0 1u 1u 1m 2m)
R1 in out 1k
C1 out 0 1u
.tran 4m
.end
EOS
echo "  Testando uma simulação em modo batch (até 2 min)..."
( cd "$T" && timeout 120 wine "$EXE" -b "$(winepath -w "$T/teste_rc.net")" >/dev/null 2>&1 )
wineserver -k 2>/dev/null || true
if [ -s "$T/teste_rc.raw" ] || grep -qi 'elapsed\|total' "$T/teste_rc.log" 2>/dev/null; then
    ok "simulação de teste rodou (teste_rc.raw gerado)"
else
    warn "o teste batch não gerou resultado. Abra o LTspice pelo menu para conferir;"
    warn "na primeira vez ele baixa as bibliotecas de componentes, o que pode demorar."
fi
rm -rf "$T"

echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra \"LTspice\" no menu ou rode:  ltspice   (ou  ltspice circuito.asc)"
echo "  Seus circuitos podem ficar em qualquer pasta; Documentos do Wine = sua pasta ~/Documentos."
echo "  Para remover:  bash $0 --remover"
