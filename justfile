list project:
  ls ./projects/{{project}} | rg hdl

list_remaining project:
  rg "Put you code here" ./projects/{{project}}/*.hdl

open project chip:
  vim ./projects/{{project}}/{{chip}}.hdl

test project chip:
  ./tools/HardwareSimulator.sh ./projects/{{project}}/{{chip}}.tst

debug project chip:
  ./tools/TextComparer.sh ./projects/{{project}}/{{chip}}.cmp ./projects/{{project}}/{{chip}}.out

simulate:
  ./tools/HardwareSimulator.sh

