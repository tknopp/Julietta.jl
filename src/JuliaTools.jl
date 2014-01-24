#module JuliaTools

#export pkgviewer

using Gtk
using Gtk.ShortNames

function pkgviewer()
  builder = Builder("C:\\Users\\knopp\\.julia\\JuliaTools.jl\\src\\pkgviewer.xml")
  #builder = Builder(joinpath(dirname(Base.source_path()),"pkgviewer.xml"))

  installedPkg = Pkg.installed()
  availablePkg = Pkg.available()
  
  lsInst=ListStore(String,String,Bool)
  lsAvail=ListStore(String,String,Bool)
  lsAll=ListStore(String,String,Bool) 
  for (name,version) in installedPkg
    push!(lsInst,(name,string(version),true))
	push!(lsAll,(name,string(version),true))
  end
  
  for name in availablePkg
    push!(lsAvail,(name,"",false))
	if !haskey(installedPkg,name)
	  push!(lsAll,(name,"",false))
	end
  end  
  
  tv=TreeView(lsAll)
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
  
  cbShowAll = G_.object(builder,"cbShowAll")
  btnAddRemove = G_.object(builder,"btnAddRemove")

  signal_connect(cbShowAll,"toggled") do widget
    showAll = getproperty(cbShowAll,:active,Bool)
	G_.model(tv, showAll ? lsAll : lsInst)
  end
  
  signal_connect(btnAddRemove,"clicked") do widget

  end
  
  selection = G_.selection(tv)
  signal_connect(selection,"changed") do widget
    println("selection-changed")
  end  
  
  win = G_.object(builder,"mainWindow")
  show(win)
end


#end #module