
type Workspace <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  store::ListStore
end

function Workspace()
  store = ListStore(String,String,String,String)
  
  tv = TreeView(store)
  r1 = CellRendererText()
  c1 = TreeViewColumn("Name", r1, {"text" => 0})
  c2 = TreeViewColumn("Type", r1,{"text" => 1})
  c3 = TreeViewColumn("Size", r1,{"text" => 2})
  c4 = TreeViewColumn("Value/Size", r1,{"text" => 3})
  G_.sort_column_id(c1,0)
  G_.resizable(c1,true)
  G_.sort_column_id(c2,1)
  G_.resizable(c2,true)
  G_.sort_column_id(c3,2)
  G_.resizable(c3,true)
  G_.sort_column_id(c4,3)
  G_.resizable(c4,true)
  G_.max_width(c4,80)
  push!(tv,c1,c2,c3,c4)
  
  G_.sort_column_id(store,0,SortType.ASCENDING)

  sw = ScrolledWindow()
  push!(sw,tv) 

  box = BoxLayout(:v)
  push!(box,sw)
  setproperty!(box,:expand,sw,true)  

  workspace = Workspace(box.handle, store)

  selection = G_.selection(tv)   

  signal_connect(tv, "button-press-event") do widget, event, other...  
    if event.button==3    
      ret, path = Gtk.path_at_pos(tv,int32(event.x),int32(event.y))

      if !ret
        return false
      end
      
      ret, it = Gtk.iter(store, path)
      var = store[it][1]
      typ = store[it][2]
        
      if contains(typ,"Array")
         item = MenuItem("plot ...")
          
         signal_connect(item, :activate) do widget
            if julietta.term != nothing
              execute(julietta.term, "display(plot(" * var * "))")
            end
         end
          
         popupmenu = Menu()
         push!(popupmenu, item)
         popup(popupmenu, event)          

      end   
    end
    false
  end

  
  
  
  Gtk.gc_move_ref(workspace, box)
end

function update!(work::Workspace, term)
  #println("update workspace...")
  empty!(work.store)
  variables = remotecall_fetch(term.id, names, Main) 
  
  #println(variables)
  
  for v in variables
    row = @fetchfrom term.id begin
      y=eval(v)
      if isa(y,Array)
        val = ""
        for d=1:(ndims(y)-1)
          val *= string(size(y,d))*"x"
        end
        val *= string(size(y,ndims(y)))
      else
        val = string(y)
      end
      (string(v),string(typeof(y)),string(sizeof(y)), val) 
    end
    
    if isa(row,Tuple) && row[2] != "Module"
      push!(work.store, row )  
    end
  end
end
