# shellcheck shell=bash
# =============================================================================
#  comum.sh  -  funções usadas pelos scripts de prototipação
#  (não é para rodar sozinho; os scripts fazem  . comum.sh)
# =============================================================================

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_b=$'\e[1m'; c_0=$'\e[0m'
step() { echo; echo "${c_b}==> $*${c_0}"; }
ok()   { echo "${c_ok}  [ok]${c_0} $*"; }
warn() { echo "${c_warn}  [aviso]${c_0} $*"; }
die()  { echo; echo "${c_err}${c_b}ERRO: $*${c_0}"; echo "Log completo: ${LOG:-}"; exit 1; }

# inicio <nome-do-log>: grava a saída no log e faz as verificações básicas
inicio() {
    LOG="$HOME/$1"
    exec > >(tee -a "$LOG") 2>&1
    echo
    echo "################  $(date '+%F %T')  $(basename "$0")  ################"
    [ "$(id -u)" -ne 0 ] || die "Não rode com sudo. Rode como usuário normal: bash $0  (o script pede a senha quando precisar)."
    command -v apt-get >/dev/null || die "apt-get não encontrado; este script é para Ubuntu/Debian."
}

# apt_instalar pacote...: instala só o que ainda não está instalado
apt_instalar() {
    local p falta=()
    for p in "$@"; do
        if dpkg -s "$p" >/dev/null 2>&1; then ok "$p já instalado"; else falta+=("$p"); fi
    done
    [ "${#falta[@]}" -eq 0 ] && return 0
    echo "  Pedindo a senha do sudo para instalar: ${falta[*]}"
    sudo apt-get update || warn "apt-get update teve erros (seguindo mesmo assim)"
    sudo apt-get install -y "${falta[@]}" || die "apt-get install falhou (veja acima). Nada foi removido."
}

# tem_pacote_apt nome: o pacote existe nos repositórios configurados?
tem_pacote_apt() {
    local c
    c="$(LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}')"
    [ -n "$c" ] && [ "$c" != "(none)" ]
}

# flathub_instalar id: instala um app do Flathub (instala o flatpak se faltar)
flathub_instalar() {
    apt_instalar flatpak
    if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
        sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
            || return 1
    fi
    if flatpak info "$1" >/dev/null 2>&1; then
        ok "$1 já instalado (flatpak)"; sudo flatpak update -y "$1" || true
    else
        sudo flatpak install -y --noninteractive flathub "$1" || return 1
    fi
}

# pasta de downloads do usuário (respeita o idioma: Downloads, Transferências...)
pasta_downloads() {
    local d
    d="$(xdg-user-dir DOWNLOAD 2>/dev/null || true)"
    [ -n "$d" ] && [ -d "$d" ] || d="$HOME/Downloads"
    echo "$d"
}

# esperar_download <nome> <link> <arquivo esperado> <função de busca> [observação]
#
# Para instaladores que precisam ser baixados à mão (Altera, por exemplo).
# Chama a função de busca; se ela não achar nada, mostra o link oficial e
# espera você baixar. Aí é só apertar Enter (procura de novo) ou colar/arrastar
# o caminho do arquivo no terminal. Resultado em ACHADO.
# Volta 1 se você digitar "s" ou se não houver terminal para perguntar.
esperar_download() {
    local nome="$1" link="$2" arq="$3" busca="$4" obs="${5:-}" r parcial
    ACHADO="$("$busca")"
    [ -n "$ACHADO" ] && return 0
    [ -r /dev/tty ] || return 1

    echo
    echo "${c_warn}${c_b}  Falta o instalador: $nome${c_0}"
    echo "  Baixe no site oficial (abra o link no navegador):"
    echo
    echo "      ${c_b}$link${c_0}"
    echo
    echo "  Arquivo: $arq"
    echo "  Deixe em $(pasta_downloads) (ou em qualquer pasta e cole o caminho aqui)."
    [ -n "$obs" ] && echo "$obs" | sed 's/^/  /'
    echo
    while true; do
        echo "  [Enter] já baixei, procurar de novo   [a] abrir o link   [s] sair"
        echo "  ...ou cole/arraste aqui o arquivo e aperte Enter."
        r=""
        read -r -p "  > " r </dev/tty || return 1
        # tira aspas e espaços que o terminal põe ao arrastar um arquivo
        r="${r#"${r%%[![:space:]]*}"}"; r="${r%"${r##*[![:space:]]}"}"
        r="${r#\'}"; r="${r%\'}"; r="${r#\"}"; r="${r%\"}"; r="${r#file://}"
        r="${r/#\~/$HOME}"
        case "$r" in
            s|S|sair|q) return 1 ;;
            a|A)
                if command -v xdg-open >/dev/null; then
                    xdg-open "$link" >/dev/null 2>&1 &
                    ok "abrindo o link no navegador"
                else
                    warn "xdg-open não encontrado; copie o link acima"
                fi ;;
            "")
                ACHADO="$("$busca")"
                [ -n "$ACHADO" ] && { ok "achei: $ACHADO"; return 0; }
                parcial="$(find "$(pasta_downloads)" -maxdepth 1 -type f \( -name '*.crdownload' -o -name '*.part' -o -name '*.download' \) 2>/dev/null | head -1)"
                if [ -n "$parcial" ]; then
                    warn "ainda tem download em andamento ($(basename "$parcial")). Espere terminar e aperte Enter."
                else
                    warn "ainda não achei em $(pasta_downloads)."
                fi ;;
            *)
                if [ -e "$r" ]; then
                    ACHADO="$(realpath "$r")"; ok "usando: $ACHADO"; return 0
                fi
                warn "não existe: $r" ;;
        esac
        echo
    done
}

# wine_instalar [32]: instala o Wine do próprio Ubuntu (apt). Não adiciona o
# repositório da WineHQ e não remove nada. Com "32", também o wine32:i386,
# que alguns programas (instaladores .NET, por exemplo) precisam.
wine_instalar() {
    local pk=(wine)
    tem_pacote_apt wine64 && pk+=(wine64)
    if [ "${1:-}" = 32 ]; then
        if ! dpkg --print-foreign-architectures | grep -qx i386; then
            echo "  Habilitando a arquitetura i386 (para o wine32)..."
            sudo dpkg --add-architecture i386 && sudo apt-get update \
                || warn "não consegui habilitar i386; seguindo só com o Wine 64 bits"
        fi
        tem_pacote_apt wine32:i386 && pk+=(wine32:i386)
    fi
    apt_instalar "${pk[@]}"
    command -v wine >/dev/null || die "o comando wine não ficou disponível depois do apt."
    ok "$(wine --version 2>/dev/null)"
}

# wine_versao_ok <maior> <menor>: o Wine instalado é pelo menos essa versão?
wine_versao_ok() {
    local v M m
    v="$(wine --version 2>/dev/null | sed -E 's/^wine-([0-9]+)\.([0-9]+).*/\1 \2/')"
    read -r M m <<< "$v"
    [ -n "${M:-}" ] || return 1
    [ "$M" -gt "$1" ] || { [ "$M" -eq "$1" ] && [ "${m:-0}" -ge "$2" ]; }
}

# icone_do_exe <arquivo.exe> <destino.png>: extrai o maior ícone do .exe (icoutils)
icone_do_exe() {
    command -v wrestool >/dev/null && command -v icotool >/dev/null || return 1
    local t; t="$(mktemp -d)"
    wrestool -x -t 14 "$1" -o "$t" 2>/dev/null
    local ico; ico="$(ls -S "$t"/*.ico 2>/dev/null | head -1)"
    [ -n "$ico" ] && icotool -x -o "$t" "$ico" 2>/dev/null
    local png; png="$(ls -S "$t"/*.png 2>/dev/null | head -1)"
    [ -n "$png" ] && mkdir -p "$(dirname "$2")" && cp "$png" "$2"
    local rc=$?; rm -rf "$t"; [ -n "$png" ] && return $rc || return 1
}
