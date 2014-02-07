# Issue with module in eval in workspace
#module Julietta

import Base: open, close, push!

#export PkgViewer, VariableViewer, ModuleBrowser, Editor, JuliettaWindow

using Gtk
using Gtk.ShortNames


include("pkg.jl")
include("history.jl")
include("workspace.jl")
include("modulebrowser.jl")
include("terminal.jl")
include("sourcedocument.jl")
include("editor.jl")
include("filebrowser.jl")
include("maintoolbar.jl")
include("symbols.jl")

type JuliettaWindow <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  work::Workspace
  term::Terminal
  hist::History
  browser::FileBrowser
  editor::Editor
  maintoolbar::MainToolbar
  symbols::Symbols
end

# This is the global Julietta instance
julietta = nothing

function JuliettaWindow()
  if nprocs() == 1
    addprocs(1)
  end
  remotecall_fetch(2, Base.load_juliarc)

  hist = History()      
  work = Workspace()
  browser = FileBrowser()
  #symbols = Symbols()
  maintoolbar = MainToolbar()
  
  nb = Notebook()
  push!(nb, work, "Workspace")
  push!(nb, hist, "History")
  
  nb2 = Notebook()
  push!(nb2, browser, "Documents")
  #push!(nb2, symbols, "Symbols") 
  
  
  panedL2 = Paned(:v)
  panedL2[1] = nb2
  panedL2[2] = nb
  G_.position(panedL2,500)  
  
  #G_.size_request(panedL2, 350,-1)  
  #G_.border_width(term,5)
  #setproperty!(term,:margin, 5)

  editor = Editor()
  term = Terminal()
  
  panedR = Paned(:v)
  panedR[1] = editor
  panedR[2] = term
  G_.position(panedR,500)
  
  
  hbox = Paned(:h)
  hbox[1] = panedL2
  hbox[2] = panedR
  G_.position(hbox,350)
  #setproperty!(hbox,"left-margin", 5)
  #setproperty!(hbox,"upper-margin", 5)
  #setproperty!(hbox,"lower-margin", 5)
    
  vbox = BoxLayout(:v)
  push!(vbox,maintoolbar)
  push!(vbox,hbox)
  setproperty!(vbox,:expand,hbox,true)
  
  
  win = GtkWindow("Julietta",1024,768)
  push!(win,vbox)
  showall(win)
  
  global julietta = JuliettaWindow(win.handle,work,term,hist,browser,editor,maintoolbar)  
  
  signal_connect(win,"destroy") do object, args...
   exit()
  end

  Gtk.gc_move_ref(julietta, win)
end

#end #module