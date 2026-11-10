#!/usr/bin/env bash
# =============================================================================
#  instalar_prusaslicer.sh  -  PrusaSlicer (fatiador para impressão 3D)
#
#  Uso:   bash instalar_prusaslicer.sh
#  Instala pelo Flathub, que é por onde a Prusa distribui a versão atual para
#  Linux. Se o Flathub falhar, usa o pacote do Ubuntu (prusa-slicer, mais antigo).
#  Log: ~/prusaslicer-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"
inicio prusaslicer-install.log
APP=com.prusa3d.PrusaSlicer

step "1/2  Instalando o PrusaSlicer (Flathub)"
if flathub_instalar "$APP"; then
    VIA=flatpak
else
    warn "o Flathub falhou; tentando o pacote prusa-slicer do Ubuntu"
    tem_pacote_apt prusa-slicer || die "prusa-slicer também não está no apt."
    apt_instalar prusa-slicer
    VIA=apt
fi

step "2/2  Conferindo"
if [ "$VIA" = flatpak ]; then
    ok "PrusaSlicer $(flatpak info "$APP" 2>/dev/null | awk '/Version:|Versão:/{print $2}') (Flathub)"
    CMD="flatpak run $APP"
    echo "  Obs.: o ícone do menu aparece depois de sair e entrar de novo na sessão."
else
    ok "PrusaSlicer $(dpkg-query -W -f='${Version}' prusa-slicer 2>/dev/null) (apt)"
    CMD=prusa-slicer
fi
echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra o PrusaSlicer pelo menu de aplicativos ou rode:  $CMD"
