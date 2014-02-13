# Issue with module in eval in workspace
#module Julietta

import Base: open, close, push!, parse

#export PkgViewer, VariableViewer, ModuleBrowser, Editor, JuliettaWindow

using Gtk
using Gtk.ShortNames

include("settings.jl")
include("pkg.jl")
include("history.jl")
include("workspace.jl")
include("modulebrowser.jl")
include("terminal.jl")
include("sourcedocument.jl")
include("editor.jl")
include("filebrowser.jl")
include("pkgbrowser.jl")
include("maintoolbar.jl")
include("symbols.jl")

type JuliettaWindow <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  work::Workspace
  term::Terminal
  hist::History
  browser::FileBrowser
  pkgbrowser::PkgBrowser
  editor::Editor
  maintoolbar::MainToolbar
  #symbols::Symbols
end

# This is the global Julietta instance
julietta = nothing

function JuliettaWindow()

  hist = History()      
  work = Workspace()
  browser = FileBrowser()
  pkgbrowser = PkgBrowser()
  #symbols = Symbols()
  maintoolbar = MainToolbar()
  
  nb = Notebook()
  push!(nb, work, "Workspace")
  push!(nb, hist, "History")
  
  nb2 = Notebook()
  push!(nb2, browser, "Documents")
  push!(nb2, pkgbrowser, "Packages")
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
  
  
  file = MenuItem("_File")
  filemenu = Menu(file)
  saveIt = MenuItem("Save")
  signal_connect(saveIt, :activate) do widget
     save(julietta.editor.currentDoc)
  end
  push!(filemenu, saveIt)
  push!(filemenu, SeparatorMenuItem())
  quitIt = MenuItem("Quit")
  signal_connect(quitIt, :activate) do widget
     exit()
  end  
  push!(filemenu, quitIt)
  mb = MenuBar()
  push!(mb, file)  # notice this is the "File" item, not filemenu
  
  #G_.accel_path(new_ ,"<control>s")#, AccelGroup())
  

  
  
  vbox = BoxLayout(:v)
  push!(vbox,mb)
  push!(vbox,maintoolbar)
  push!(vbox,hbox)
  setproperty!(vbox,:expand,hbox,true)  
  
  win = GtkWindow("Julietta",1024,768)
  push!(win,vbox)  
  showall(win)
  
  ag = AccelGroup()
  push!(win,ag)
  
  push!(saveIt, "activate", ag, keyval("s") ,  GdkModifierType.COMMAND,  GtkAccelFlags.VISIBLE)
  
  push!(quitIt, "activate", ag, keyval("q") , GdkModifierType.COMMAND, GtkAccelFlags.VISIBLE)  
  
  global julietta = JuliettaWindow(win.handle,work,term,hist,browser,pkgbrowser,editor,maintoolbar)  
  
  rd, wr = redirect_stdout()

  @schedule begin
     while(true)
        response = readavailable(rd)
        if !isempty(response)
          response = replace(response, "From worker 2:	", "")
          insert!(julietta.term.textView,string(response)) #,"\n"
        end
     end
   end  
  
  signal_connect(win,"destroy") do object, args...
   exit()
  end

  Gtk.gc_move_ref(julietta, win)
end

#end #module