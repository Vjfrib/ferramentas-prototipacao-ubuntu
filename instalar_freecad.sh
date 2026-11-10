#!/usr/bin/env bash
# =============================================================================
#  instalar_freecad.sh  -  FreeCAD (modelagem 3D paramétrica)
#
#  Uso:   bash instalar_freecad.sh
#  Instala pelo Flathub (versão oficial e atual do FreeCAD). Se o Flathub
#  falhar, usa o pacote do Ubuntu, quando existir (o 24.04, por exemplo, não tem).
#  Log: ~/freecad-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"
inicio freecad-install.log

step "1/2  Instalando o FreeCAD (Flathub)"
if flathub_instalar org.freecad.FreeCAD; then
    VIA=flatpak
else
    warn "o Flathub falhou; tentando o pacote freecad do Ubuntu"
    tem_pacote_apt freecad || die "freecad também não está disponível no apt."
    apt_instalar freecad
    VIA=apt
fi

step "2/2  Conferindo"
if [ "$VIA" = apt ]; then
    command -v freecad >/dev/null || die "o comando freecad não ficou disponível."
    ok "FreeCAD $(dpkg-query -W -f='${Version}' freecad 2>/dev/null) (apt)"
    CMD=freecad
else
    ok "FreeCAD $(flatpak info org.freecad.FreeCAD 2>/dev/null | awk '/Version:|Versão:/{print $2}') (Flathub)"
    CMD="flatpak run org.freecad.FreeCAD"
    echo "  Obs.: o ícone do menu aparece depois de sair e entrar de novo na sessão."
fi
echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra o FreeCAD pelo menu de aplicativos ou rode:  $CMD"
