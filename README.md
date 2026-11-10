# Instalação de ferramentas de prototipação no Ubuntu

Scripts para montar, com um menu no terminal, um ambiente de prototipação de eletrônica no **Ubuntu** (testado no 26.04 "resolute" x86_64): FPGA, placas de circuito, CNC e impressão 3D.

```
Menu principal
├── FPGA
│   ├── Quartus II 11.0 Web Edition     instalar_quartus11.sh
│   ├── GHDL + GTKWave                  instalar_ghdl_gtkwave.sh
│   └── ModelSim-Altera 11.0 Starter    instalar_modelsim11.sh
├── Prototipação
│   ├── KiCad                           instalar_kicad.sh
│   ├── UGS (Universal Gcode Sender)    instalar_ugs.sh
│   ├── FreeCAD                         instalar_freecad.sh
│   ├── PrusaSlicer                     instalar_prusaslicer.sh
│   └── Instalar os quatro
├── Ver o que já está instalado
└── Antes de começar
```

A parte de FPGA nasceu de uma necessidade: eu tenho uma placa com a **Cyclone I EP1C3T144C8N**, e o Quartus II 11.0 é uma das últimas versões que suportam essa família (o Quartus Prime moderno não tem mais). Só que o instalador de 2011 não roda num Linux de 2026, então fui resolvendo erro por erro e juntei tudo em scripts. Depois vieram as outras ferramentas que eu uso.

## Como usar

```bash
git clone https://github.com/Vjfrib/ferramentas-prototipacao-ubuntu.git
cd ferramentas-prototipacao-ubuntu
bash instalar.sh
```

Aparece um menu (whiptail) com as categorias. Cada opção roda o seu script, mostra a saída na tela e volta para o menu. Ao lado de cada ferramenta aparece se ela já está instalada. Os scripts também podem ser rodados sozinhos, por exemplo `bash instalar_kicad.sh`.

Só a parte da Altera precisa ser baixada antes, do site da Intel, e deixada em `~/Downloads`:

- Quartus: `11.0_quartus_free_linux.sh`
- ModelSim: o ModelSim-Altera Starter Edition 11.0 para Linux (ex.: `11.0_modelsim_ase_linux.sh`). Também serve a pasta já extraída ou um `ModelSimSetup-*.run`. Outro caminho: `MODELSIM_SRC=/caminho bash instalar_modelsim11.sh`.

O resto é baixado sozinho (apt, Flathub ou GitHub).

Regras que valem para todos os scripts:

- Não rode com `sudo` na frente. Eles pedem a senha quando precisam.
- Podem rodar várias vezes: o que já foi feito é pulado.
- Não rodam `apt autoremove` e não removem nenhum pacote.
- Cada um grava um log na pasta pessoal: `~/<ferramenta>-install.log`.

## Prototipação

| Ferramenta | Para que serve | De onde vem |
|---|---|---|
| **KiCad** | Esquemático e placa de circuito impresso | apt do Ubuntu, com as bibliotecas de símbolos, footprints e templates. Os modelos 3D (vários GB) só com `KICAD_3D=1 bash instalar_kicad.sh` |
| **UGS Platform** | Enviar G-code para CNC (GRBL e outros) | Última versão do [GitHub](https://github.com/winder/Universal-G-Code-Sender/releases), com o Java embutido, em `~/.local/opt/ugs`. Comando `ugs` e atalho no menu |
| **FreeCAD** | Modelagem 3D paramétrica | Flathub (`org.freecad.FreeCAD`). Se o Flathub falhar, usa o apt, quando o Ubuntu tiver o pacote |
| **PrusaSlicer** | Fatiar modelos para impressão 3D | Flathub (`com.prusa3d.PrusaSlicer`), que é como a Prusa distribui a versão atual. Se falhar, usa o `prusa-slicer` do apt (mais antigo) |

Observações:

- **UGS e a porta serial:** o script coloca você no grupo `dialout`, que é o que dá acesso a `/dev/ttyUSB*` e `/dev/ttyACM*`. Vale depois de sair e entrar de novo na sessão. Se a placa da CNC usa CH340 e não aparece, o culpado costuma ser o `brltty`; o script avisa, e a solução é `sudo apt remove brltty`.
- **Apps do Flathub:** o ícone no menu de aplicativos aparece depois de sair e entrar de novo na sessão. Pelo terminal: `flatpak run org.freecad.FreeCAD` e `flatpak run com.prusa3d.PrusaSlicer`.

## FPGA: Quartus II 11.0

Depois é só abrir **"Quartus II 11.0 Web Edition"** no menu, ou rodar `quartus11` no terminal.
Para ver o USB-Blaster: `quartus11 jtagconfig`.

Instala em `~/altera/11.0`. Os caminhos podem ser trocados com `QUARTUS_SH=` e `QUARTUS_SRC=`.

## FPGA: simulação

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

- Ubuntu 26.04 LTS "resolute", x86_64, glibc 2.43, 8 GB de RAM: o Quartus II 11.0 Build 157 Web Edition (`11.0_quartus_free_linux.sh`) abre pelo ícone do menu e responde normalmente.
- Ubuntu 24.04: os scripts do GHDL + GTKWave, KiCad e PrusaSlicer (pelo caminho do apt) rodaram de ponta a ponta, e o menu foi testado num terminal.
- Ainda não rodados com o download de verdade: ModelSim (precisa do instalador da Intel), UGS e os apps do Flathub. Se algo falhar, o log de cada script mostra onde parou.
