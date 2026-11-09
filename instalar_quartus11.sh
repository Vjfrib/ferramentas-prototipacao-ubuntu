#!/usr/bin/env bash
# =============================================================================
#  instalar_quartus11.sh
#  Instala o Quartus II 11.0 Web Edition (32 bits) no Ubuntu 26.04 x86_64
#  para usar a FPGA Cyclone I EP1C3T144C8N com USB-Blaster.
#
#  Uso:   bash instalar_quartus11.sh
#  Pode rodar quantas vezes quiser: o que já foi feito é pulado.
#  NÃO roda "apt autoremove" e não remove nenhum pacote.
#  Log completo: ~/quartus11-install.log
# =============================================================================

set -u

# ----------------------------- configuração ---------------------------------
SH_FILE="${QUARTUS_SH:-$HOME/Downloads/11.0_quartus_free_linux.sh}"
SRC_DIR="${QUARTUS_SRC:-$HOME/Downloads/11.0_quartus_free_linux}"
DEST="$HOME/altera/11.0"
COMPAT="$DEST/compat-lib32"
LOG="$HOME/quartus11-install.log"
LAUNCHER="$DEST/quartus11"
DESKTOP="$HOME/.local/share/applications/quartus11.desktop"
UDEV_RULE="/etc/udev/rules.d/51-usbblaster.rules"
# glibc >= 2.41 recusa carregar .so antigas que pedem "pilha executável".
# É isso que faz o _hashlib.so do instalador falhar e virar "No module named _md5".
export GLIBC_TUNABLES="glibc.rtld.execstack=2"

exec > >(tee -a "$LOG") 2>&1

# ----------------------------- utilidades -----------------------------------
c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_b=$'\e[1m'; c_0=$'\e[0m'
step() { echo; echo "${c_b}==> $*${c_0}"; }
ok()   { echo "${c_ok}  [ok]${c_0} $*"; }
warn() { echo "${c_warn}  [aviso]${c_0} $*"; }
die()  {
    echo
    echo "${c_err}${c_b}ERRO: $*${c_0}"
    echo "O log completo está em: $LOG"
    echo "Mande esse arquivo (ou as últimas ~80 linhas dele) pra quem estiver te ajudando."
    exit 1
}

echo
echo "################  $(date '+%F %T')  instalar_quartus11.sh  ################"

# ----------------------------- verificações ---------------------------------
step "Verificando o ambiente"
[ "$(id -u)" -ne 0 ] || die "Não rode com sudo. Rode como usuário normal: bash $0  (o script pede a senha quando precisar)."
[ "$(uname -m)" = "x86_64" ] || die "Este script é para x86_64 (detectado: $(uname -m))."
command -v apt-get >/dev/null || die "apt-get não encontrado; este script é para Ubuntu/Debian."
command -v python3 >/dev/null || die "python3 não encontrado (vem por padrão no Ubuntu). Instale com: sudo apt install python3"

if [ ! -d "$SRC_DIR/altera_installer" ]; then
    if [ -f "$SH_FILE" ]; then
        warn "Pasta extraída não encontrada; extraindo $SH_FILE (demora ~2 min)..."
        chmod +x "$SH_FILE"
        ( cd "$(dirname "$SH_FILE")" && "$SH_FILE" --noexec --keep ) || die "Falha ao extrair $SH_FILE"
    fi
fi
[ -d "$SRC_DIR/altera_installer" ] || die "Não achei $SRC_DIR/altera_installer. Extraia antes com:
    cd ~/Downloads && ./11.0_quartus_free_linux.sh --noexec --keep"
ok "Instalador extraído em $SRC_DIR"
ok "Destino: $DEST"

echo "  Pedindo a senha do sudo uma vez (para apt, udev e /etc/jtagd)..."
sudo -v || die "sudo falhou."
# mantém o sudo vivo enquanto o script roda
( while true; do sudo -n true 2>/dev/null; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null' EXIT

# ----------------------------- 1. pacotes -----------------------------------
step "1/7  Bibliotecas de 32 bits (i386)"
if ! dpkg --print-foreign-architectures | grep -qx i386; then
    sudo dpkg --add-architecture i386 || die "dpkg --add-architecture i386 falhou"
fi
sudo apt-get update || warn "apt-get update teve erros (seguindo mesmo assim)"

WANT_I386="libc6 libstdc++6 libgcc-s1 zlib1g libbz2-1.0 libuuid1 libexpat1
 libx11-6 libxext6 libxrender1 libxft2 libxtst6 libxi6 libsm6 libice6 libxau6
 libxdmcp6 libxrandr2 libxcursor1 libxinerama1 libxfixes3 libxt6 libxmu6 libxcb1
 libfreetype6 libfontconfig1 libpng16-16t64 libpng16-16
 libglib2.0-0t64 libglib2.0-0
 libncurses6 libncursesw6 libtinfo6
 libudev1 libusb-0.1-4 libusb-1.0-0"
WANT_NATIVE="file binutils xfonts-base xfonts-75dpi xfonts-100dpi"

TO_INSTALL=()
for p in $WANT_I386; do
    if apt-cache show "$p:i386" >/dev/null 2>&1; then TO_INSTALL+=("$p:i386"); fi
done
for p in $WANT_NATIVE; do
    if apt-cache show "$p" >/dev/null 2>&1; then TO_INSTALL+=("$p"); fi
done
echo "  Pacotes: ${TO_INSTALL[*]}"
sudo apt-get install -y --no-install-recommends "${TO_INSTALL[@]}" \
    || die "apt-get install falhou (veja acima qual pacote). Nada foi removido."
[ -e /lib/ld-linux.so.2 ] || die "/lib/ld-linux.so.2 não existe mesmo após instalar libc6:i386."
ok "Bibliotecas i386 instaladas"

# ----------------------------- corretor de ELF ------------------------------
# Remove a flag "pilha executável" (PT_GNU_STACK com PF_X) de bibliotecas antigas.
# O Ubuntu 26.04 (glibc 2.43) se recusa a carregá-las via dlopen, e é por isso que
# o _hashlib.so do instalador falha e o Python cai no erro "No module named _md5".
# Idempotente: só mexe em arquivos que ainda têm a flag.
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
                    if struct.unpack_from('<H', h, 16)[0] != 3:   # só ET_DYN (.so)
                        continue
                    if is64:
                        phoff, = struct.unpack_from('<Q', h, 32)
                        phentsize, phnum = struct.unpack_from('<HH', h, 54)
                        flag_off = 4
                    else:
                        phoff, = struct.unpack_from('<I', h, 28)
                        phentsize, phnum = struct.unpack_from('<HH', h, 42)
                        flag_off = 24
                    for i in range(phnum):
                        off = phoff + i * phentsize
                        f.seek(off)
                        ph = f.read(phentsize)
                        if len(ph) < flag_off + 4:
                            break
                        if struct.unpack_from('<I', ph, 0)[0] != PT_GNU_STACK:
                            continue
                        flags, = struct.unpack_from('<I', ph, flag_off)
                        if flags & PF_X:
                            f.seek(off + flag_off)
                            f.write(struct.pack('<I', flags & ~PF_X))
                            fixed += 1
                            print('    pilha executável removida:', p)
            except (PermissionError, OSError):
                pass
print('    total de bibliotecas corrigidas nesta passada:', fixed)
PY
}

# ----------------------------- compat libs ----------------------------------
make_compat() {
    mkdir -p "$COMPAT"
    local L=/usr/lib/i386-linux-gnu
    link() { [ -e "$L/$2" ] && ln -sfn "$L/$2" "$COMPAT/$1"; }
    link libudev.so.0     libudev.so.1       # jtagd antigo procura libudev.so.0
    link libncurses.so.5  libncurses.so.6
    link libtinfo.so.5    libtinfo.so.6
    link libpng12.so.0    libpng16.so.16     # só é usado se o Quartus não trouxer a dele
    true
}

# ----------------------------- 2. instalador --------------------------------
step "2/7  Corrigindo as bibliotecas do instalador (causa do erro _md5)"
fix_execstack "$SRC_DIR/altera_installer"
IBIN="$SRC_DIR/altera_installer/bin"

# Pedaços da glibc de 2011 que vieram junto (libresolv, libutil...) pedem símbolos
# internos (ex.: __res_maybe_init@GLIBC_PRIVATE) que a glibc 2.43 não tem mais.
# Resultado: _hashlib.so não carrega -> "No module named _md5".
# Correção: tirar essas cópias do caminho para usar as do sistema (i386).
quarantine_glibc() {
    local dir="$1" q="$1/_glibc_antiga_desativada" moved=0
    for f in "$dir"/libc.so.* "$dir"/libm.so.* "$dir"/libdl.so.* "$dir"/libpthread.so.* \
             "$dir"/librt.so.* "$dir"/libresolv.so.* "$dir"/libutil.so.* "$dir"/libnsl.so.* \
             "$dir"/libcrypt.so.* "$dir"/ld-linux.so.*; do
        [ -e "$f" ] || [ -L "$f" ] || continue
        mkdir -p "$q"; mv -f "$f" "$q/"; moved=$((moved+1))
        echo "    desativada (usa a do sistema): $(basename "$f")"
    done
    [ "$moved" -gt 0 ] || echo "    nenhuma lib da glibc antiga em $dir"
}
quarantine_glibc "$IBIN"
if [ -f "$IBIN/_hashlib.so" ]; then
    echo "  Diagnóstico do _hashlib.so (símbolos/libs faltando):"
    LD_LIBRARY_PATH="$IBIN" ldd -r "$IBIN/_hashlib.so" 2>&1 | grep -Ei 'not found|undefined|error' \
        | sed 's/^/    /' || echo "    nada faltando"
fi

quartus_installed() { [ -n "$(find "$DEST" -maxdepth 4 -type f -name quartus_sh 2>/dev/null | head -1)" ]; }

# ----------------------------- 3. instalação --------------------------------
step "3/7  Instalando o Quartus II 11.0 em $DEST"
mkdir -p "$DEST"
make_compat

if quartus_installed; then
    ok "Quartus já está instalado em $DEST (pulando)"
else
    echo "  Conteúdo do pacote extraído (para diagnóstico):"
    find "$SRC_DIR" -maxdepth 3 -not -path '*/altera_installer/*' \( -type f -size +1M -o -type d \) \
        -printf '    %10s  %P\n' 2>/dev/null | head -50

    # --- Caminho A: extrair os pacotes (tar) direto, sem o instalador Python ---
    mapfile -t ARCHIVES < <(find "$SRC_DIR" -not -path '*/altera_installer/*' -type f \
        \( -name '*.tar' -o -name '*.tar.gz' -o -name '*.tgz' -o -name '*.tar.bz2' \
           -o -name '*.tbz2' -o -name '*.tar.xz' -o -name '*.qdz' \) 2>/dev/null | sort)
    # Formato do 11.0: linux_installer/quartus_free/*.gz (cada um é um tar.gz)
    QF_DIR="$(find "$SRC_DIR" -maxdepth 3 -type d -path '*linux_installer/quartus_free' | head -1)"
    if [ -n "$QF_DIR" ]; then
        echo "  Caminho A: extraindo os pacotes de $QF_DIR direto (sem o instalador Python)"
        for a in "$QF_DIR"/*.gz; do
            [ -f "$a" ] || continue
            mark="$DEST/.extraido_$(basename "$a")"
            [ -e "$mark" ] && { ok "já extraído: $(basename "$a")"; continue; }
            first="$(tar -tzf "$a" 2>/dev/null | sed 's#^\./##' | grep -v '^$' | head -1)"
            if [ -z "$first" ]; then
                warn "$(basename "$a") não é tar.gz ($(file -b "$a" | cut -c1-60)); pulando"
                continue
            fi
            case "$first" in
                quartus/*|quartus|nios2eds*|ip/*|modelsim*) target="$DEST" ;;
                *) target="$DEST/quartus" ;;
            esac
            mkdir -p "$target"
            echo "    extraindo $(basename "$a") ($(du -h "$a" | cut -f1)) em $target ..."
            if tar -xzf "$a" -C "$target"; then touch "$mark"; else warn "falha ao extrair $(basename "$a")"; fi
        done
    fi
    if [ "${#ARCHIVES[@]}" -gt 0 ]; then
        echo "  Caminho A: encontrei ${#ARCHIVES[@]} pacote(s); extraindo direto em $DEST"
        for a in "${ARCHIVES[@]}"; do
            mark="$DEST/.extraido_$(basename "$a")"
            [ -e "$mark" ] && { ok "já extraído: $(basename "$a")"; continue; }
            echo "    extraindo $(basename "$a") ($(du -h "$a" | cut -f1))..."
            if tar -xf "$a" -C "$DEST" 2>/dev/null; then
                touch "$mark"
            elif command -v unzip >/dev/null && unzip -oq "$a" -d "$DEST" 2>/dev/null; then
                touch "$mark"
            else
                warn "não consegui abrir $(basename "$a") ($(file -b "$a" | cut -c1-60))"
            fi
        done
    else
        true
    fi

    # --- Caminho B: o instalador original, agora com a correção aplicada ---
    if ! quartus_installed; then
        HDR="$(head -c 40000 "$SH_FILE" 2>/dev/null | tr -d '\0')"
        SCRIPT="$(printf '%s\n' "$HDR" | sed -n 's/^script="\(.*\)"$/\1/p' | head -1)"
        SARGS="$(printf '%s\n' "$HDR" | sed -n 's/^scriptargs="\(.*\)"$/\1/p' | head -1)"
        [ -n "$SCRIPT" ] || SCRIPT="./altera_installer/bin/altera_installer_gui"
        echo
        echo "  Caminho B: abrindo o instalador gráfico da Altera com a correção."
        echo "  ${c_b}>>> Quando ele perguntar a pasta de instalação, use:  $DEST  <<<${c_0}"
        echo "  (comando: $SCRIPT $SARGS)"
        ( cd "$SRC_DIR" && LD_LIBRARY_PATH="$IBIN" $SCRIPT $SARGS )
        rc=$?
        echo "  instalador terminou com código $rc"
        # se o usuário escolheu outra pasta, tenta achar
        if ! quartus_installed; then
            other="$(find "$HOME/altera" "$HOME/altera11.0" -maxdepth 5 -type f -name quartus_sh 2>/dev/null | head -1)"
            if [ -n "$other" ]; then
                warn "Quartus instalado em outro lugar: $other"
                warn "Vou usar esse local. (Se quiser, mova a pasta para $DEST e rode o script de novo.)"
                DEST="$(cd "$(dirname "$other")/../.." && pwd)"
            fi
        fi
    fi
fi

if ! quartus_installed; then
    echo
    echo "  --- Diagnóstico ---"
    echo "  Teste isolado do instalador:"
    ( cd "$SRC_DIR" && LD_LIBRARY_PATH="$IBIN" ./altera_installer/bin/altera_installer_gui --help 2>&1 | tail -15 | sed 's/^/    /' )
    echo "  Ainda há bibliotecas com pilha executável?"
    command -v readelf >/dev/null && for f in "$IBIN"/*.so*; do
        readelf -lW "$f" 2>/dev/null | grep -q 'GNU_STACK.*RWE' && echo "    $f"
    done
    die "Não consegui instalar o Quartus em $DEST (nem extraindo os pacotes, nem pelo instalador)."
fi

QSH="$(find "$DEST" -maxdepth 4 -type f -name quartus_sh | head -1)"
QROOT="$(cd "$(dirname "$QSH")/.." && pwd)"     # .../quartus

# O instalador da Altera cria a pasta quartus/bin no fim (atalhos que passam pelo
# adm/qenv.sh). Como pulamos o instalador, o script cria essa pasta.
#   modo qenv:   bin/<ferramenta> carrega adm/qenv.sh com bash (jeito oficial)
#   modo direto: bin/<ferramenta> chama linux/<ferramenta> direto (plano B)
make_bin() {
    local mode="$1" n=0 f t
    rm -rf "$QROOT/bin.gerado" ; mkdir -p "$QROOT/bin.gerado"
    for f in "$QROOT"/linux/*; do
        [ -f "$f" ] || continue
        case "$f" in *.so|*.so.*|*.txt|*.dat|*.ini) continue ;; esac
        [ "$(head -c4 "$f" 2>/dev/null | tr -d '\0')" = $'\x7fELF' ] || continue
        t="$(basename "$f")"
        if [ "$mode" = qenv ]; then
            cat > "$QROOT/bin.gerado/$t" <<EOF
#!/usr/bin/env bash
exec bash -c '. "\$0.qenv" "\$@"' "$QROOT/bin/$t" "\$@"
EOF
        else
            cat > "$QROOT/bin.gerado/$t" <<EOF
#!/usr/bin/env bash
export QUARTUS_ROOTDIR="$QROOT"
export LD_LIBRARY_PATH="$QROOT/linux:$COMPAT\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec "$QROOT/linux/$t" "\$@"
EOF
        fi
        chmod +x "$QROOT/bin.gerado/$t"; n=$((n+1))
    done
    [ "$n" -gt 0 ] || die "Não achei executáveis em $QROOT/linux."
    if [ "$mode" = qenv ]; then
        # "$0.qenv" -> aponta para o qenv.sh, e $0 continua sendo bin/<ferramenta>
        for t in "$QROOT"/bin.gerado/*; do
            case "$t" in *.qenv) continue ;; esac
            ln -sfn "$QROOT/adm/qenv.sh" "$t.qenv"
        done
    fi
    if [ -d "$QROOT/bin" ] && [ ! -e "$QROOT/bin/.gerado_pelo_script" ]; then
        mv "$QROOT/bin" "$QROOT/bin.original.$(date +%s)"
    fi
    rm -rf "$QROOT/bin"; mv "$QROOT/bin.gerado" "$QROOT/bin"
    echo "$mode" > "$QROOT/bin/.gerado_pelo_script"
    echo "    pasta bin criada (modo $mode, $n ferramentas)"
}
if [ ! -e "$QROOT/bin/quartus" ]; then
    if [ -f "$QROOT/adm/qenv.sh" ]; then make_bin qenv; else make_bin direto; fi
fi
chmod -R u+rwX "$DEST" 2>/dev/null
find "$QROOT/bin" "$QROOT/linux" -maxdepth 1 -type f -exec chmod +x {} + 2>/dev/null
ok "Quartus encontrado em $QROOT"

# ----------------------------- 4. corrigir Quartus --------------------------
step "4/7  Corrigindo bibliotecas antigas do próprio Quartus"
fix_execstack "$DEST"
QLIB="$QROOT/linux"
quarantine_glibc "$QLIB"

echo "  Procurando bibliotecas ainda faltando (ldd)..."
QLIB="$QROOT/linux"
MISSING="$(
  for f in "$QLIB"/quartus "$QLIB"/quartus_sh "$QLIB"/quartus_map "$QLIB"/quartus_pgm "$QLIB"/jtagd "$QLIB"/*.so; do
      [ -f "$f" ] || continue
      LD_LIBRARY_PATH="$QLIB:$COMPAT" ldd "$f" 2>/dev/null | awk '/not found/{print $1}'
  done | sort -u
)"
if [ -n "$MISSING" ]; then
    warn "Bibliotecas não encontradas (o Quartus pode funcionar mesmo assim se forem opcionais):"
    echo "$MISSING" | sed 's/^/      /'
    echo "  Dica: procure o pacote com:  apt-file search <nome>  e instale com :i386 no final."
else
    ok "Nenhuma biblioteca faltando"
fi

# ----------------------------- 5. USB-Blaster ------------------------------
step "5/7  USB-Blaster (udev + jtagd)"
RULE='# Altera USB-Blaster / USB-Blaster II
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666", TAG+="uaccess"'
if [ "$(cat "$UDEV_RULE" 2>/dev/null)" != "$RULE" ]; then
    printf '%s\n' "$RULE" | sudo tee "$UDEV_RULE" >/dev/null
    sudo udevadm control --reload-rules && sudo udevadm trigger
fi
ok "Regra udev em $UDEV_RULE (replugue o USB-Blaster)"
if [ -f "$QLIB/pgm_parts.txt" ]; then
    sudo mkdir -p /etc/jtagd
    sudo cp -f "$QLIB/pgm_parts.txt" /etc/jtagd/jtagd.pgm_parts
    ok "/etc/jtagd/jtagd.pgm_parts copiado"
fi

# ----------------------------- 6. atalho ------------------------------------
step "6/7  Criando o atalho"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Gerado por instalar_quartus11.sh
export QUARTUS_ROOTDIR="$QROOT"
export QUARTUS_64BIT=0
export GLIBC_TUNABLES="glibc.rtld.execstack=2"
export LD_LIBRARY_PATH="$QLIB:$COMPAT\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export PATH="$QROOT/bin:\$PATH"
export LC_ALL=C          # o Quartus 11 se perde com locale pt_BR (vírgula decimal)
tool="\${1:-quartus}"
case "\$tool" in
  quartus|quartus_*|jtagd|jtagconfig|qmegawiz) shift 2>/dev/null || true ;;
  *) tool=quartus ;;
esac
exec "$QROOT/bin/\$tool" "\$@"
EOF
chmod +x "$LAUNCHER"
mkdir -p "$HOME/.local/bin"
ln -sfn "$LAUNCHER" "$HOME/.local/bin/quartus11"

ICON="$(find "$QROOT" -maxdepth 3 -iname '*.png' -path '*adm*' 2>/dev/null | head -1)"
[ -n "$ICON" ] || ICON="$(find "$QROOT" -maxdepth 4 -iname 'quartus*.png' 2>/dev/null | head -1)"
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Quartus II 11.0 Web Edition
Comment=Altera Quartus II 11.0 (Cyclone I)
Exec=$LAUNCHER %f
Icon=${ICON:-applications-engineering}
Terminal=false
Categories=Development;Electronics;
StartupNotify=true
EOF
update-desktop-database "$(dirname "$DESKTOP")" >/dev/null 2>&1 || true
ok "Atalho no menu: 'Quartus II 11.0 Web Edition'"
ok "Pelo terminal: quartus11   (ou $LAUNCHER)"

# ----------------------------- 7. teste -------------------------------------
step "7/7  Testando"
out="$("$LAUNCHER" quartus_sh --version 2>&1)"; rc=$?
if [ $rc -ne 0 ] && [ "$(cat "$QROOT/bin/.gerado_pelo_script" 2>/dev/null)" = qenv ]; then
    echo "$out" | tail -10 | sed 's/^/    /'
    warn "Pelo qenv.sh não funcionou; recriando a pasta bin no modo direto e testando de novo."
    make_bin direto
    out="$("$LAUNCHER" quartus_sh --version 2>&1)"; rc=$?
fi
if [ $rc -eq 0 ]; then
    echo "$out" | sed 's/^/    /'
    ok "quartus_sh funciona"
else
    echo "$out" | tail -25 | sed 's/^/    /'
    die "quartus_sh --version falhou (saída acima). A instalação está em $DEST; o problema é de execução."
fi
echo "  Famílias instaladas em common/devinfo:"
ls "$QROOT/common/devinfo" 2>/dev/null | tr '\n' ' ' | fold -w 76 | sed 's/^/    /'; echo
if [ -d "$QROOT/common/devinfo/cyclone" ]; then
    ok "Cyclone I (EP1C3T144C8N) presente"
else
    warn "A pasta common/devinfo/cyclone (Cyclone I) NÃO existe."
    QDA="$(find "$SRC_DIR" -maxdepth 3 -name cyclone.qda | head -1)"
    [ -n "$QDA" ] && echo "    O arquivo da Cyclone I está em $QDA ($(file -b "$QDA" | cut -c1-60))"
    echo "    Me mande essas linhas para eu ajustar a instalação dos dispositivos."
fi

echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra pelo menu 'Quartus II 11.0 Web Edition' ou rode:  quartus11"
echo "Para gravar a FPGA: ligue o USB-Blaster e rode  quartus11 jtagconfig  para ver se ele aparece."
echo "(Se 'quartus11' não for encontrado, feche e abra o terminal de novo.)"
