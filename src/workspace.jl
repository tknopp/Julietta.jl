
type Workspace <: Gtk.GtkBoxI
  handle::Ptr{Gtk.GObjectI}
  store::ListStore
end

function Workspace()
  store = ListStore(String,String,String,String)
  
  tv = TreeView(store)
  r1 = CellRendererText()
  #setproperty!(r1,:wrap_width, 20)
  c1 = TreeViewColumn("Name", r1, {"text" => 0})
  c2 = TreeViewColumn("Type", r1,{"text" => 1})
  c3 = TreeViewColumn("Size", r1,{"text" => 2})
  c4 = TreeViewColumn("Value", r1,{"text" => 3})
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

  update!(workspace)
  
  Gtk.gc_move_ref(workspace, box)
end

function update!(work::Workspace)
  #println("update workspace...")
  empty!(work.store)
  variables = remotecall_fetch(2, names, Main) 
  #variables = names(Main)
  
  #println(variables)
  
  for v in variables
    y = remotecall_fetch(2, eval, v)
    #y = eval(v)
    if string(typeof(y)) != "Module"
      push!(work.store, (string(v), string(typeof(y)),string(sizeof(y)), string(y)) )  
    end
  end
end

type VariableViewer <: Gtk.GtkWindowI
  handle::Ptr{Gtk.GObjectI}
end

function VariableViewer()
  work = Workspace()
  win = GtkWindow(work,"Variable Viewer")
  show(win)
  
  variableViewer = VariableViewer(tv.handle)
  Gtk.gc_move_ref(variableViewer, win)
end
