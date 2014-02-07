
type History <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  filename::String
  store::ListStore
  commands::Vector{String}
  iter::Int
end

function History()
  store = ListStore(String)
  
  tv = TreeView(store)
  r1 = CellRendererText()
  c1 = TreeViewColumn("History", r1, {"text" => 0})
  G_.sort_column_id(c1,0)
  G_.resizable(c1,true)
  G_.max_width(c1,80)
  push!(tv,c1)

  sw = ScrolledWindow()
  push!(sw,tv)  

  box = BoxLayout(:v)
  push!(box,sw)
  setproperty!(box,:expand,sw,true)

  commands = String[]
  hist_filename = joinpath(homedir(),".julia_history")
  history = History(box.handle, hist_filename, store, commands, length(commands))

  open(hist_filename) do stream
    for cmd in eachline(stream)
      push!(history,strip(cmd),true)
    end
  end
  
  selection = G_.selection(tv) 
  
  signal_connect(tv, "row-activated") do treeview, path, col, other...
    if hasselection(selection)
      m, currentIt = selected(selection)

      cmd = store[currentIt][1]

      if julietta != nothing
        execute(julietta.term,cmd)
      end  
    end
    false
  end
  
  signal_connect(tv, "size-allocate") do widget, event, other...
    adj = G_.vadjustment(sw)
    G_.value(adj,getproperty(adj,:upper,Float64) - getproperty(adj,:page_size,Float64) )
  end  
  
  Gtk.gc_move_ref(history, box)
end

function push!(hist::History,cmd::String, silent::Bool=false)
  push!(hist.store, (cmd,) )
  push!(hist.commands,cmd)
  hist.iter = length(hist.commands)
  
  if !silent
    stream = open(hist.filename, "a")
    write(stream,cmd*"\n")
    close(stream)
  end
end

function prevcmd!(hist::History)
  hist.iter = (hist.iter == 0) ? 0 : hist.iter - 1
  hist.commands[hist.iter]
end

function nextcmd!(hist::History)
  hist.iter = (hist.iter == length(hist.commands)) ? length(hist.commands) : hist.iter + 1
  hist.commands[hist.iter]
end


