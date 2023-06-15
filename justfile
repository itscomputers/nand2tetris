list project:
  find ./projects/{{project}} \
    | rg "([\./A-Za-z0-9]+(hdl|asm|vm|jack))" -or '$1'

assemble project asm:
  ./tools/Assembler.sh projects/{{project}}/{{asm}}

test project test tool="HardwareSimulator":
  ./tools/{{tool}}.sh projects/{{project}}/{{test}}.tst

test_all project tool="HardwareSimulator":
  find projects/{{project}} \
    | rg "([\./\-A-Za-z0-9]+tst)" -or '$1' \
    | xargs -I % sh -c 'echo %; tools/{{tool}}.sh %'

debug project test:
  ./tools/TextComparer.sh \
    ./projects/{{project}}/{{test}}.cmp \
    ./projects/{{project}}/{{test}}.out

simulate:
  ./tools/HardwareSimulator.sh

cpu_emulate:
  ./tools/CPUEmulator.sh

assembler:
  ./tools/Assembler.sh
