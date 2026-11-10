#!/usr/bin/env bash
# =============================================================================
#  instalar.sh  -  menu para instalar as ferramentas de FPGA no Ubuntu
#
#    1) Quartus II 11.0 Web Edition   -> instalar_quartus11.sh
#    2) GHDL + GTKWave                -> instalar_ghdl_gtkwave.sh
#    3) ModelSim-Altera 11.0 Starter  -> instalar_modelsim11.sh
#
#  Uso:   bash instalar.sh
#  Usa o whiptail (já vem no Ubuntu). Sem ele, usa o dialog ou um menu de texto.
#  Cada script também pode ser rodado sozinho.
# =============================================================================

set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TITULO="Ferramentas FPGA (Cyclone I / Ubuntu)"

if [ "$(id -u)" -eq 0 ]; then
    echo "Não rode com sudo. Rode como usuário normal: bash $0"
    exit 1
fi

if command -v whiptail >/dev/null; then UI=whiptail
elif command -v dialog >/dev/null; then UI=dialog
else UI=texto
fi

# ----------------------------- estado de cada item --------------------------
st_quartus() { [ -x "$HOME/altera/11.0/quartus11" ] && echo "instalado" || echo "-"; }
st_ghdl() {
    if command -v ghdl >/dev/null && command -v gtkwave >/dev/null; then echo "instalado"
    elif command -v ghdl >/dev/null || command -v gtkwave >/dev/null; then echo "parcial"
    else echo "-"; fi
}
st_modelsim() {
    [ -n "$(find "$HOME/altera/11.0" -maxdepth 3 -path '*bin-ubuntu/vsim' 2>/dev/null | head -1)" ] \
        && echo "instalado" || echo "-"
}

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

status() {
    local txt
    txt="Quartus II 11.0 .......... $(st_quartus)
GHDL + GTKWave ........... $(st_ghdl)
ModelSim-Altera 11.0 ..... $(st_modelsim)

Logs:
  ~/quartus11-install.log
  ~/ghdl-gtkwave-install.log
  ~/modelsim11-install.log"
    if [ "$UI" = texto ]; then echo; echo "$txt"; echo; read -r -p "Enter... " _
    else "$UI" --title "Status" --msgbox "$txt" 16 60; fi
}

ajuda() {
    local txt="Antes de instalar, baixe da Intel/Altera e deixe em ~/Downloads:

 - Quartus:  11.0_quartus_free_linux.sh
 - ModelSim: 11.0_modelsim_ase_linux.sh  (ModelSim-Altera Starter)

O GHDL e o GTKWave vêm do apt, não precisa baixar nada.

Os scripts pedem a senha do sudo quando precisam, podem ser
rodados de novo sem problema e não removem nenhum pacote.
A FPGA alvo é a Cyclone I EP1C3T144C8N, por isso o Quartus 11.0."
    if [ "$UI" = texto ]; then echo; echo "$txt"; echo; read -r -p "Enter... " _
    else "$UI" --title "Antes de começar" --msgbox "$txt" 18 70; fi
}

menu() {
    local q g m
    q="$(st_quartus)"; g="$(st_ghdl)"; m="$(st_modelsim)"
    if [ "$UI" = texto ]; then
        echo
        echo "  $TITULO"
        echo "  1) Instalar Quartus II 11.0          [$q]"
        echo "  2) Instalar GHDL + GTKWave           [$g]"
        echo "  3) Instalar ModelSim-Altera 11.0     [$m]"
        echo "  4) Ver o que já está instalado"
        echo "  5) Antes de começar (o que baixar)"
        echo "  0) Sair"
        read -r -p "  Escolha: " ESC
    else
        ESC="$("$UI" --title "$TITULO" --menu "Escolha o que instalar:" 17 66 6 \
            1 "Instalar Quartus II 11.0         [$q]" \
            2 "Instalar GHDL + GTKWave          [$g]" \
            3 "Instalar ModelSim-Altera 11.0    [$m]" \
            4 "Ver o que já está instalado" \
            5 "Antes de começar (o que baixar)" \
            0 "Sair" 3>&1 1>&2 2>&3)" || ESC=0
    fi
}

while true; do
    menu
    case "$ESC" in
        1) rodar instalar_quartus11.sh    "Quartus II 11.0" ;;
        2) rodar instalar_ghdl_gtkwave.sh "GHDL + GTKWave" ;;
        3) rodar instalar_modelsim11.sh   "ModelSim-Altera 11.0" ;;
        4) status ;;
        5) ajuda ;;
        0|"") clear; exit 0 ;;
        *) ;;
    esac
done
