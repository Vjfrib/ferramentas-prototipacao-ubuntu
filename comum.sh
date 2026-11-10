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
