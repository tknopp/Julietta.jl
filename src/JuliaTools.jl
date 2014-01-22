module JuliaTools

export pkgviewer

using Gtk.ShortNames

function pkgviewer()
  builder = Builder(joinpath(dirname(Base.source_path()),"pkgviewer.xml"))
  
  installedPkg = Pkg.installed()
  
  ls=ListStore(String,String)
  
  for (name,version) in installedPkg
    push!(ls,(name,version))
  end
  
  tv=TreeView(ls)
  r1=CellRendererText()
  c1=TreeViewColumn("Name", r1,text=0)
  c2=TreeViewColumn("Version", r1,active=1)
  push!(tv,c1)
  push!(tv,c2) 
  
  hbox1 = G_.object(builder,"hbox1")
  hbox1[2] = tv
  hbox1[tv,:expand]
  
  win = G_.object(builder,"mainWindow")
  showall(win)
end


end #module