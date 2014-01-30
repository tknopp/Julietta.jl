#module JuliaTools

#export PkgViewer, VariableViewer, ModuleBrowser, SourceViewer

using Gtk
using Gtk.ShortNames
using GtkSourceWidget


type PkgViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  builder::GtkBuilder
  store::GtkListStore
end

function PkgViewer()
  filename = joinpath(dirname(Base.source_path()),"pkgviewer.xml")
  if !isfile(filename)
    filename = Pkg.dir("JuliaTools.jl","src","pkgviewer.xml")
  end
  builder = Builder(filename)
  
  store = ListStore(String,String,Bool)
  tmFiltered = nothing
  
  tv = TreeView(store)
  r1 = CellRendererText()
  r2 = CellRendererToggle()
  c1 = TreeViewColumn("Name", r1, {"text" => 0})
  c2 = TreeViewColumn("Version", r1,{"text" => 1})
  c3 = TreeViewColumn("Installed", r2,{"active" => 2})
  G_.sort_column_id(c1,0)
  G_.sort_column_id(c2,1)
  G_.sort_column_id(c3,2)
  push!(tv,c1,c2,c3)
  
  G_.sort_column_id(store,0,Gtk.GtkSortType.GTK_SORT_ASCENDING)
  
  sw = G_.object(builder,"swAvailable")
  push!(sw,tv)  
  
  
  cbShowAll = G_.object(builder,"cbShowAll")
  btnAddRemove = G_.object(builder,"btnAddRemove")
  spinner = G_.object(builder,"spinner")

  signal_connect(cbShowAll,"toggled") do widget
    showAll = getproperty(cbShowAll,:active,Bool)
    if(showAll)
      G_.model(tv, store)
    else
      tmFiltered = TreeModelFilter(store)
      G_.visible_column(tmFiltered,2)
      G_.model(tv, tmFiltered)
    end
  end
  
  function pkgfinished()
    println("Pkg finished")
    # TODO (does not work)
    store[currentIt,3] = !selectedPkg[3]   
    selectionChanged()
    stop(spinner)
  end
  
  function doPkgWork(selectedPkg)
    println("doPkgWork")
    println(selectedPkg)
    if selectedPkg[3]
      Pkg.rm(selectedPkg[1])
    else
      Pkg.add(selectedPkg[1])
    end
    #remotecall(1, pkgfinished)
    pkgfinished()
  end 
  
  signal_connect(btnAddRemove,"clicked") do widget
      println("btnAddRemove clicked")
      if selectedPkg != nothing
        start(spinner)
          
        @async doPkgWork(selectedPkg)
      end
  end
  
  
  selection = G_.selection(tv)
  selectedPkg = nothing
  currentIt = nothing

  function selectionChanged( widget=nothing )
    m, currentIt, valid = selected(selection)
    
    if valid && !isvalid(store, currentIt)
      it = TreeIter()
      Gtk.convert_iter_to_child_iter(tmFiltered, it, currentIt)
      currentIt = it
    end
    
    if valid
        selectedPkg = store[currentIt]
        print(selectedPkg)
        G_.label(btnAddRemove, selectedPkg[3] ? "Remove" : "Add")
    end
  end
  
  signal_connect(selectionChanged, selection,"changed")    
  
  win = G_.object(builder,"mainWindow")
  show(win)
  
  
  function loadPkg()
    installedPkg = Pkg.installed()
    availablePkg = Pkg.available()
    
  for (name,version) in installedPkg
	push!(store,(name,string(version),true))
  end
  
  for name in availablePkg
	if !haskey(installedPkg,name)
	  push!(store,(name,"",false))
	end
  end
  end  
  
  @async loadPkg()
  
  pkgViewer = PkgViewer(win,builder,store)
  Gtk.gc_move_ref(pkgViewer, win)
end


type VariableViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function VariableViewer()
  store = ListStore(String,String,String,String)
  
  tv = TreeView(store)
  r1 = CellRendererText()
  c1 = TreeViewColumn("Name", r1, {"text" => 0})
  c2 = TreeViewColumn("Type", r1,{"text" => 1})
  c3 = TreeViewColumn("Size", r1,{"text" => 2})
  c4 = TreeViewColumn("Value", r1,{"text" => 3})
  G_.sort_column_id(c1,0)
  G_.sort_column_id(c2,1)
  G_.sort_column_id(c3,2)
  G_.sort_column_id(c4,3)  
  push!(tv,c1,c2,c3,c4)
  
  G_.sort_column_id(store,0,Gtk.GtkSortType.GTK_SORT_ASCENDING)
  
  variables = names(Main)
  
  for v in variables
    if string(typeof(eval(v))) != "Module"
      push!(store, (string(v), string(typeof(eval(v))),string(sizeof(eval(v))), string(eval(v))) )  
    end
  end
  
  win = GtkWindow(tv,"Variable Viewer")
  show(win)
  
  variableViewer = VariableViewer(win)
  Gtk.gc_move_ref(variableViewer, win)
end


type ModuleBrowser <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function ModuleBrowser()
  Base.Help.init_help()

  filename = joinpath(dirname(Base.source_path()),"moduleBrowser.ui")
  if !isfile(filename)
    filename = Pkg.dir("JuliaTools.jl","src","moduleBrowser.ui")
  end
  builder = Builder(filename)

  storeModules = ListStore(String)
  
  tvModules = TreeView(storeModules)
  rModules1 = CellRendererText()
  cModules1 = TreeViewColumn("Module", rModules1, {"text" => 0})
  G_.sort_column_id(cModules1,0)
  push!(tvModules,cModules1)
  
  G_.sort_column_id(storeModules,0,Gtk.GtkSortType.GTK_SORT_ASCENDING)
  
  variables = names(Main)
  
  for v in variables
    if string(typeof(eval(v))) == "Module"
      push!(storeModules, (string(v),) )  
    end
  end
  
  storeContent = ListStore(String,String)
  
  tvContent = TreeView(storeContent)
  rContent1 = CellRendererText()
  cContent1 = TreeViewColumn("Name", rContent1, {"text" => 0})
  cContent2 = TreeViewColumn("Type", rContent1,{"text" => 1})
  G_.sort_column_id(cContent1,0)
  G_.sort_column_id(cContent2,1)
  push!(tvContent,cContent1,cContent2)
  
  G_.sort_column_id(storeContent,0,Gtk.GtkSortType.GTK_SORT_ASCENDING)  
  
  swModules = G_.object(builder,"swModules")
  push!(swModules,tvModules)    
  
  swContent = G_.object(builder,"swContent")
  push!(swContent,tvContent)  
  
  textBuf = TextBuffer()
  textV = TextView(textBuf)  
  swMethods = G_.object(builder,"swMethods")
  push!(swMethods,textV)
  
  textBufHelp = TextBuffer()
  textVHelp = TextView(textBufHelp)  
  swHelp = G_.object(builder,"swHelp")
  push!(swHelp,textVHelp)  
  
  selection = G_.selection(tvModules)
  selectedModule = nothing
  currentIt = nothing  
  
  function updateContent( widget=nothing )
    m, currentIt, valid = selected(selection)

    if valid
      selectedModule = storeModules[currentIt]
      println(selectedModule)
      empty!(storeContent)
      content = names( eval(symbol( selectedModule[1] )) )
      for v in content
        if isdefined(v) 
          push!(storeContent, (string(v), string(typeof(eval(v)))) )  
        end
      end
        
    end
  end
  
  signal_connect(updateContent, selection, "changed")
  
  
  selectionCont = G_.selection(tvContent)
  selectedCont = nothing
  currentItCont = nothing  
  
  function updateMethods( widget=nothing )
    m, currentItCont, valid = selected(selectionCont)

    if valid
      selectedCont = storeContent[currentItCont]
      println(selectedCont)
      if selectedCont[2] == "Function" && isgeneric(eval(symbol(selectedCont[1])))
        txt = string(methods(eval(symbol(selectedCont[1]))))
        
        funcStr = string(selectedModule[1],".",selectedCont[1])
        if haskey(Base.Help.FUNCTION_DICT, funcStr)
          helpVec = Base.Help.FUNCTION_DICT[funcStr]
          txtHelp = ""
          for s in helpVec
            txtHelp = string(txtHelp, s)
          end
        else
          txtHelp = string(funcStr," is not documented")
        end
      elseif selectedCont[2] == "DataType" 
        fields =  names(eval(symbol(selectedCont[1])))
        txt = ""
        for f in fields
          txt = string(txt, string(f),"\n")# "       ",typeof(eval(f)),"\n")
        end             
        txtHelp = ""
      else 
        txt = ""
        txtHelp = ""
      end
      G_.text(textBuf, txt, -1)
      G_.text(textBufHelp, txtHelp, -1)
    end
  end
  
  signal_connect(updateMethods, selectionCont, "changed")   
  
  
  
  win = G_.object(builder,"mainWindow")
  show(win)
  
  moduleBrowser = ModuleBrowser(win)
  Gtk.gc_move_ref(moduleBrowser, win)
end


type SourceViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function SourceViewer()
  
  m = GtkSourceLanguageManager()
  l = GtkSourceWidget.language(m,"julia")
  b = GtkSourceBuffer(l)
  v = GtkSourceView(b)
  
  GtkSourceWidget.show_line_numbers!(v,true)
  GtkSourceWidget.auto_indent!(v,true)
  
  sw = ScrolledWindow()
  push!(sw,v)
  
  nb = Notebook()
  push!(nb, sw, "tab _one")

  
  btnOpen = Button("Open")
  
  vbox = BoxLayout(:v)
  push!(vbox,btnOpen)
  push!(vbox,nb)
  setproperty!(vbox,:expand,nb,true)
  
  win = GtkWindow(vbox,"Source Viewer")
  show(win)
  showall(win)  
  
  signal_connect(btnOpen, "clicked") do widget
    dlg = FileChooserDialog("Select file", NullContainer(), FileChooserAction.OPEN,
                        Stock.CANCEL, Response.CANCEL,
                        Stock.OPEN, Response.ACCEPT)
    ret = run(dlg)
    if ret == Response.ACCEPT
      filename = Gtk.bytestring(Gtk._.filename(dlg),true)
      txt = open(readall, filename)
      
      bNew = GtkSourceBuffer(l)
      G_.text(bNew,txt,-1)
      
      vNew = GtkSourceView(bNew)
  
      GtkSourceWidget.show_line_numbers!(vNew,true)
      GtkSourceWidget.auto_indent!(vNew,true)
  
      swNew = ScrolledWindow()
      push!(swNew,vNew)      
      
      push!(nb, swNew, filename)
      
      showall(nb)   
    end
    destroy(dlg)
  end
  
  

  
  sourceViewer = SourceViewer(win)
  Gtk.gc_move_ref(sourceViewer, win)
end

#end #module