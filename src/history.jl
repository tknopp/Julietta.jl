
type History <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  store2::ListStore
end

function History()
  store2 = ListStore(String)
  
  tvh = TreeView(store2)
  r1 = CellRendererText()
  c1 = TreeViewColumn("History", r1, {"text" => 0})
  G_.sort_column_id(c1,0)
  G_.resizable(c1,true)
  G_.max_width(c1,80)
  push!(tvh,c1)

  sw = ScrolledWindow()
  push!(sw,tvh)  

  box = BoxLayout(:v)
  push!(box,sw)
  setproperty!(box,:expand,sw,true)

  history = History(box.handle, store2)
  hist_filename = @windows? joinpath(ENV["HOMEDRIVE"],ENV["HOMEPATH"],".julia_history") : joinpath(ENV["HOME"],".julia_history")
  open(hist_filename) do stream
    for cmd in eachline(stream)
      push!(history,strip(cmd))
    end
  end
  
  selection = G_.selection(tvh) 
  
  signal_connect(tvh, "row-activated") do treeview, path, col, other...
    if hasselection(selection)
      m, currentIt = selected(selection)

      cmd = store2[currentIt][1]

      if julietta != nothing
        execute(julietta.term,cmd)
      end
      
      
        
    end
    0
  end
  
  Gtk.gc_move_ref(history, box)
end

function push!(hist::History,cmd::String)
  push!(hist.store2, (cmd,) )  
end