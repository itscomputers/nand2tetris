vm_translator_tests := "07/StackArithmetic/SimpleAdd/SimpleAdd \
  07/StackArithmetic/StackTest/StackTest \
  07/MemoryAccess/BasicTest/BasicTest \
  07/MemoryAccess/PointerTest/PointerTest \
  07/MemoryAccess/StaticTest/StaticTest \
  08/ProgramFlow/BasicLoop/BasicLoop \
  08/ProgramFlow/FibonacciSeries/FibonacciSeries"

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

@test_vm_translator test:
  ruby compiler/compile.rb -v projects/{{test}}.vm
  echo "testing projects/{{test}}.tst"
  ./tools/CPUEmulator.sh projects/{{test}}.tst

@test_vm_translator_all:
  for test in {{vm_translator_tests}}; do \
    just test_vm_translator "$test"; \
  done

debug project test:
  ./tools/TextComparer.sh \
    ./projects/{{project}}/{{test}}.cmp \
    ./projects/{{project}}/{{test}}.out

simulate:
  ./tools/HardwareSimulator.sh

cpu_emulate:
  ./tools/CPUEmulator.sh

vm_emulate:
  ./tools/VMEmulator.sh

assembler:
  ./tools/Assembler.sh
