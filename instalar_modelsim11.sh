#!/usr/bin/env bash
# =============================================================================
#  instalar_modelsim11.sh
#  Instala o ModelSim-Altera Starter Edition 11.0 (32 bits, sem licença) no
#  Ubuntu 26.04 x86_64, ao lado do Quartus II 11.0 em ~/altera/11.0.
#
#  Uso:   bash instalar_modelsim11.sh
#  Coloque antes em ~/Downloads o instalador baixado da Altera/Intel, por exemplo
#  11.0_modelsim_ase_linux.sh (ou a pasta já extraída, ou um ModelSimSetup-*.run).
#  Outro caminho:  MODELSIM_SRC=/caminho/do/instalador bash instalar_modelsim11.sh
#
#  Pode rodar quantas vezes quiser: o que já foi feito é pulado.
#  NÃO roda "apt autoremove" e não remove nenhum pacote.
#  Log completo: ~/modelsim11-install.log
# =============================================================================

set -u

# ----------------------------- configuração ---------------------------------
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"   # esperar_download, pasta_downloads
DL="$(pasta_downloads)"
LINK_Q11="https://www.altera.com/downloads/fpga-development-tools/quartus-ii-web-edition-design-software-version-11-0-b123-linux"
LINK_MS13="https://www.altera.com/downloads/fpga-development-tools/quartus-ii-web-edition-design-software-version-13-0sp1-linux"
SRC="${MODELSIM_SRC:-}"
DEST="$HOME/altera/11.0"
LOG="$HOME/modelsim11-install.log"
DESKTOP="$HOME/.local/share/applications/modelsim11.desktop"
export GLIBC_TUNABLES="glibc.rtld.execstack=2"

exec > >(tee -a "$LOG") 2>&1

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_b=$'\e[1m'; c_0=$'\e[0m'
step() { echo; echo "${c_b}==> $*${c_0}"; }
ok()   { echo "${c_ok}  [ok]${c_0} $*"; }
warn() { echo "${c_warn}  [aviso]${c_0} $*"; }
die()  {
    echo
    echo "${c_err}${c_b}ERRO: $*${c_0}"
    echo "O log completo está em: $LOG"
    exit 1
}

echo
echo "################  $(date '+%F %T')  instalar_modelsim11.sh  ################"

# Pasta do ModelSim já instalado (a que tem o script "vco"), ou vazio.
find_ms() {
    local v
    v="$(find "$DEST" -maxdepth 3 -type f -name vco -path '*modelsim*' 2>/dev/null | head -1)"
    [ -n "$v" ] && dirname "$v"
}
# Pasta dos binários de 32 bits (linuxaloem na versão Altera, ou linux).
find_vcodir() {
    local d
    for d in linuxaloem linux linux_rh60; do
        [ -x "$1/$d/vsim" ] && { echo "$d"; return; }
    done
}

# Procura o instalador do ModelSim, nesta ordem: pasta já extraída, .sh (makeself),
# .run (instalador novo) e, por último, o ModelSim que vem dentro do pacote do Quartus.
achar_modelsim() {
    local f
    f="$(find "$DL" -maxdepth 1 -type d -iname '*modelsim*linux*' 2>/dev/null | sort | head -1)"
    [ -n "$f" ] || f="$(find "$DL" -maxdepth 1 -type f -iname '*modelsim*linux*.sh' 2>/dev/null | sort | head -1)"
    [ -n "$f" ] || f="$(find "$DL" -maxdepth 1 -type f -iname 'ModelSimSetup-*.run' 2>/dev/null | sort | tail -1)"
    [ -n "$f" ] || f="$(find "$DL" -maxdepth 4 -type f -iname '*modelsim*.gz' 2>/dev/null | head -1 | xargs -r -d '\n' dirname)"
    echo "$f"
}

# ----------------------------- 1. verificações ------------------------------
step "1/6  Verificando o ambiente"
[ "$(id -u)" -ne 0 ] || die "Não rode com sudo. Rode como usuário normal: bash $0  (o script pede a senha quando precisar)."
[ "$(uname -m)" = "x86_64" ] || die "Este script é para x86_64 (detectado: $(uname -m))."
command -v apt-get >/dev/null || die "apt-get não encontrado; este script é para Ubuntu/Debian."
command -v python3 >/dev/null || die "python3 não encontrado. Instale com: sudo apt install python3"

MS="$(find_ms)"
if [ -n "$MS" ]; then
    ok "ModelSim já extraído em $MS (a instalação dos arquivos será pulada)"
else
    if [ -z "$SRC" ]; then
        esperar_download "ModelSim-Altera Starter (Linux)" "$LINK_MS13" \
            "ModelSimSetup-13.0.1.232.run (776 MB, item 'ModelSim-Altera Edition (includes Starter Edition)')" \
            achar_modelsim \
            "Precisa de uma conta gratuita no site da Altera (o link pede login).
A página do 11.0 só tem o pacote completo (quartus_free_linux.sh, 3,2 GB), que pode
trazer o ModelSim dentro: se você já tem esse arquivo, rode antes o instalador do
Quartus (ele extrai o pacote) e aperte Enter aqui. Página do 11.0:
    $LINK_Q11
O ModelSim 13.0 (10.1d) simula VHDL/Verilog do mesmo jeito; ele só não traz as
bibliotecas de simulação pós-síntese da Cyclone I." \
            || die "Sem o instalador do ModelSim não dá para continuar. Baixe em:
    $LINK_MS13
    e rode de novo (ou: MODELSIM_SRC=/caminho/do/arquivo bash $0)."
        SRC="$ACHADO"
    fi
    [ -e "$SRC" ] || die "Não existe: $SRC"
    ok "Instalador: $SRC"
fi
ok "Destino: $DEST"

echo "  Pedindo a senha do sudo uma vez (para o apt)..."
sudo -v || die "sudo falhou."
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT

# ----------------------------- 2. pacotes -----------------------------------
step "2/6  Bibliotecas de 32 bits (i386)"
if ! dpkg --print-foreign-architectures | grep -qx i386; then
    sudo dpkg --add-architecture i386 || die "dpkg --add-architecture i386 falhou"
fi
sudo apt-get update || warn "apt-get update teve erros (seguindo mesmo assim)"
WANT_I386="libc6 libstdc++6 libgcc-s1 zlib1g libexpat1
 libx11-6 libxext6 libxrender1 libxft2 libxtst6 libxi6 libxss1 libsm6 libice6
 libxau6 libxdmcp6 libxcb1 libfreetype6 libfontconfig1
 libncurses6 libncursesw6 libtinfo6"
WANT_NATIVE="file binutils fonts-dejavu-core xfonts-base"
TO_INSTALL=()
for p in $WANT_I386;   do apt-cache show "$p:i386" >/dev/null 2>&1 && TO_INSTALL+=("$p:i386"); done
for p in $WANT_NATIVE; do apt-cache show "$p"      >/dev/null 2>&1 && TO_INSTALL+=("$p");      done
echo "  Pacotes: ${TO_INSTALL[*]}"
sudo apt-get install -y --no-install-recommends "${TO_INSTALL[@]}" \
    || die "apt-get install falhou (veja acima qual pacote). Nada foi removido."
[ -e /lib/ld-linux.so.2 ] || die "/lib/ld-linux.so.2 não existe mesmo após instalar libc6:i386."
ok "Bibliotecas i386 instaladas"

# ----------------------------- utilidades de correção -----------------------
# Tira a marca de "pilha executável" de .so antigas (glibc >= 2.41 recusa carregá-las).
fix_execstack() {
    python3 -I - "$@" <<'PY'
import os, struct, sys
PT_GNU_STACK, PF_X = 0x6474e551, 1
fixed = 0
for root in sys.argv[1:]:
    for d, _, files in os.walk(root):
        for n in files:
            p = os.path.join(d, n)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            try:
                with open(p, 'r+b') as f:
                    h = f.read(64)
                    if len(h) < 52 or h[:4] != b'\x7fELF' or h[5] != 1:
                        continue
                    is64 = h[4] == 2
                    if struct.unpack_from('<H', h, 16)[0] != 3:
                        continue
                    if is64:
                        phoff, = struct.unpack_from('<Q', h, 32)
                        phentsize, phnum = struct.unpack_from('<HH', h, 54); flag_off = 4
                    else:
                        phoff, = struct.unpack_from('<I', h, 28)
                        phentsize, phnum = struct.unpack_from('<HH', h, 42); flag_off = 24
                    for i in range(phnum):
                        off = phoff + i * phentsize
                        f.seek(off); ph = f.read(phentsize)
                        if len(ph) < flag_off + 4:
                            break
                        if struct.unpack_from('<I', ph, 0)[0] != PT_GNU_STACK:
                            continue
                        flags, = struct.unpack_from('<I', ph, flag_off)
                        if flags & PF_X:
                            f.seek(off + flag_off); f.write(struct.pack('<I', flags & ~PF_X))
                            fixed += 1; print('    pilha executável removida:', p)
            except (PermissionError, OSError):
                pass
print('    bibliotecas corrigidas:', fixed)
PY
}

# Pedaços da glibc de 2011 que vêm junto com o instalador da Altera
quarantine_glibc() {
    local dir="$1" q="$1/_glibc_antiga_desativada" f
    for f in "$dir"/libc.so.* "$dir"/libm.so.* "$dir"/libdl.so.* "$dir"/libpthread.so.* \
             "$dir"/librt.so.* "$dir"/libresolv.so.* "$dir"/libutil.so.* "$dir"/libnsl.so.* \
             "$dir"/libcrypt.so.* "$dir"/ld-linux.so.*; do
        [ -e "$f" ] || continue
        mkdir -p "$q"; mv -f "$f" "$q/"; echo "    desativada (usa a do sistema): $(basename "$f")"
    done
}

# Extrai um tar.gz do pacote: se ele já começa com modelsim_ase/, vai para $DEST;
# senão vai para $DEST/modelsim_ase.
extract_component() {
    local a="$1" mark first target
    mark="$DEST/.extraido_$(basename "$a")"
    [ -e "$mark" ] && { ok "já extraído: $(basename "$a")"; return; }
    first="$(tar -tzf "$a" 2>/dev/null | sed 's#^\./##' | grep -v '^$' | head -1)"
    [ -n "$first" ] || { warn "$(basename "$a") não é tar.gz; pulando"; return; }
    case "$first" in
        modelsim_ase*|modelsim_ae*) target="$DEST" ;;
        *) target="$DEST/modelsim_ase" ;;
    esac
    mkdir -p "$target"
    echo "    extraindo $(basename "$a") ($(du -h "$a" | cut -f1)) em $target ..."
    tar -xzf "$a" -C "$target" && touch "$mark" || warn "falha ao extrair $(basename "$a")"
}

# ----------------------------- 3. instalação --------------------------------
step "3/6  Instalando o ModelSim em $DEST"
mkdir -p "$DEST"
if [ -z "$MS" ]; then
    case "$SRC" in
        *.run)
            # Instalador BitRock (versões 12+). Tem modo sem perguntas.
            chmod +x "$SRC"
            "$SRC" --mode unattended --accept_eula 1 --installdir "$DEST" \
                --modelsim_edition modelsim_ase \
                || "$SRC" --mode unattended --installdir "$DEST" \
                || warn "o instalador .run terminou com erro"
            ;;
        *.sh)
            # Arquivo makeself, igual ao do Quartus: só extrai, sem rodar o instalador Python.
            X="${SRC%.sh}"
            if [ ! -d "$X" ]; then
                echo "  Extraindo $SRC em $X (demora um pouco)..."
                chmod +x "$SRC"
                "$SRC" --noexec --target "$X" \
                    || ( cd "$(dirname "$SRC")" && "$SRC" --noexec --keep ) \
                    || die "Falha ao extrair $SRC"
            fi
            SRC="$X"
            ;;
    esac
fi
MS="$(find_ms)"
if [ -z "$MS" ] && [ -d "$SRC" ]; then
    echo "  Conteúdo do pacote (para diagnóstico):"
    find "$SRC" -maxdepth 3 -not -path '*/altera_installer/*' \( -type f -size +1M -o -type d \) \
        -printf '    %10s  %P\n' 2>/dev/null | head -40
    # Caminho A: extrair os componentes tar.gz direto
    mapfile -t PARTS < <(find "$SRC" -not -path '*/altera_installer/*' -type f \
        \( -iname '*modelsim*.gz' -o -path '*modelsim*/*.gz' -o -path '*linux_installer/*.gz' \) 2>/dev/null | sort)
    for a in "${PARTS[@]}"; do
        # só pacotes que tenham cara de ModelSim (vco, vsim, linuxaloem...)
        tar -tzf "$a" 2>/dev/null | grep -qE '(^|/)(vco|linuxaloem/|linux/vsim|modelsim\.ini)' \
            && extract_component "$a"
    done
    MS="$(find_ms)"
    # Caminho B: o instalador gráfico da Altera, com a correção do _md5
    if [ -z "$MS" ] && [ -d "$SRC/altera_installer/bin" ]; then
        IBIN="$SRC/altera_installer/bin"
        fix_execstack "$SRC/altera_installer"
        quarantine_glibc "$IBIN"
        echo
        echo "  Caminho B: abrindo o instalador gráfico da Altera."
        echo "  ${c_b}>>> Quando ele perguntar a pasta de instalação, use:  $DEST  <<<${c_0}"
        ( cd "$SRC" && LD_LIBRARY_PATH="$IBIN" ./altera_installer/bin/altera_installer_gui ) \
            || warn "o instalador gráfico terminou com erro"
        MS="$(find_ms)"
    fi
fi
[ -n "$MS" ] || die "Não consegui instalar o ModelSim em $DEST.
    Mande as linhas de 'Conteúdo do pacote' acima para eu ajustar o script."
VCODIR="$(find_vcodir "$MS")"
[ -n "$VCODIR" ] || die "Achei $MS/vco, mas nenhum vsim em linuxaloem/ ou linux/."
chmod -R u+rwX "$MS" 2>/dev/null
ok "ModelSim em $MS (binários em $VCODIR/)"

# ----------------------------- 4. correções ---------------------------------
step "4/6  Corrigindo o ModelSim para o Ubuntu 26.04"
# (a) O script vco só conhece kernels 2.x/3.x; no kernel 6 ele procura uma pasta
#     "linux_rh60" que não existe. Aponta esse caso para a pasta certa.
if grep -q 'vco="linux_rh60"' "$MS/vco" && [ ! -d "$MS/linux_rh60" ]; then
    [ -e "$MS/vco.original" ] || cp -p "$MS/vco" "$MS/vco.original"
    sed -i "s/vco=\"linux_rh60\"/vco=\"$VCODIR\"/" "$MS/vco"
    ok "vco corrigido (kernel novo -> $VCODIR)"
else
    ok "vco não precisa de correção"
fi
# (b) bibliotecas com pilha executável
fix_execstack "$MS"

# (c) Fontes: o Tk do ModelSim trava (Segmentation fault) com a freetype nova.
#     Solução conhecida: usar a freetype 2.4.12 de 32 bits só para o ModelSim. A
#     fontconfig do Ubuntu 26.04 exige uma freetype nova (e é ligada com BIND_NOW),
#     então vai junto uma fontconfig antiga (2.11.94, Ubuntu 16.04). Nada disso é
#     instalado no sistema: fica só em $MS/compat-lib32.
COMPAT="$MS/compat-lib32"
mkdir -p "$COMPAT"
get_lib() {   # url sha256 caminho-no-deb nome-final
    [ -f "$COMPAT/$4" ] && return 0
    local tmp; tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/p.deb" "$1" 2>/dev/null || wget -q -O "$tmp/p.deb" "$1"; then
        if [ "$(sha256sum "$tmp/p.deb" | cut -d' ' -f1)" = "$2" ]; then
            dpkg-deb -x "$tmp/p.deb" "$tmp/x" && cp "$tmp/x/$3" "$COMPAT/$4" \
                && echo "    $4 instalada em $COMPAT"
        else
            warn "checksum de $(basename "$1") não confere; não instalei"
        fi
    else
        warn "não consegui baixar $(basename "$1") (sem internet?). A interface gráfica pode travar; o modo texto (vsim -c) funciona."
    fi
    rm -rf "$tmp"
}
get_lib http://old-releases.ubuntu.com/ubuntu/pool/main/f/freetype/libfreetype6_2.4.12-0ubuntu1.1_i386.deb \
        bbb4079ad44c6cced35ecbbae8564d8cb6725756271857f29338f9237efe678d \
        usr/lib/i386-linux-gnu/libfreetype.so.6.10.1 libfreetype.so.6
get_lib http://archive.ubuntu.com/ubuntu/pool/main/f/fontconfig/libfontconfig1_2.11.94-0ubuntu1.1_i386.deb \
        127e14e234457576185a79732809483d91813fa6bc61d99bc7b56495c7ebfdc8 \
        usr/lib/i386-linux-gnu/libfontconfig.so.1.9.0 libfontconfig.so.1
L=/usr/lib/i386-linux-gnu
[ -e "$L/libncurses.so.6" ] && ln -sfn "$L/libncurses.so.6" "$COMPAT/libncurses.so.5"
[ -e "$L/libtinfo.so.6" ]   && ln -sfn "$L/libtinfo.so.6"   "$COMPAT/libtinfo.so.5"
# Configuração de fontes própria (a fontconfig antiga não entende o fonts.conf novo)
cat > "$COMPAT/fonts.conf" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <dir>/usr/share/fonts</dir>
  <dir>/usr/local/share/fonts</dir>
  <dir prefix="xdg">fonts</dir>
  <cachedir prefix="xdg">fontconfig-modelsim11</cachedir>
  <alias><family>sans-serif</family><prefer><family>DejaVu Sans</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>DejaVu Sans Mono</family></prefer></alias>
</fontconfig>
EOF
ok "Bibliotecas de compatibilidade em $COMPAT"

# ----------------------------- 5. atalhos -----------------------------------
step "5/6  Criando os comandos (vlib, vcom, vlog, vsim...) e o atalho no menu"
# Cada comando chama o binário direto (sem passar pelo vco), com as libs certas.
WRAP="$MS/bin-ubuntu"
rm -rf "$WRAP"; mkdir -p "$WRAP"
n=0
for t in vsim vlib vcom vlog vmap vdel vdir vmake vcd2wlf wlf2vcd wlf2log wlfman vcover qverilog sccom; do
    [ -x "$MS/$VCODIR/$t" ] || continue
    cat > "$WRAP/$t" <<EOF
#!/usr/bin/env bash
# Gerado por instalar_modelsim11.sh
export GLIBC_TUNABLES="glibc.rtld.execstack=2"
export LD_LIBRARY_PATH="$COMPAT\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export FONTCONFIG_FILE="$COMPAT/fonts.conf"
export LC_NUMERIC=C
exec "$MS/$VCODIR/$t" "\$@"
EOF
    chmod +x "$WRAP/$t"; n=$((n+1))
done
[ "$n" -gt 0 ] || die "nenhum executável encontrado em $MS/$VCODIR"
# Atalho principal: modelsim11 (abre a interface) e links no PATH
ln -sfn "$WRAP/vsim" "$WRAP/modelsim11"
mkdir -p "$HOME/.local/bin"
for t in "$WRAP"/*; do ln -sfn "$t" "$HOME/.local/bin/$(basename "$t")"; done
ok "$n comandos em $WRAP (também em ~/.local/bin)"

ICON="$(find "$MS" -maxdepth 3 -iname '*.png' \( -iname '*modelsim*' -o -iname '*logo*' \) 2>/dev/null | head -1)"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=ModelSim-Altera 11.0
Comment=Simulador VHDL/Verilog (Starter Edition)
Exec=$WRAP/vsim
Path=$HOME
Icon=${ICON:-applications-science}
Terminal=false
Categories=Development;Electronics;
EOF
update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true
ok "Atalho no menu: 'ModelSim-Altera 11.0'"

# ----------------------------- 6. teste -------------------------------------
step "6/6  Testando pela linha de comando"
"$WRAP/vsim" -version 2>&1 | sed 's/^/    /'
T="$(mktemp -d)"
cat > "$T/tb.vhd" <<'EOF'
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity tb is end entity;
architecture sim of tb is
    signal clk : std_logic := '0';
    signal q   : unsigned(3 downto 0) := (others => '0');
begin
    clk <= not clk after 5 ns;
    process (clk) begin
        if rising_edge(clk) then q <= q + 1; end if;
    end process;
    process begin
        wait for 100 ns;
        assert q = 10 report "contador errado" severity failure;
        report "TESTE OK";
        wait;
    end process;
end architecture;
EOF
out="$( cd "$T" && "$WRAP/vlib" work && "$WRAP/vcom" -93 tb.vhd \
        && "$WRAP/vsim" -c tb -do "run 120 ns; quit -f" 2>&1 )"
echo "$out" | tail -15 | sed 's/^/    /'
rm -rf "$T"
if echo "$out" | grep -q "TESTE OK"; then
    ok "vlib + vcom + vsim -c funcionando"
else
    die "o teste em linha de comando falhou (saída acima)."
fi

cat <<EOF

${c_ok}${c_b}Pronto!${c_0} Abra pelo menu 'ModelSim-Altera 11.0' ou rode:  vsim
Pela linha de comando, sem abrir janela:

    vlib work
    vcom -93 meu_circuito.vhd tb_meu_circuito.vhd
    vsim -c tb_meu_circuito -do "run 1 us; quit -f"

Para o Quartus chamar o ModelSim (Tools > Run EDA Simulation Tool):
  Tools > Options > EDA Tool Options > ModelSim-Altera:  $WRAP
(Se 'vsim' não for encontrado, feche e abra o terminal de novo.)
EOF
