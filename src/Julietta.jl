# Issue with module in eval in workspace
#module Julietta

import Base: open, close, push!, parse

#export PkgViewer, VariableViewer, ModuleBrowser, Editor, JuliettaWindow

using Gtk, Gtk.ShortNames, Gtk.GConstants

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

type JuliettaApp 
  app::GtkApplication
  work::Workspace
  term::Terminal
  hist::History
  browser::FileBrowser
  pkgbrowser::PkgBrowser
  editor::Editor
  maintoolbar::MainToolbar
  #symbols::Symbols
  win
end

# This is the global Julietta instance
julietta = nothing

const menustr =
    """<interface>
       <menu id="menubar">
          <submenu>
          <attribute name="label">File</attribute>
             <item>
                <attribute name="label">Quit</attribute>
                <attribute name="action">app.quit</attribute>
             </item>
          </submenu>
          <submenu>
          <attribute name="label">Help</attribute>
        </submenu>
      </menu>
      <menu id="appmenu">
        <section>
          <item>
            <attribute name="label">Save</attribute>
            <attribute name="action">app.save</attribute>
          </item>
          <item>
            <attribute name="label">Quit</attribute>
            <attribute name="action">app.quit</attribute>
          </item>
        </section>
      </menu>
     </interface>"""

function JuliettaApp()

  hist = History()      
  work = Workspace()
  browser = FileBrowser()
  pkgbrowser = PkgBrowser()
  #symbols = Symbols()
  maintoolbar = MainToolbar()
  
  nb = @Notebook()
  push!(nb, work, "Workspace")
  push!(nb, hist, "History")
  
  nb2 = @Notebook()
  push!(nb2, browser, "Documents")
  push!(nb2, pkgbrowser, "Packages")
  #push!(nb2, symbols, "Symbols") 
  
  
  panedL2 = @Paned(:v)
  panedL2[1] = nb2
  panedL2[2] = nb
  G_.position(panedL2,500)  
  
  #G_.size_request(panedL2, 350,-1)  
  #G_.border_width(term,5)
  #setproperty!(term,:margin, 5)

  editor = Editor()
  term = Terminal()
  
  panedR = @Paned(:v)
  panedR[1] = editor
  panedR[2] = term
  G_.position(panedR,500)
  
  
  hbox = @Paned(:h)
  hbox[1] = panedL2
  hbox[2] = panedR
  G_.position(hbox,350)
  #setproperty!(hbox,"left-margin", 5)
  #setproperty!(hbox,"upper-margin", 5)
  #setproperty!(hbox,"lower-margin", 5)
  
   
  
  vbox = @Box(:v)
  push!(vbox,maintoolbar)
  push!(vbox,hbox)
  setproperty!(vbox,:expand,hbox,true)  
  
  app = @GtkApplication("org.julia.example", GApplicationFlags.FLAGS_NONE)
  
  signal_connect(app,"activate") do a, args...
    win = Gtk.@GtkApplicationWindow(app)
    G_.title(win, "Julietta" )
    G_.default_size(win, 1024,768)
    
    julietta.win = win
    
    builder = @GtkBuilder(buffer=menustr)

    menubar = G_.object(builder,"menubar")
    appmenu = G_.object(builder,"appmenu")

    Gtk.set_menubar(app, menubar)
    Gtk.set_app_menu(app, appmenu)

    push!(win,vbox)  
    showall(win)
 

    quitAction = Gtk.@GSimpleAction("quit")
    signal_connect(quitAction, :activate) do widget...
       exit()
    end
    push!( Gtk.GActionMap(app), Gtk.GAction(quitAction) )

    Gtk.add_accelerator(app, "<Primary>q", "app.quit")


    saveAction = Gtk.@GSimpleAction("save")
    signal_connect(saveAction, :activate) do widget...
       save(julietta.editor.currentDoc)
    end
    push!( Gtk.GActionMap(app), Gtk.GAction(saveAction) )

    Gtk.add_accelerator(app, "<Primary>s", "app.save")


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
  end

  global julietta = JuliettaApp(app,work,term,hist,browser,pkgbrowser,editor,maintoolbar,nothing)  
  julietta
end

function run_julietta()
  j = JuliettaApp()
  Gtk.run(j.app)
end

#end module
