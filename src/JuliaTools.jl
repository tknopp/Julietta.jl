#module JuliaTools

#export pkgviewer

using Gtk.ShortNames

function pkgviewer()
  builder = Builder("C:\\Users\\knopp\\.julia\\JuliaTools.jl\\src\\pkgviewer.xml")
  #builder = Builder(joinpath(dirname(Base.source_path()),"pkgviewer.xml"))

  installedPkg = Pkg.installed()
  
  ls=ListStore(String,String)
  
  for (name,version) in installedPkg
    push!(ls,(name,string(version)))
  end
  
  tv=TreeView(ls)
  r1=CellRendererText()
  c1=TreeViewColumn("Name", r1,text=0)
  c2=TreeViewColumn("Version", r1,text=1)
  push!(tv,c1)
  push!(tv,c2) 
  
  hbox1 = G_.object(builder,"hbox1")
  push!(hbox1,tv)
  hbox1[tv,:expand] = true
  
  win = G_.object(builder,"mainWindow")
  show(win)
end


#end #module