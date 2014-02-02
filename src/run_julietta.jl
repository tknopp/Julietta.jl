unshift!(DL_LOAD_PATH,"/opt/local/lib")

include("Julietta.jl")

j = JuliettaWindow()

wait(Condition())