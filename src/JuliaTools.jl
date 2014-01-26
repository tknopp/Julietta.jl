#module JuliaTools

#export PkgViewer, VariableViewer, ModuleBrowser

using Gtk
using Gtk.ShortNames


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
  
  sw1 = ScrolledWindow()
  push!(sw1,tvModules)
  sw2 = ScrolledWindow()
  push!(sw2,tvContent)  
  
  textBuf = TextBuffer()
  textV = TextView(textBuf)  
  sw3 = ScrolledWindow()
  push!(sw3,textV)   
  
  hbox = BoxLayout(:h)
  push!(hbox,sw1)
  setproperty!(hbox,:expand,sw1,true)
  push!(hbox,sw2)
  setproperty!(hbox,:expand,sw2,true)
  push!(hbox,sw3)
  setproperty!(hbox,:expand,sw3,true)    
  setproperty!(sw1,:spacing,5)
  setproperty!(sw2,:spacing,5)
  setproperty!(sw3,:spacing,5)

  
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
        push!(storeContent, (string(v), string(typeof(eval(v)))) )  
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
      if selectedCont[2] == "Function"
        txt = string(methods(eval(symbol(selectedCont[1]))))
      else
        txt = ""
      end
      G_.text(textBuf, txt, -1)
    end
  end
  
  signal_connect(updateMethods, selectionCont, "changed")   
  
  
  
  win = GtkWindow(hbox,"Module Viewer")
  show(win)
  
  moduleBrowser = ModuleBrowser(win)
  Gtk.gc_move_ref(moduleBrowser, win)
end

#end #module