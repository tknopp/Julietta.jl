

type PkgBrowser <: Gtk.GtkBox
  handle::Ptr{Gtk.GObject}
  path::String
  store
  combo
  recentFolder::Vector{String}
end

function PkgBrowser()
  store = @TreeStore(String,String)
  
  tv = @TreeView(TreeModel(store))
  G_.headers_visible(tv,false)  
  r1 = @CellRendererPixbuf()
  r2 = @CellRendererText()
  c1 = @TreeViewColumn("Files", r1, {"stock-id" => 1})
  push!(c1,r2)
  Gtk.add_attribute(c1,r2,"text",0)
  G_.sort_column_id(c1,0)
  G_.resizable(c1,true)
  G_.max_width(c1,80)
  push!(tv,c1)

  sw = @ScrolledWindow()
  push!(sw,tv)
  
  combo = @GtkComboBoxText(false)
  
  box = @Box(:v)
  push!(box,combo)
  push!(box,sw)
  setproperty!(box,:expand,sw,true)

  recentFolder = String[]

  browser = PkgBrowser(box.handle, "", store, combo, recentFolder)  
  
  cd(Pkg.dir())
  files = readdir()
  for file in files
    if isdir(file) && !ishidden(file)
      push!(combo,basename(file))
    end
  end  

  signal_connect(combo, "changed") do w, other...
    changedir!(julietta.pkgbrowser, Pkg.dir( bytestring( G_.active_text(w))))
  end
  
  selection = G_.selection(tv) 
  signal_connect(tv, "row-activated") do treeview, path, col, other...
    if hasselection(selection)
      m, currentIt = selected(selection)

      filepath = TreeModel(store)[currentIt][1]

      treepath = Gtk.path( TreeModel(store) , currentIt)
      
      println(Gtk.depth(treepath))
      
      for l=2:Gtk.depth(treepath)
        b = up(treepath)
        valid,it = Gtk.iter(store,treepath)
        filepath = joinpath(store[it][1], filepath)    
      end

      newpath = joinpath(browser.path,filepath)
      
      if isdir(newpath)
        changedir!(browser, newpath)
      else
        if julietta != nothing
          open(julietta.editor,newpath)
        end
        #present(julietta.editor)
      end
    end
    false
  end
  
  Gtk.gc_move_ref(browser, box)
  browser
end

function changedir!(browser::PkgBrowser, path::String)
  browser.path = path
  update!(browser)
end

function dirwalk(store::TreeStore, path::String, parent=nothing)
  files = readdir(path)
  
  #println(files)
  
  for file in files
    stock = isdir(joinpath(path,file)) ? "gtk-directory" : "gtk-file"
    it = push!(store, (file,stock), parent)
    if isdir(joinpath(path,file))
      dirwalk(store, joinpath(path,file), it)
    end
  end
end

function update!(browser::PkgBrowser)
  empty!(browser.store)
  dirwalk(browser.store, browser.path)
end

