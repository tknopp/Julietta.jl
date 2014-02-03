type PkgViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
  builder::GtkBuilder
  store::GtkListStore
end

function PkgViewer()
  filename = joinpath(dirname(Base.source_path()),"pkgviewer.ui")
  if !isfile(filename)
    filename = Pkg.dir("Julietta.jl","src","pkgviewer.ui")
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
  
  #G_.sort_column_id(store,0,SortType.ASCENDING)
  
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
  
  pkgViewer = PkgViewer(win.handle,builder,store)
  Gtk.gc_move_ref(pkgViewer, win)
end