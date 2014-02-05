
type FileBrowser <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  path::String
  store::ListStore
  entry::Entry
  combo::GtkComboBoxText
  recentFolder::Vector{String}
end

function FileBrowser()
  store = ListStore(String,String)
  
  tv = TreeView(store)
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
  
  combo = GtkComboBoxText(true)
  entry = G_.child(combo)
  btnUp = ToolButton("gtk-go-up")
  btnChooser = ToolButton("gtk-open")
  
  setproperty!(entry,:editable,false)

  hbox = BoxLayout(:h)
  push!(hbox,combo)
  push!(hbox,btnUp)
  push!(hbox,btnChooser)
  setproperty!(hbox,:expand,combo,true)

  box = BoxLayout(:v)
  push!(box,hbox)
  push!(box,sw)
  setproperty!(box,:expand,sw,true)

  recentFolder = String[]

  browser = FileBrowser(box.handle, "", store, entry, combo, recentFolder)  
  
  changedir!(browser, pwd())
  
  signal_connect(btnUp, "clicked") do widget
    cd("..")
    changedir!(browser,pwd())
  end  
  
  signal_connect(btnChooser, "clicked") do widget
    dlg = FileChooserDialog("Select folder", NullContainer(), FileChooserAction.SELECT_FOLDER,
                        Stock.CANCEL, Response.CANCEL,
                        Stock.OPEN, Response.ACCEPT)
    ret = run(dlg)
    if ret == Response.ACCEPT
      path = Gtk.bytestring(Gtk._.filename(dlg),true)
      changedir!(browser,path)
    end
    destroy(dlg)
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
          if julietta.editor == nothing
            julietta.editor = SourceViewer()
        
            signal_connect(julietta.editor,"delete-event") do args...
              destroy(julietta.editor)
              julietta.editor = nothing
            end          
          end
          open(julietta.editor,newpath)
        end
        present(julietta.editor)
      end
    end
    false
  end
  
  Gtk.gc_move_ref(browser, box)
end

function changedir!(browser::FileBrowser, path::String)
  browser.path = path
  push!(browser.recentFolder,path)
  push!(browser.combo,path)
  G_.text(browser.entry,path)
  G_.position(browser.entry,-1)  

  update!(browser)
end

function update!(browser::FileBrowser)
  empty!(browser.store)
  cd(browser.path)
  remotecall(2,cd,browser.path)
  files = readdir()
  for file in files
    stock = isdir(file) ? "gtk-directory" : "gtk-file"
    push!(browser.store, (file,stock))
  end
end


