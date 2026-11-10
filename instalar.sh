#!/usr/bin/env bash
# =============================================================================
#  instalar.sh  -  Instalação de ferramentas de prototipação no Ubuntu
#
#  Menu principal
#    FPGA
#      Quartus II 11.0 Web Edition    -> instalar_quartus11.sh
#      GHDL + GTKWave                 -> instalar_ghdl_gtkwave.sh
#      ModelSim-Altera 11.0 Starter   -> instalar_modelsim11.sh
#    Prototipação
#      KiCad                          -> instalar_kicad.sh
#      UGS (Universal Gcode Sender)   -> instalar_ugs.sh
#      FreeCAD                        -> instalar_freecad.sh
#      PrusaSlicer                    -> instalar_prusaslicer.sh
#
#  Uso:   bash instalar.sh
#  Usa o whiptail (já vem no Ubuntu). Sem ele, usa o dialog ou um menu de texto.
#  Cada script também pode ser rodado sozinho.
# =============================================================================

set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TITULO="Ferramentas de prototipação - Ubuntu"

if [ "$(id -u)" -eq 0 ]; then
    echo "Não rode com sudo. Rode como usuário normal: bash $0"
    exit 1
fi

if command -v whiptail >/dev/null; then UI=whiptail
elif command -v dialog >/dev/null; then UI=dialog
else UI=texto
fi

# ----------------------------- estado de cada item --------------------------
tem() { command -v "$1" >/dev/null 2>&1; }
tem_flatpak() { tem flatpak && flatpak info "$1" >/dev/null 2>&1; }
sim() { if "$@"; then echo "instalado"; else echo "-"; fi; }

st_quartus()  { sim test -x "$HOME/altera/11.0/quartus11"; }
st_ghdl() {
    if tem ghdl && tem gtkwave; then echo "instalado"
    elif tem ghdl || tem gtkwave; then echo "parcial"
    else echo "-"; fi
}
st_modelsim() { sim test -n "$(find "$HOME/altera/11.0" -maxdepth 3 -path '*bin-ubuntu/vsim' 2>/dev/null | head -1)"; }
st_kicad()    { sim tem kicad; }
st_ugs()      { sim test -x "$HOME/.local/opt/ugs/bin/ugsplatform"; }
st_freecad()  { if tem freecad || tem_flatpak org.freecad.FreeCAD; then echo "instalado"; else echo "-"; fi; }
st_prusa()    { if tem prusa-slicer || tem_flatpak com.prusa3d.PrusaSlicer; then echo "instalado"; else echo "-"; fi; }

# ----------------------------- telas ----------------------------------------
rodar() {   # rodar <script> <nome>
    clear
    echo "=== $2 ==="
    echo
    bash "$DIR/$1"
    local rc=$?
    echo
    if [ $rc -eq 0 ]; then echo ">>> $2: concluído."; else echo ">>> $2: terminou com erro (código $rc)."; fi
    read -r -p "Pressione Enter para voltar ao menu... " _
}

caixa() {   # caixa <título> <texto> <altura>
    if [ "$UI" = texto ]; then echo; echo "== $1 =="; echo "$2"; echo; read -r -p "Enter... " _
    else "$UI" --title "$1" --msgbox "$2" "$3" 72; fi
}

# escolher <título> <pergunta> tag "texto" tag "texto"...   -> resposta em ESC
escolher() {
    local titulo="$1" pergunta="$2"; shift 2
    if [ "$UI" = texto ]; then
        echo; echo "  $titulo"; echo "  $pergunta"
        while [ $# -gt 0 ]; do echo "    $1) $2"; shift 2; done
        read -r -p "  Escolha: " ESC
    else
        local n=$(( $# / 2 ))
        ESC="$("$UI" --title "$titulo" --menu "$pergunta" $((n + 9)) 70 "$n" "$@" 3>&1 1>&2 2>&3)" || ESC=0
    fi
}

status() {
    caixa "O que já está instalado" "FPGA
  Quartus II 11.0 .............. $(st_quartus)
  GHDL + GTKWave ............... $(st_ghdl)
  ModelSim-Altera 11.0 ......... $(st_modelsim)

Prototipação
  KiCad ........................ $(st_kicad)
  UGS (Universal Gcode Sender) . $(st_ugs)
  FreeCAD ...................... $(st_freecad)
  PrusaSlicer .................. $(st_prusa)

Os logs ficam na sua pasta pessoal (~/*-install.log)." 20
}

ajuda() {
    caixa "Antes de começar" "Quase tudo é baixado sozinho (apt, Flathub ou GitHub).
Só a parte da Altera precisa ser baixada antes, do site da Intel,
e deixada em ~/Downloads:

 - Quartus:  11.0_quartus_free_linux.sh
 - ModelSim: 11.0_modelsim_ase_linux.sh  (ModelSim-Altera Starter)

Os scripts pedem a senha do sudo quando precisam, podem ser
rodados de novo sem problema e não removem nenhum pacote." 16
}

menu_fpga() {
    while true; do
        escolher "FPGA" "Escolha o que instalar:" \
            1 "Quartus II 11.0                [$(st_quartus)]" \
            2 "GHDL + GTKWave                 [$(st_ghdl)]" \
            3 "ModelSim-Altera 11.0           [$(st_modelsim)]" \
            0 "Voltar"
        case "$ESC" in
            1) rodar instalar_quartus11.sh    "Quartus II 11.0" ;;
            2) rodar instalar_ghdl_gtkwave.sh "GHDL + GTKWave" ;;
            3) rodar instalar_modelsim11.sh   "ModelSim-Altera 11.0" ;;
            0|"") return ;;
        esac
    done
}

menu_proto() {
    while true; do
        escolher "Prototipação" "Escolha o que instalar:" \
            1 "KiCad (placas de circuito)     [$(st_kicad)]" \
            2 "UGS - Universal Gcode Sender   [$(st_ugs)]" \
            3 "FreeCAD (modelagem 3D)         [$(st_freecad)]" \
            4 "PrusaSlicer (impressão 3D)     [$(st_prusa)]" \
            5 "Instalar os quatro" \
            0 "Voltar"
        case "$ESC" in
            1) rodar instalar_kicad.sh       "KiCad" ;;
            2) rodar instalar_ugs.sh         "UGS (Universal Gcode Sender)" ;;
            3) rodar instalar_freecad.sh     "FreeCAD" ;;
            4) rodar instalar_prusaslicer.sh "PrusaSlicer" ;;
            5) clear
               for s in kicad ugs freecad prusaslicer; do
                   echo "=== $s ==="; bash "$DIR/instalar_$s.sh" || echo ">>> $s terminou com erro."
               done
               read -r -p "Pressione Enter para voltar ao menu... " _ ;;
            0|"") return ;;
        esac
    done
}

while true; do
    escolher "$TITULO" "Escolha uma categoria:" \
        1 "FPGA  (Quartus, GHDL/GTKWave, ModelSim)" \
        2 "Prototipação  (KiCad, UGS, FreeCAD, PrusaSlicer)" \
        3 "Ver o que já está instalado" \
        4 "Antes de começar (o que baixar)" \
        0 "Sair"
    case "$ESC" in
        1) menu_fpga ;;
        2) menu_proto ;;
        3) status ;;
        4) ajuda ;;
        0|"") clear; exit 0 ;;
    esac
done
