

type PkgBrowser <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  path::String
  store::ListStore
  combo::GtkComboBoxText
  recentFolder::Vector{String}
end

function PkgBrowser()
  store = ListStore(String,String)
  
  tv = TreeView(store)
  G_.headers_visible(tv,false)  
  r1 = CellRendererPixbuf()
  r2 = CellRendererText()
  c1 = TreeViewColumn("Files", r1, {"stock-id" => 1})
  push!(c1,r2)
  Gtk.add_attribute(c1,r2,"text",0)
  G_.sort_column_id(c1,0)
  G_.resizable(c1,true)
  G_.max_width(c1,80)
  push!(tv,c1)

  sw = ScrolledWindow()
  push!(sw,tv)
  
  combo = GtkComboBoxText(false)
  
  box = BoxLayout(:v)
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

      file = store[currentIt][1]
      
      newpath = joinpath(browser.path,file)
      
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
end

function changedir!(browser::PkgBrowser, path::String)
  browser.path = path
  update!(browser)
end

function update!(browser::PkgBrowser)
  empty!(browser.store)
  cd(browser.path)
  if julietta != nothing
    remotecall(julietta.term.id,cd,browser.path)
  end
  files = readdir()
  for file in files
    stock = isdir(file) ? "gtk-directory" : "gtk-file"
    push!(browser.store, (file,stock))
  end
end