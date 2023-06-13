list project:
  find ./projects/{{project}} \
    | rg "([\./A-Za-z0-9]+(hdl|asm))" -or '$1'

open project chip:
  vim ./projects/{{project}}/{{chip}}.hdl

test project chip:
  ./tools/HardwareSimulator.sh ./projects/{{project}}/{{chip}}.tst

test_all project:
  find ./projects/{{project}} \
    | rg "([\./A-Za-z0-9]+)(hdl|asm)" -or '$1' \
    | xargs -I % sh -c 'echo %tst; ./tools/HardwareSimulator.sh %tst'

debug project chip:
  ./tools/TextComparer.sh \
    ./projects/{{project}}/{{chip}}.cmp \
    ./projects/{{project}}/{{chip}}.out

simulate:
  ./tools/HardwareSimulator.sh

cpu_emulate:
  ./tools/CPUEmulator.sh
