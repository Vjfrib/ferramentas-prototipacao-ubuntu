# Ferramentas de FPGA no Ubuntu moderno (26.04): Quartus II 11.0, ModelSim e GHDL

Scripts para montar o ambiente de FPGA no **Ubuntu 26.04 "resolute" x86_64**, com um menu no terminal para escolher o que instalar:

| Opção do menu | Script | O que faz |
|---|---|---|
| Quartus II 11.0 | `instalar_quartus11.sh` | Quartus II 11.0 Web Edition (32 bits, de 2011) + USB-Blaster |
| GHDL + GTKWave | `instalar_ghdl_gtkwave.sh` | Simulador VHDL livre + visualizador de ondas, pelo apt |
| ModelSim-Altera 11.0 | `instalar_modelsim11.sh` | ModelSim-Altera Starter Edition 11.0 (32 bits, sem licença) |

Eu precisava do Quartus 11.0 porque é uma das últimas versões que suporta a **Cyclone I** (tenho uma placa com a **EP1C3T144C8N**). O Quartus Prime moderno não tem mais essa família. Só que o instalador de 2011 não roda num Linux de 2026, então fui resolvendo erro por erro e juntei tudo em scripts.

## Como usar

```bash
git clone https://github.com/Vjfrib/quartus-ii-11-ubuntu.git
cd quartus-ii-11-ubuntu
bash instalar.sh
```

Aparece um menu (whiptail) com as opções acima, mais "Ver o que já está instalado" e "Antes de começar". Cada opção roda o seu script, mostra a saída na tela e volta para o menu. Os scripts também podem ser rodados sozinhos, por exemplo `bash instalar_ghdl_gtkwave.sh`.

Antes, baixe da Intel/Altera e deixe em `~/Downloads`:

- Quartus: `11.0_quartus_free_linux.sh`
- ModelSim: o ModelSim-Altera Starter Edition 11.0 para Linux (ex.: `11.0_modelsim_ase_linux.sh`). Também serve a pasta já extraída ou um `ModelSimSetup-*.run`. Outro caminho: `MODELSIM_SRC=/caminho bash instalar_modelsim11.sh`.

O GHDL e o GTKWave vêm do apt, não precisa baixar nada.

Regras que valem para todos os scripts:

- Não rode com `sudo` na frente. Eles pedem a senha quando precisam.
- Podem rodar várias vezes: o que já foi feito é pulado.
- Não rodam `apt autoremove` e não removem nenhum pacote.
- Cada um grava um log em `~`: `quartus11-install.log`, `ghdl-gtkwave-install.log`, `modelsim11-install.log`.

## Quartus II 11.0

Depois é só abrir **"Quartus II 11.0 Web Edition"** no menu, ou rodar `quartus11` no terminal.
Para ver o USB-Blaster: `quartus11 jtagconfig`.

Instala em `~/altera/11.0`. Os caminhos podem ser trocados com `QUARTUS_SH=` e `QUARTUS_SRC=`.

## Simulação

O Quartus parou de ter simulador embutido na versão 10, então a simulação fica com o GHDL ou com o ModelSim. **Os dois funcionam inteiros pela linha de comando**, sem abrir janela nenhuma.

### GHDL + GTKWave

```bash
ghdl -a --std=08 meu_circuito.vhd tb_meu_circuito.vhd    # analisa (compila)
ghdl -e --std=08 tb_meu_circuito                         # elabora o testbench
ghdl -r --std=08 tb_meu_circuito --vcd=onda.vcd --stop-time=1us
gtkwave onda.vcd
```

O script instala os dois pelo apt e roda um testbench de contador para conferir.

### ModelSim-Altera 11.0

Instala em `~/altera/11.0/modelsim_ase`, cria os comandos `vlib`, `vcom`, `vlog`, `vsim` etc. (em `~/.local/bin`) e o atalho **"ModelSim-Altera 11.0"** no menu.

Pela linha de comando:

```bash
vlib work                                              # cria a biblioteca
vcom -93 meu_circuito.vhd tb_meu_circuito.vhd          # compila
vsim -c tb_meu_circuito -do "run 1 us; quit -f"        # simula sem janela
```

Dá para colocar os comandos num arquivo `.do` e rodar `vsim -c tb_meu_circuito -do sim.do`. Para ver as ondas no GTKWave sem abrir o ModelSim, gere um VCD dentro do `.do`:

```tcl
vcd file onda.vcd
vcd add -r /*
run 1 us
quit -f
```

Para o Quartus chamar o ModelSim (Tools > Run EDA Simulation Tool), aponte **Tools > Options > EDA Tool Options > ModelSim-Altera** para `~/altera/11.0/modelsim_ase/bin-ubuntu`.

O que o script corrige no ModelSim:

- **Bibliotecas de 32 bits:** o ModelSim 11 é 32 bits; o script instala as libs i386 (X11, Xft, fontconfig, ncurses...).
- **`linux_rh60` não encontrado:** o script `vco` só conhece kernels 2.x e 3.x; no kernel 6 ele procura uma pasta que não existe. O script aponta esse caso para `linuxaloem` (o original fica em `vco.original`). Os comandos em `bin-ubuntu/` chamam os binários direto.
- **Interface travando (Segmentation fault) por causa das fontes:** o Tk do ModelSim não funciona com a freetype nova. A solução conhecida é usar a freetype 2.4.12; como a fontconfig do Ubuntu 26.04 exige uma freetype nova, vai junto a fontconfig 2.11.94 (Ubuntu 16.04). As duas são baixadas de archive.ubuntu.com / old-releases.ubuntu.com com o sha256 conferido e ficam só em `modelsim_ase/compat-lib32`, sem mexer no sistema. Isso só afeta a interface; o modo texto (`vsim -c`) não precisa delas.
- **Pilha executável:** a mesma correção do Quartus (problema 8 abaixo).

A Starter Edition não precisa de licença; ela só fica mais lenta em projetos grandes, o que não faz diferença para exercícios.

## Quartus: os erros que apareceram (e como foram resolvidos)

### 1. `libz.so.1: cannot open shared object file`
O instalador é **ELF 32 bits**, e o Ubuntu só tinha a `libz` de 64 bits.
**Solução:** habilitar i386 e instalar `zlib1g:i386`, `libc6:i386` e `libstdc++6:i386`.

### 2. `Não é possível encontrar o pacote zlib1g:i386`
A arquitetura i386 não estava habilitada no apt.
**Solução:** `sudo dpkg --add-architecture i386 && sudo apt update`.

### 3. `altera_installer_gui: No such file or directory`
O `.sh` é um arquivo makeself: ele extrai tudo numa pasta temporária e apaga no final.
**Solução:** extrair e manter os arquivos com `./11.0_quartus_free_linux.sh --noexec --keep`.

### 4. `ImportError: libXext.so.6`
Faltavam as bibliotecas gráficas X11 de 32 bits.
**Solução:** instalar `libxext6:i386`, `libx11-6:i386`, `libxrender1:i386`, `libxft2:i386`, `libxtst6:i386` e outras. O script instala uma lista completa.

### 5. `libssl.so.4 / libcrypto.so.4 / libpython2.6.so.1.0 => not found`
Essas bibliotecas vêm junto, em `altera_installer/bin/`, mas o carregador não procura lá.
**Solução:** `LD_LIBRARY_PATH=altera_installer/bin`.

### 6. `ImportError: No module named _md5` ← o mais chato
O `ldd` normal não mostrava nada faltando. O que entregou a causa foi o `ldd -r`:

```
undefined symbol: __res_maybe_init, version GLIBC_PRIVATE (altera_installer/bin/libresolv.so.2)
```

O instalador traz uma **`libresolv.so.2` da glibc de 2011**. Ela depende de uma função interna da glibc que não existe mais na glibc 2.43. Por isso o `_hashlib.so` do Python 2.6 embutido falha ao carregar, e o `hashlib` tenta o `_md5`, que também não existe.
**Solução:** tirar do caminho os pedaços da glibc antiga que vieram junto (`libresolv.so.2`, `libutil.so.1`) para que o sistema use os seus próprios (i386). O script move esses arquivos para `_glibc_antiga_desativada/`.

### 7. Pular o instalador Python de vez
Com o problema 6 resolvido o instalador até abre, mas não precisa dele. Os componentes do Quartus estão em `linux_installer/quartus_free/*.gz`, e cada um é um `tar.gz`. O script extrai esses arquivos direto em `~/altera/11.0/quartus`.

### 8. Bibliotecas com "pilha executável"
A glibc nova (2.41+) se recusa a carregar via `dlopen` bibliotecas marcadas com pilha executável (`PT_GNU_STACK` com `PF_X`). Seis bibliotecas do Quartus tinham essa marca (por exemplo `libsys_cpt.so`, `libtls1.6.so` e `libmpir.so.7`).
**Solução:** um trecho em Python no script tira a marca de todos os `.so` do Quartus. Também é exportado `GLIBC_TUNABLES=glibc.rtld.execstack=2`, como garantia.

### 9. Faltava a pasta `quartus/bin`
É o instalador oficial que cria essa pasta no final, e como ele foi pulado, ela não existia.
**Solução:** o script gera um wrapper em `bin/` para cada executável de `linux/`, carregando o `adm/qenv.sh` com bash (como o original faz). Se isso falhar, ele chama o binário direto.

### 10. USB-Blaster
- Regra udev em `/etc/udev/rules.d/51-usbblaster.rules` (VID `09fb`), para não precisar de root.
- `pgm_parts.txt` copiado para `/etc/jtagd/jtagd.pgm_parts`.
- Link `libudev.so.0 → libudev.so.1` numa pasta de compatibilidade, porque o jtagd antigo procura a `.so.0`.

### 11. Interface travada + enxurrada de `libpng warning: Application built with libpng-1.2.7 but running with 1.6.57`
O Quartus 11 foi compilado com a libpng 1.2 e não traz essa biblioteca junto. No começo eu fiz um link da `libpng12.so.0` para a `libpng16` do sistema, e foi um erro: as duas são incompatíveis e a janela abre, mas não responde.
**Solução:** usar a `libpng12` original de 32 bits, do pacote `libpng12-0_1.2.54-1ubuntu1.1_i386.deb` do Ubuntu 16.04 (archive.ubuntu.com, com o sha256 conferido). O script extrai a biblioteca só para a pasta de compatibilidade do Quartus, sem instalar nada no sistema.

### 12. O atalho fechava sem abrir nada
Passando pelo `adm/qenv.sh`, o Quartus fechava calado. Chamando o binário `linux/quartus` direto, com `LD_LIBRARY_PATH` e `QUARTUS_ROOTDIR`, ele abre.
**Solução:** os atalhos em `quartus/bin/` chamam o binário direto.

### Dica: janela escondida no Wayland
Na primeira vez, o Quartus abre uma caixinha de licença / Web Edition que trava a janela principal. No Wayland ela pode ficar atrás: use Alt+Tab.

### Aviso inofensivo
`setlocale: LC_CTYPE: cannot change locale (en_US)`: o `qenv.sh` tenta usar `en_US`. Pode ignorar.

## Pendente

- [ ] **Arquivos de dispositivo (Cyclone I etc.):** o `devinfo.gz` não criou as famílias em `common/devinfo`, e os arquivos `devices/subscription/*.qda` estão num formato próprio. Ainda estou investigando.

## Ambiente testado

Testado e funcionando: o Quartus abre pelo ícone do menu e responde normalmente.
O script do GHDL + GTKWave foi testado no Ubuntu 24.04. O script do ModelSim ainda não foi rodado com o instalador de verdade; se algo falhar, o log mostra o conteúdo do pacote para ajustar.


- Ubuntu 26.04 LTS "resolute", x86_64, glibc 2.43, 8 GB de RAM
- Quartus II 11.0 Build 157 Web Edition (`11.0_quartus_free_linux.sh`)
