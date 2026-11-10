#!/usr/bin/env bash
# =============================================================================
#  instalar_ghdl_gtkwave.sh
#  Instala o GHDL (simulador VHDL) e o GTKWave (visualizador de formas de onda)
#  pelos pacotes do Ubuntu e faz um teste rápido de simulação.
#
#  Uso:   bash instalar_ghdl_gtkwave.sh
#  Pode rodar quantas vezes quiser. Não remove nenhum pacote.
#  Log completo: ~/ghdl-gtkwave-install.log
# =============================================================================

set -u

LOG="$HOME/ghdl-gtkwave-install.log"
exec > >(tee -a "$LOG") 2>&1

c_ok=$'\e[32m'; c_warn=$'\e[33m'; c_err=$'\e[31m'; c_b=$'\e[1m'; c_0=$'\e[0m'
step() { echo; echo "${c_b}==> $*${c_0}"; }
ok()   { echo "${c_ok}  [ok]${c_0} $*"; }
warn() { echo "${c_warn}  [aviso]${c_0} $*"; }
die()  { echo; echo "${c_err}${c_b}ERRO: $*${c_0}"; echo "Log completo: $LOG"; exit 1; }

echo
echo "################  $(date '+%F %T')  instalar_ghdl_gtkwave.sh  ################"

step "1/3  Verificando o ambiente"
[ "$(id -u)" -ne 0 ] || die "Não rode com sudo. Rode como usuário normal: bash $0"
command -v apt-get >/dev/null || die "apt-get não encontrado; este script é para Ubuntu/Debian."
ok "Ubuntu/Debian $(uname -m)"

step "2/3  Instalando ghdl e gtkwave (apt)"
PKGS=()
for p in ghdl gtkwave make; do
    if dpkg -s "$p" >/dev/null 2>&1; then
        ok "$p já instalado"
    else
        PKGS+=("$p")
    fi
done
if [ "${#PKGS[@]}" -gt 0 ]; then
    echo "  Pedindo a senha do sudo para instalar: ${PKGS[*]}"
    sudo apt-get update || warn "apt-get update teve erros (seguindo mesmo assim)"
    sudo apt-get install -y "${PKGS[@]}" || die "apt-get install falhou (veja acima). Nada foi removido."
fi
command -v ghdl    >/dev/null || die "ghdl não ficou disponível no PATH."
command -v gtkwave >/dev/null || die "gtkwave não ficou disponível no PATH."
ok "$(ghdl --version | head -1)"
ok "gtkwave $(dpkg-query -W -f='${Version}' gtkwave 2>/dev/null)"

step "3/3  Testando uma simulação"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
cat > "$T/contador.vhd" <<'EOF'
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_contador is
end entity;

architecture sim of tb_contador is
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
        report "TESTE OK: contador chegou em " & integer'image(to_integer(q));
        std.env.stop;
        wait;
    end process;
end architecture;
EOF
(
    cd "$T" \
    && ghdl -a --std=08 contador.vhd \
    && ghdl -e --std=08 tb_contador \
    && ghdl -r --std=08 tb_contador --vcd=onda.vcd
) 2>&1 | sed 's/^/    /'
if [ -s "$T/onda.vcd" ]; then
    ok "GHDL compilou, simulou e gerou o arquivo de ondas (.vcd)"
else
    die "o teste de simulação falhou (saída acima)."
fi

cat <<EOF

${c_ok}${c_b}Pronto!${c_0} Fluxo básico no terminal:

    ghdl -a --std=08 meu_circuito.vhd tb_meu_circuito.vhd   # analisa (compila)
    ghdl -e --std=08 tb_meu_circuito                        # elabora o testbench
    ghdl -r --std=08 tb_meu_circuito --vcd=onda.vcd --stop-time=1us
    gtkwave onda.vcd                                        # abre as formas de onda

(Use --wave=onda.ghw no lugar de --vcd para guardar também tipos VHDL como enum e record.)
EOF
