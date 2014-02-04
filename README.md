Julietta - An IDE for Julia
============================

Julietta is feasibility study of mine if it is possible to write an IDE for Julia in Julia using Gtk.jl. In its current form Julietta is not really usable.

## Installation

Currently it is a lot complicated to get Julietta running. Here is a list of instructions:

- Install Gtk.jl from my "listView" branch: https://github.com/tknopp/Gtk.jl/tree/listView
- Install GtkSourceWidget.jl: https://github.com/tknopp/GtkSourceWidget.jl

The complicated part is not the installation of the Julia packages (using Pkg.clone) but the installation of the dependencies. Under linux this should be most simple as the libraries Gtk+ and GtkSourceView are part of the distributions package manager.

## Running Julietta

julia -F PATH_To_Julietta/src/run_julietta.jl

