#!/usr/bin/env bash
# =============================================================================
#  instalar_kicad.sh  -  KiCad (esquemático e placa de circuito impresso)
#
#  Uso:   bash instalar_kicad.sh
#  Usa o pacote do próprio Ubuntu, com as bibliotecas de símbolos e footprints.
#  Os modelos 3D (kicad-packages3d, alguns GB) só são instalados com
#      KICAD_3D=1 bash instalar_kicad.sh
#  Log: ~/kicad-install.log
# =============================================================================
set -u
. "$(dirname "${BASH_SOURCE[0]}")/comum.sh"
inicio kicad-install.log

step "1/3  Escolhendo de onde instalar"
if tem_pacote_apt kicad; then
    ok "kicad disponível no apt ($(apt-cache policy kicad | awk '/Candidato|Candidate/{print $2}'))"
else
    die "o pacote kicad não foi encontrado no apt. Habilite o repositório 'universe':
    sudo add-apt-repository universe && sudo apt update"
fi

step "2/3  Instalando o KiCad e as bibliotecas de símbolos e footprints"
PKGS=(kicad)
for p in kicad-symbols kicad-footprints kicad-templates kicad-libraries; do
    tem_pacote_apt "$p" && PKGS+=("$p")
done
if [ "${KICAD_3D:-0}" = 1 ] && tem_pacote_apt kicad-packages3d; then
    PKGS+=(kicad-packages3d)
fi
# --no-install-recommends evita puxar os modelos 3D (vários GB) sem você pedir
falta=()
for p in "${PKGS[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || falta+=("$p"); done
if [ "${#falta[@]}" -gt 0 ]; then
    echo "  Pedindo a senha do sudo para instalar: ${falta[*]}"
    sudo apt-get update || warn "apt-get update teve erros (seguindo mesmo assim)"
    sudo apt-get install -y --no-install-recommends "${falta[@]}" \
        || die "apt-get install falhou (veja acima). Nada foi removido."
fi
ok "pacotes: ${PKGS[*]}"

step "3/3  Conferindo"
command -v kicad >/dev/null || die "o comando kicad não ficou disponível."
ok "KiCad $(dpkg-query -W -f='${Version}' kicad 2>/dev/null)"
[ "${KICAD_3D:-0}" = 1 ] || echo "  (Modelos 3D não instalados. Para ter: KICAD_3D=1 bash $0)"
echo
echo "${c_ok}${c_b}Pronto!${c_0} Abra o KiCad pelo menu de aplicativos ou rode:  kicad"
