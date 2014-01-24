#module JuliaTools

#export pkgviewer

using Gtk
using Gtk.ShortNames

function pkgviewer()
  filename = joinpath(dirname(Base.source_path()),"pkgviewer.xml")
  if !isfile(filename)
    filename = Pkg.dir("JuliaTools.jl","src","pkgviewer.xml")
  end
  global builder = Builder(filename)

  global installedPkg = Pkg.installed()
  global availablePkg = Pkg.available()
  
  global lsAll = ListStore(String,String,Bool)
  global tmFiltered = nothing
  for (name,version) in installedPkg
	push!(lsAll,(name,string(version),true))
  end
  
  for name in availablePkg
	if !haskey(installedPkg,name)
	  push!(lsAll,(name,"",false))
	end
  end  
  
  global tv = TreeView(lsAll)
  r1=CellRendererText()
  r2=CellRendererToggle()
  c1=TreeViewColumn("Name", r1, {"text" => 0})
  G_.sort_column_id(c1,0)
  c2=TreeViewColumn("Version", r1,{"text" => 1})
  c3=TreeViewColumn("Installed", r2,{"active" => 2})  
  push!(tv,c1)
  push!(tv,c2) 
  push!(tv,c3)    
  
  sw = G_.object(builder,"swAvailable")
  push!(sw,tv)
  #hbox1[tv,:expand] = true
  
  global cbShowAll = G_.object(builder,"cbShowAll")
  global btnAddRemove = G_.object(builder,"btnAddRemove")
  global spinner = G_.object(builder,"spinner")

  signal_connect(cbShowAll,"toggled") do widget
    showAll = getproperty(cbShowAll,:active,Bool)
    if(showAll)
      G_.model(tv, lsAll)
    else
      tmFiltered = TreeModelFilter(lsAll)
      G_.visible_column(tmFiltered,2)
      G_.model(tv, tmFiltered)
    end
  end
  
  @everywhere function pkgfinished()
    println("Pkg finished")
    # TODO (does not work)
    # selectionChanged()
    stop(spinner)
  end
  
  @everywhere function doPkgWork(selectedPkg)
    println("doPkgWork")
    println(selectedPkg)
    if selectedPkg[3]
      Pkg.rm(selectedPkg[1])
    else
      Pkg.add(selectedPkg[1])
    end
    remotecall(1, pkgfinished)
  end 
  
  signal_connect(btnAddRemove,"clicked") do widget
      println("btnAddRemove clicked")
      if selectedPkg != nothing
        start(spinner)
          
        # Hack 
        if getproperty(cbShowAll,:active,Bool)
          lsAll[currentIt,3] = !selectedPkg[3]
        else
          #TODO lsAll[currentIt,3] = !selectedPkg[3]
        end       

       
          
          @spawn doPkgWork(selectedPkg)
      end
  end
  
  global selection = G_.selection(tv)
  global selectedPkg = nothing
  global currentIt = nothing

  function selectionChanged( widget=nothing )
    m, currentIt, valid = selected(selection)
    
    if valid && !isvalid(lsAll, currentIt)
      it = TreeIter()
      Gtk.convert_iter_to_child_iter(tmFiltered, it, currentIt)
      currentIt = it
    end
    
    if valid
        selectedPkg = lsAll[currentIt]
        print(selectedPkg)
        G_.label(btnAddRemove, selectedPkg[3] ? "Remove" : "Add")
    end
  end
  
  signal_connect(selectionChanged, selection,"changed")  
  
  win = G_.object(builder,"mainWindow")
  show(win)
end


#end #module